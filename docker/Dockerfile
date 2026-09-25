# ══════════════════════════════════════════════════════════════════════════
#  Dockerfile — Imagen de WordPress personalizada y securizada
#  Permite cambiar la versión de WordPress y PHP dinámicamente vía WP_IMAGE
# ══════════════════════════════════════════════════════════════════════════
ARG WP_IMAGE=wordpress:6.7-php8.2-apache
FROM ${WP_IMAGE}

# ── 1. Instalar herramientas del sistema y WP-CLI ─────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    less \
    curl \
    rsync \
    && curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── 2. Optimización y módulos de Apache ───────────────────────────────────
RUN a2enmod headers rewrite && \
    a2dismod -f autoindex status

# Ocultar cabeceras informativas de Debian y Apache
RUN sed -i \
    -e 's/ServerTokens OS/ServerTokens Prod/' \
    -e 's/ServerSignature On/ServerSignature Off/' \
    /etc/apache2/conf-available/security.conf

# ── 3. Hardening de Apache (bloqueo PHP uploads, CSP, headers de seguridad)
COPY security-hardening.conf /etc/apache2/conf-available/
RUN a2enconf security-hardening.conf

# ── 4. Hardening de directivas PHP básicas ────────────────────────────────
RUN { \
    echo "expose_php = Off"; \
    echo "session.cookie_httponly = On"; \
    echo "session.cookie_samesite = Strict"; \
    } > /usr/local/etc/php/conf.d/security.ini

# ── 5. Incluir plantilla base de wp-content ───────────────────────────────
COPY templates/wp-content /usr/src/wp-content-template/

# ── 6. Script de arranque / entrypoint personalizado ──────────────────────
COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# ── 7. Eliminar archivos informativos de la fuente de WordPress ───────────
RUN rm -f /usr/src/wordpress/readme.html \
          /usr/src/wordpress/license.txt \
          /usr/src/wordpress/wp-config-sample.php

ENTRYPOINT ["custom-entrypoint.sh"]
CMD ["apache2-foreground"]
