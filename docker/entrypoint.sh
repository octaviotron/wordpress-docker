#!/bin/bash
set -e

echo "══════════════════════════════════════════════════════════════"
echo "  WordPress Docker — Custom Entrypoint Initialization"
echo "══════════════════════════════════════════════════════════════"

# ── 1. Mapeo dinámico de PUID / PGID para resolver permisos con el host ───
TARGET_UID="${PUID:-1000}"
TARGET_GID="${PGID:-1000}"

CURRENT_UID=$(id -u www-data)
CURRENT_GID=$(id -g www-data)

if [ "$TARGET_GID" != "$CURRENT_GID" ]; then
    echo "==> [Entrypoint] Sincronizando GID de www-data ($CURRENT_GID -> $TARGET_GID)..."
    groupmod -o -g "$TARGET_GID" www-data
fi

if [ "$TARGET_UID" != "$CURRENT_UID" ]; then
    echo "==> [Entrypoint] Sincronizando UID de www-data ($CURRENT_UID -> $TARGET_UID)..."
    usermod -o -u "$TARGET_UID" www-data
fi

# ── 2. Detección y Sincronización del Core de WordPress ────────────────────
IMAGE_WP="/usr/src/wordpress/wp-includes/version.php"
VOLUME_WP="/var/www/html/wp-includes/version.php"

IMAGE_VERSION=""
VOLUME_VERSION=""

if [ -f "$IMAGE_WP" ]; then
    IMAGE_VERSION=$(grep "^\$wp_version =" "$IMAGE_WP" | cut -d"'" -f2)
fi

if [ -f "$VOLUME_WP" ]; then
    VOLUME_VERSION=$(grep "^\$wp_version =" "$VOLUME_WP" | cut -d"'" -f2)
fi

echo "==> [Entrypoint] Core version — Imagen: '${IMAGE_VERSION}' | Volumen: '${VOLUME_VERSION:-ninguna}'"

SHOULD_SYNC=false

if [ -z "$VOLUME_VERSION" ]; then
    echo "==> [Entrypoint] Volumen vacío o nueva instalación — sincronizando core desde imagen..."
    SHOULD_SYNC=true
elif [ "$IMAGE_VERSION" != "$VOLUME_VERSION" ]; then
    NEWEST=$(printf '%s\n%s\n' "$IMAGE_VERSION" "$VOLUME_VERSION" | sort -V | tail -1)
    if [ "$NEWEST" = "$IMAGE_VERSION" ]; then
        echo "==> [Entrypoint] Imagen más nueva ($IMAGE_VERSION > $VOLUME_VERSION) — actualizando core..."
        SHOULD_SYNC=true
    else
        echo "==> [Entrypoint] Volumen más nuevo ($VOLUME_VERSION > $IMAGE_VERSION) — conservando versión del volumen."
    fi
fi

if [ "$SHOULD_SYNC" = true ]; then
    echo "==> [Entrypoint] Copiando archivos base del Core mediante rsync..."
    rsync -a --delete \
        --exclude='/wp-content' \
        --exclude='/wp-config.php' \
        /usr/src/wordpress/ /var/www/html/
    echo "==> [Entrypoint] Core sincronizado con éxito a versión ${IMAGE_VERSION}."
fi

# ── 3. Estructura y Poblado inicial de wp-content ──────────────────────────
mkdir -p /var/www/html/wp-content/themes \
         /var/www/html/wp-content/plugins \
         /var/www/html/wp-content/uploads \
         /var/www/html/wp-content/upgrade

# Verificar si el directorio wp-content está vacío o carece de temas
# Si es así, se puebla desde la plantilla custom y temas oficiales de WP
THEMES_COUNT=$(find /var/www/html/wp-content/themes -mindepth 1 -maxdepth 1 | wc -l)
if [ "$THEMES_COUNT" -eq 0 ]; then
    echo "==> [Entrypoint] Inicializando wp-content desde plantilla y temas base..."
    
    # 3.1 Copiar temas por defecto del core si existen
    if [ -d "/usr/src/wordpress/wp-content/themes" ]; then
        cp -rn /usr/src/wordpress/wp-content/themes/* /var/www/html/wp-content/themes/ 2>/dev/null || true
    fi

    # 3.2 Copiar temas definidos en la plantilla custom si existen
    if [ -d "/usr/src/wp-content-template/themes" ]; then
        find /usr/src/wp-content-template/themes -mindepth 1 -not -name "README.md" -not -name ".gitkeep" -exec cp -r {} /var/www/html/wp-content/themes/ \; 2>/dev/null || true
    fi

    # 3.3 Copiar plugins definidos en la plantilla custom si existen
    if [ -d "/usr/src/wp-content-template/plugins" ]; then
        find /usr/src/wp-content-template/plugins -mindepth 1 -not -name "README.md" -not -name ".gitkeep" -exec cp -r {} /var/www/html/wp-content/plugins/ \; 2>/dev/null || true
    fi
    echo "==> [Entrypoint] wp-content inicializado correctamente."
fi

# ── 4. Blindaje del Core (Inmutable ante exploits web) ─────────────────────
# El core pertenece a root:root. PHP (que corre como www-data) NO puede modificarlo.
echo "==> [Entrypoint] Aplicando protección de solo lectura al Core de WordPress..."
find /var/www/html -maxdepth 1 -not -name "wp-content" -exec chown root:root {} +
if [ -d "/var/www/html/wp-admin" ]; then chown -R root:root /var/www/html/wp-admin; fi
if [ -d "/var/www/html/wp-includes" ]; then chown -R root:root /var/www/html/wp-includes; fi

# ── 5. Permisos sobre wp-content (Lectura y Escritura para www-data) ───────
echo "==> [Entrypoint] Ajustando permisos de wp-content para www-data (UID: $TARGET_UID)..."
chown -R www-data:www-data /var/www/html/wp-content
find /var/www/html/wp-content -type d -exec chmod 775 {} + 2>/dev/null || true
find /var/www/html/wp-content -type f -exec chmod 664 {} + 2>/dev/null || true

# ── 6. Blindaje de wp-config.php ──────────────────────────────────────────
if [ -f "/var/www/html/wp-config.php" ]; then
    chown root:www-data /var/www/html/wp-config.php
    chmod 440 /var/www/html/wp-config.php
fi

echo "==> [Entrypoint] Entregando control al entrypoint oficial de WordPress..."
exec docker-entrypoint.sh "$@"
