#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV_FILE="$PROJECT_ROOT/.env"
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"

echo "══════════════════════════════════════════════════════════════"
echo "  Inicializador de Variables y Secretos para WordPress Docker"
echo "══════════════════════════════════════════════════════════════"

if [ -f "$ENV_FILE" ] && [ "$1" != "--force" ]; then
    echo "⚠️  El archivo .env ya existe en la raíz del proyecto."
    echo "   Para regenerarlo de cero, ejecuta: $0 --force"
    exit 0
fi

if [ ! -f "$ENV_EXAMPLE" ]; then
    echo "❌ Error: No se encontró el archivo $ENV_EXAMPLE"
    exit 1
fi

USER_UID=$(id -u)
USER_GID=$(id -g)

python3 - <<EOF
import os
import secrets
import string
import urllib.request
import re

env_example_path = "$ENV_EXAMPLE"
env_path = "$ENV_FILE"
user_uid = "$USER_UID"
user_gid = "$USER_GID"

with open(env_example_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Mapeo UID/GID
content = re.sub(r"^PUID=.*", f"PUID={user_uid}", content, flags=re.MULTILINE)
content = re.sub(r"^PGID=.*", f"PGID={user_gid}", content, flags=re.MULTILINE)

# 2. Generar contraseñas aleatorias seguras (alfanumérico de alta entropía)
alphabet = string.ascii_letters + string.digits
db_password = ''.join(secrets.choice(alphabet) for _ in range(24))
db_root_password = ''.join(secrets.choice(alphabet) for _ in range(28))

content = re.sub(r"^DB_PASSWORD=.*", f"DB_PASSWORD={db_password}", content, flags=re.MULTILINE)
content = re.sub(r"^DB_ROOT_PASSWORD=.*", f"DB_ROOT_PASSWORD={db_root_password}", content, flags=re.MULTILINE)

# 3. Obtener o generar Salts de WordPress
salt_keys = [
    ("WORDPRESS_AUTH_KEY", "AUTH_KEY"),
    ("WORDPRESS_SECURE_AUTH_KEY", "SECURE_AUTH_KEY"),
    ("WORDPRESS_LOGGED_IN_KEY", "LOGGED_IN_KEY"),
    ("WORDPRESS_NONCE_KEY", "NONCE_KEY"),
    ("WORDPRESS_AUTH_SALT", "AUTH_SALT"),
    ("WORDPRESS_SECURE_AUTH_SALT", "SECURE_AUTH_SALT"),
    ("WORDPRESS_LOGGED_IN_SALT", "LOGGED_IN_SALT"),
    ("WORDPRESS_NONCE_SALT", "NONCE_SALT"),
]

api_salts = {}
try:
    req = urllib.request.Request("https://api.wordpress.org/secret-key/1.1/salt/", headers={"User-Agent": "WP-Docker-Init"})
    with urllib.request.urlopen(req, timeout=5) as response:
        salt_text = response.read().decode("utf-8")
        matches = re.findall(r"define\('([^']+)',\s*'([^']*)'\);", salt_text)
        api_salts = dict(matches)
        print("==> Salts criptográficos oficiales obtenidos exitosamente desde api.wordpress.org")
except Exception as e:
    print(f"⚠️  No se pudo contactar con api.wordpress.org ({e}). Generando Salts localmente...")

for env_var, wp_name in salt_keys:
    if wp_name in api_salts:
        salt_val = api_salts[wp_name]
    else:
        # Generar llave local segura de 64 caracteres
        salt_val = ''.join(secrets.choice(alphabet + "_-!@#%^*=") for _ in range(64))
    
    # Envolver en comillas simples y escapar comillas simples internas
    escaped_val = salt_val.replace("'", "'\"'\"'")
    content = re.sub(rf"^{env_var}=.*", f"{env_var}='{escaped_val}'", content, flags=re.MULTILINE)

with open(env_path, "w", encoding="utf-8") as f:
    f.write(content)

os.chmod(env_path, 0o600)
print("==> Archivo .env configurado y protegido con permisos 600.")
EOF

echo "══════════════════════════════════════════════════════════════"
echo "✅ Inicialización completada con éxito."
echo "   Puedes revisar el archivo .env generado."
echo "   Para levantar el proyecto ejecuta: docker compose up -d --build"
echo "══════════════════════════════════════════════════════════════"
