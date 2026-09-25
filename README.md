# WordPress Docker Production & Development Kit

A modular, scalable, secure, and production-ready WordPress environment powered by Docker and Docker Compose. Engineered to eliminate persistent Linux permission conflicts, isolate and protect the WordPress Core against webshell/malware exploits, provide seamless PHP multi-version switching, and automatically scaffold fresh implementations using custom theme and plugin templates.

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Project Structure](#project-structure)
- [Usage](#usage)
  - [Setup](#1-setup)
  - [Install](#2-install)
  - [Update & Maintenance](#3-update--maintenance)
  - [Uninstall & Clean Reset](#4-uninstall--clean-reset)
- [Security Hardening](#security-hardening)
- [Contribution](#contribution)
- [License](#license)
- [Credits](#credits)

---

## Features

- **Bidirectional Permission Synchronization (PUID/PGID Strategy)**: Dynamically synchronizes Apache's `www-data` user with your host user UID/GID (`1000:1000` by default). You can edit code in `web/wp-content`, use Git locally, and upload assets or install plugins from the WordPress dashboard without permission errors or requiring `sudo`.
- **Immutable Core Architecture**: The WordPress core (`/var/www/html/*`, `wp-admin/`, `wp-includes/`) is owned by `root:root` and set to read-only for the web server process. Only `wp-content/` is writable by `www-data`. Even if a vulnerable plugin is exploited, attackers cannot modify `index.php`, `wp-settings.php`, or inject webshells into the core.
- **Seamless PHP & WordPress Multi-Versioning**: Change PHP versions (8.1, 8.2, 8.3) or pin specific WordPress releases without editing the Dockerfile. Simply update `WP_IMAGE` in `.env` and rebuild.
- **Automated wp-content Template Scaffolding**: Provision custom themes and plugins automatically. Place standard plugins or themes inside `docker/templates/wp-content/`, and any fresh deployment where `web/wp-content/` is empty will be automatically populated alongside default WordPress themes.
- **Decoupled & Multi-Instance Ready**: Zero hardcoded service names or database hosts. Uses generic internal service names (`wordpress`, `db`, `db-updater`) while isolating volumes and network namespaces through `COMPOSE_PROJECT_NAME` and `CONTAINER_PREFIX`. Multiple independent sites can coexist on the same Docker host.
- **Cryptographic Secrets & Salt Generator**: Includes an automated helper (`./docker/scripts/init-env.sh`) that generates high-entropy database passwords and pulls authentic cryptographic salts from `api.wordpress.org` (with local OpenSSL fallback).
- **Ephemeral DB Schema Updater (db-updater)**: An automated, one-shot auxiliary service that safely verifies database health and runs `wp core update-db` upon boot.
- **Integrated WP-CLI**: Pre-installed and ready to use for site administration, checksum validation, and script automation.

---

## Requirements

Before setting up the project, ensure you have the following installed:

- **Docker Engine**: version 24.0 or newer
- **Docker Compose**: version 2.x (Compose V2 CLI plugin: `docker compose`)
- **Operating System**: Linux, macOS, or Windows with WSL2
- **Command-line utilities**: `bash`, `curl`, `openssl`, and `python3` (used by `./docker/scripts/init-env.sh` for automated secret generation)

---

## Project Structure

```text
wordpress-docker/
├── .env.example              # Documented environment variable template
├── .gitignore                # Security rules (ignores .env, DB dumps, and large upload directories)
├── docker-compose.yml        # Orchestration definition (WordPress, MariaDB, db-updater)
├── LICENSE                   # GNU General Public License v3.0
├── README.md                 # Complete project documentation
│
├── docker/                   # Docker build context and service configurations
│   ├── Dockerfile            # Parameterized multi-PHP Dockerfile with WP-CLI
│   ├── entrypoint.sh         # Custom entrypoint: PUID/PGID sync, template cloning, core hardening
│   ├── security-hardening.conf # Apache security rules (blocks PHP in uploads, CSP, headers)
│   ├── php-override.ini      # PHP runtime directives (memory limits, upload limits, OPcache)
│   ├── scripts/
│   │   └── init-env.sh       # Automated secret, password, and WordPress salt generator
│   └── templates/
│       └── wp-content/       # Baseline template for new instances
│           ├── plugins/      # Place arbitrary plugins here to auto-copy to fresh deployments
│           └── themes/       # Place arbitrary themes here to auto-copy to fresh deployments
│
└── web/                      # Host-mounted workspace directory
    └── wp-content/           # Bound to /var/www/html/wp-content (auto-generated if empty)
```

---

## Usage

### 1. Setup

#### Step 1: Clone the repository
```bash
git clone https://github.com/octaviotron/wordpress-docker.git my-site
cd my-site
```

#### Step 2: Initialize environment variables and secrets
Run the automated initialization script:
```bash
./docker/scripts/init-env.sh
```

This script performs the following tasks:
1. Copies `.env.example` to `.env`.
2. Automatically detects your host `UID` and `GID` (`id -u` / `id -g`) and maps them to `PUID` and `PGID`.
3. Generates high-entropy passwords for `DB_PASSWORD` and `DB_ROOT_PASSWORD`.
4. Fetches unique cryptographic salts directly from `https://api.wordpress.org/secret-key/1.1/salt/` (or generates fallback keys with OpenSSL).
5. Secures file permissions (`chmod 600 .env`).

*(Optional: If you prefer manual configuration, run `cp .env.example .env` and customize the variables manually).*

#### Step 3: Customize configuration (Optional)
Review `.env` to adjust project identifiers or port numbers:
```ini
COMPOSE_PROJECT_NAME=my_site_project
CONTAINER_PREFIX=my_site
APP_PORT=8080
APP_TIMEZONE=America/Caracas
WP_IMAGE=wordpress:6.7-php8.2-apache
```

---

### 2. Install

#### Launch the containers
Build the customized image and start the services in detached mode:
```bash
docker compose up -d --build
```

#### Complete WordPress Installation
Open your browser and navigate to:
**[http://localhost:8080](http://localhost:8080)** (or the port defined in `APP_PORT`).

Complete the standard WordPress installation wizard (Select language, site title, and administrator credentials). The database connection is configured automatically through environment variables.

---

### 3. Update & Maintenance

#### Changing PHP or WordPress Versions
To update the core image or switch PHP versions (e.g., from PHP 8.2 to PHP 8.1 or PHP 8.3):
1. Update `WP_IMAGE` in `.env`:
   ```ini
   # Examples:
   WP_IMAGE=wordpress:6.7-php8.1-apache
   # or
   WP_IMAGE=wordpress:6.7-php8.3-apache
   ```
2. Rebuild and restart the container:
   ```bash
   docker compose build wordpress && docker compose up -d
   ```

#### Applying PHP runtime changes without rebuilding
Edit [docker/php-override.ini](file:///home/tr0n/GIT/wordpress-docker/docker/php-override.ini) to modify memory limits, upload file sizes, or OPcache options. Then restart the WordPress container:
```bash
docker compose restart wordpress
```

#### Database Maintenance & WP-CLI
The `wordpress` container includes WP-CLI preinstalled. You can run administration commands directly:

```bash
# Check WordPress core version:
docker compose exec wordpress wp core version --allow-root

# Verify core file integrity (checksum validation against tampering):
docker compose exec wordpress wp core verify-checksums --allow-root

# Run database schema updates:
docker compose exec wordpress wp core update-db --allow-root

# List installed plugins:
docker compose exec wordpress wp plugin list --allow-root

# Install and activate a plugin:
docker compose exec wordpress wp plugin install woocommerce --activate --allow-root
```

#### Backup Database
```bash
docker compose exec db mariadb-dump -u wordpress_user -p wordpress_db > backup_$(date +%Y%m%d).sql
```

#### Restore Database
```bash
docker compose exec -T db mariadb -u wordpress_user -p wordpress_db < backup.sql
```

---

### 4. Uninstall & Clean Reset

#### Stop services preserving data
```bash
docker compose down
```

#### Stop services and delete persistent volumes (Database & Core)
```bash
docker compose down -v
```

#### Total Clean Reinstallation (Reset from scratch)
If you wish to wipe the entire project and restart with a clean slate (removing the database, core volumes, and generated `wp-content` files):

> [!WARNING]
> This operation permanently deletes the local database, posts, users, and any media uploaded to `web/wp-content/`.

**Step-by-step reset:**

1. **Stop containers and destroy persistent volumes**:
   ```bash
   docker compose down -v
   ```

2. **Clean local generated `wp-content` files on the host**:
   *(The container entrypoint will re-scaffold this directory from your template on next boot)*
   ```bash
   rm -rf web/wp-content/*
   ```

3. **(Optional) Regenerate passwords and cryptographic salts**:
   ```bash
   ./docker/scripts/init-env.sh --force
   ```

4. **Rebuild and start clean**:
   ```bash
   docker compose up -d --build
   ```

**Fast Reset One-Liner:**
```bash
docker compose down -v && rm -rf web/wp-content/* && docker compose up -d --build
```

---

## Security Hardening

This environment incorporates defense-in-depth protections across Apache, PHP, and filesystem layers:

### Apache Layer (docker/security-hardening.conf)
- **Webshell Prevention**: Denies execution of all `.php` files inside `/wp-content/uploads/`.
- **XML-RPC Attack Surface**: Denies all requests to `xmlrpc.php` (mitigating brute force and amplification DDoS attacks).
- **Hidden & Sensitive Files**: Blocks access to dotfiles (`.env`, `.git`), `wp-config.php`, `readme.html`, and `license.txt`.
- **Direct Includes Protection**: Prohibits direct access to PHP files under `/wp-includes/`.
- **Information Leakage**: Enforces `ServerTokens Prod` and `ServerSignature Off`.

### HTTP Security Headers
- `X-Content-Type-Options: nosniff` (prevents MIME-type sniffing).
- `X-Frame-Options: SAMEORIGIN` (mitigates clickjacking).
- `Referrer-Policy: strict-origin-when-cross-origin`.
- `Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()`.
- **Differentiated Content Security Policy (CSP)**: Strict default CSP for the public frontend, with targeted allowance for preview iframes and external assets within `/wp-admin/`.

### PHP Layer (docker/Dockerfile & docker/security-hardening.conf)
- `expose_php = Off`
- `session.cookie_httponly = On`
- `session.cookie_samesite = Strict`
- `open_basedir = "/var/www/html:/tmp"` (prevents directory traversal and LFI attacks outside web roots).
- `disable_functions = "passthru,shell_exec,system,proc_open,popen,pcntl_exec,show_source"` (disabled specifically for the web context, without restricting WP-CLI).

---

## Contribution

Contributions, bug reports, and suggestions are welcome!

1. Fork the repository.
2. Create your feature branch:
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. Commit your changes:
   ```bash
   git commit -m 'feat: add amazing feature'
   ```
4. Push to the branch:
   ```bash
   git push origin feature/amazing-feature
   ```
5. Open a Pull Request.

Please ensure your scripts maintain POSIX/bash compliance, respect the decoupled architecture, and do not commit sensitive credentials or environment files.

---

## License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See the [LICENSE](file:///home/tr0n/GIT/wordpress-docker/LICENSE) file for full details.

```text
WordPress Docker Production & Development Kit
Copyright (C) 2026 Octavio Rossell Tabet

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
```

---

## Credits

- **Author**: Octavio Rossell Tabet
- **Email**: [octavio.rossell@gmail.com](mailto:octavio.rossell@gmail.com)
- **Repository**: [https://github.com/octaviotron/wordpress-docker](https://github.com/octaviotron/wordpress-docker)
