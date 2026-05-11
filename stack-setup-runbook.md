# PHP + Nginx + MariaDB Docker Stack Runbook

## 1. Objective

Set up a Docker‑based local stack running:

- Nginx (web server)  
- PHP‑FPM (custom image based on `php:8.3-fpm`)  
- MariaDB (database)  

Serve a `phpinfo()` page via Nginx and verify database connectivity from PHP with a `test_db.php` script. All setup is automated by a Bash script that:

1. Checks if Docker is installed; installs it only if missing (Ubuntu). [docs.docker](https://docs.docker.com/engine/install/ubuntu/)
2. Creates the project structure (`Dockerfile`, `docker-compose.yml`, Nginx config, PHP files, `Makefile`). [blog.jonsdocs.org](https://blog.jonsdocs.org.uk/2023/04/08/using-docker-for-a-php-mariadb-and-nginx-project/)
3. Provides `make` targets to manage the stack and test DB connectivity.

***

## 2. Prerequisites

- Ubuntu / WSL Ubuntu with sudo access.  
- Git installed and GitHub account for version control.  
- Internet access (for installing Docker and pulling images).

***

## 3. Bootstrap Script: `setup.sh`

### 3.1. Purpose

`setup.sh` is the single **bootstrap entry point**. It is designed to be **idempotent**:

- If Docker already exists, it will **not** reinstall it. [oneuptime](https://oneuptime.com/blog/post/2026-03-02-how-to-install-docker-engine-on-ubuntu-official-method/view)
- If project files exist, it skips recreating them (no overwrites).  
- It can safely be re‑run to re‑generate missing pieces.

### 3.2. Script contents

Create `setup.sh` (e.g. in `~/dockerstackphp`):

```bash
#!/usr/bin/env bash
set -e

PROJECT_DIR="php-docker-task"

command_exists() {
command -v "$1" >/dev/null 2>&1
}

install_docker() {
  echo "Docker not found. Installing Docker..."

  sudo apt remove -y docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc || true
  sudo apt update
  sudo apt install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable docker
  sudo systemctl start docker

  echo "Docker installed successfully."
}

create_project_structure() {
  mkdir -p "${PROJECT_DIR}/app"
  mkdir -p "${PROJECT_DIR}/nginx"

  # Dockerfile for PHP
  if [ ! -f "${PROJECT_DIR}/Dockerfile" ]; then
    cat > "${PROJECT_DIR}/Dockerfile" <<'DOCKER'
FROM php:8.3-fpm

# Install PHP extensions for MariaDB/MySQL
RUN docker-php-ext-install mysqli pdo pdo_mysql

WORKDIR /var/www/html
DOCKER
    echo "Created Dockerfile"
  else
    echo "Dockerfile already exists, skipping."
  fi

  # docker-compose.yml
  if [ ! -f "${PROJECT_DIR}/docker-compose.yml" ]; then
    cat > "${PROJECT_DIR}/docker-compose.yml" <<'YAML'
services:
  php:
    build: .
    container_name: php_app
    volumes:
      - ./app:/var/www/html
    depends_on:
      - mariadb

  nginx:
    image: nginx:alpine
    container_name: nginx_web
    ports:
      - "8080:80"
    volumes:
      - ./app:/var/www/html
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - php

  mariadb:
    image: mariadb:11
    container_name: mariadb_db
    environment:
      MARIADB_ROOT_PASSWORD: root123
      MARIADB_DATABASE: appdb
      MARIADB_USER: appuser
      MARIADB_PASSWORD: apppass123
    ports:
      - "3307:3306"
    volumes:
      - mariadb_data:/var/lib/mysql

volumes:
  mariadb_data:
YAML
    echo "Created docker-compose.yml"
  else
    echo "docker-compose.yml already exists, skipping."
  fi

  # Nginx config
  if [ ! -f "${PROJECT_DIR}/nginx/default.conf" ]; then
    cat > "${PROJECT_DIR}/nginx/default.conf" <<'NGINX'
server {
    listen 80;
    server_name localhost;
    root /var/www/html;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
NGINX
    echo "Created nginx/default.conf"
  else
    echo "nginx/default.conf already exists, skipping."
  fi

  # PHP files
  if [ ! -f "${PROJECT_DIR}/app/index.php" ]; then
    cat > "${PROJECT_DIR}/app/index.php" <<'PHP'
<?php
phpinfo();
PHP
    echo "Created app/index.php"
  else
    echo "app/index.php already exists, skipping."
  fi

  if [ ! -f "${PROJECT_DIR}/app/test_db.php" ]; then
    cat > "${PROJECT_DIR}/app/test_db.php" <<'PHP'
<?php
$host = 'mariadb';
$db   = 'appdb';
$user = 'appuser';
$pass = 'apppass123';
$dsn  = "mysql:host=$host;dbname=$db;charset=utf8mb4";

try {
    $pdo = new PDO($dsn, $user, $pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "DB connection OK\n";
} catch (PDOException $e) {
    echo "DB connection FAILED: " . $e->getMessage() . "\n";
}
PHP
    echo "Created app/test_db.php"
  else
    echo "app/test_db.php already exists, skipping."
  fi

  # Makefile
  if [ ! -f "${PROJECT_DIR}/Makefile" ]; then
    cat > "${PROJECT_DIR}/Makefile" <<'MAKE'
.PHONY: up down restart logs ps clean db-test

up:
	docker compose up -d --build

down:
	docker compose down

restart:
	docker compose down && docker compose up -d --build

logs:
	docker compose logs -f

ps:
	docker compose ps

clean:
	docker compose down -v

db-test:
	docker compose exec php php /var/www/html/test_db.php
MAKE
    echo "Created Makefile"
  else
    echo "Makefile already exists, skipping."
  fi
}

main() {
  if command_exists docker; then
    echo "Docker is already installed."
  else
    install_docker
  fi

  if docker compose version >/dev/null 2>&1; then
    echo "Docker Compose plugin is available."
  else
    echo "Docker Compose plugin not found."
    exit 1
  fi

  create_project_structure

  echo ""
  echo "Setup complete."
  echo "Next steps:"
  echo "  cd ${PROJECT_DIR}"
  echo "  make up"
  echo "  make db-test"
  echo "Then open:"
  echo "  http://localhost:8080"
}

main
```

This follows Docker’s official Ubuntu installation method (using the Docker apt repository and installing `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, and `docker-compose-plugin`). [docs.docker](https://docs.docker.com/engine/install/ubuntu/)

### 3.3. Running the script

From the directory where you placed `setup.sh`:

```bash
chmod +x setup.sh
./setup.sh
```

This will:

- Install Docker and the Compose plugin if missing. [docs.docker](https://docs.docker.com/compose/install/)
- Create the project directory structure and files under `php-docker-task/`.

***

## 4. Project Structure

After running `setup.sh`:

```text
php-docker-task/
├── Dockerfile
├── Makefile
├── docker-compose.yml
├── nginx/
│   └── default.conf
└── app/
    ├── index.php
    └── test_db.php
```

- `Dockerfile`: builds a custom PHP 8.3‑FPM image with `mysqli`, `pdo`, `pdo_mysql` extensions. [forums.docker](https://forums.docker.com/t/cant-install-pdo-mysql-with-docker-php-ext-install/132238)
- `docker-compose.yml`: defines `php`, `nginx`, `mariadb` services. `php` is built from `Dockerfile`; Nginx and MariaDB use official images. [digitalocean](https://www.digitalocean.com/community/tutorials/how-to-set-up-laravel-nginx-and-mysql-with-docker-compose)
- `nginx/default.conf`: Nginx server block that forwards `.php` requests to PHP‑FPM (`php:9000`).  
- `app/index.php`: `phpinfo()` to verify PHP stack.  
- `app/test_db.php`: PDO script to test DB connectivity from the PHP container. [gist.github](https://gist.github.com/d3a9d812e05f5179992033ccb99549a5)
- `Makefile`: convenient wrapper for `docker compose` commands and DB test.

***

## 5. Docker & Docker Compose Usage

From inside `php-docker-task`:

### 5.1. Start the stack

```bash
cd php-docker-task
make up
```

`make up` runs:

```bash
docker compose up -d --build
```

- Builds the custom PHP image from `Dockerfile`.  
- Starts `php_app`, `nginx_web`, and `mariadb_db` containers. [stackoverflow](https://stackoverflow.com/questions/52540785/setting-up-php-fpm-nginx-mariadb-on-centos-using-docker)

### 5.2. View status and logs

```bash
make ps        # docker compose ps
make logs      # docker compose logs -f
```

### 5.3. Stop and clean

```bash
make down      # docker compose down
make clean     # docker compose down -v  (also removes volumes, wipes DB)
```

***

## 6. Verifying PHP and Nginx

Once `make up` succeeds:

- Open `http://localhost:8080` in a browser.  
- You should see the PHP `phpinfo()` page, confirming:
  - Nginx is listening on port 80 inside the container and mapped to host 8080.  
  - Nginx is forwarding `.php` requests to the `php` container via FastCGI.  
  - PHP‑FPM is running and serving the script. [blog.jonsdocs.org](https://blog.jonsdocs.org.uk/2023/04/08/using-docker-for-a-php-mariadb-and-nginx-project/)

***

## 7. Verifying DB Connectivity from PHP

### 7.1. PHP test script (`test_db.php`)

`app/test_db.php`:

```php
<?php
$host = 'mariadb';
$db   = 'appdb';
$user = 'appuser';
$pass = 'apppass123';
$dsn  = "mysql:host=$host;dbname=$db;charset=utf8mb4";

try {
    $pdo = new PDO($dsn, $user, $pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "DB connection OK\n";
} catch (PDOException $e) {
    echo "DB connection FAILED: " . $e->getMessage() . "\n";
}
```

- Uses `PDO` and `pdo_mysql` to connect to MariaDB.  
- Uses service name `mariadb` as host, matching the Docker Compose service. [accuweb](https://accuweb.cloud/resource/articles/PHP-connection-to-mysql-mariadb)

### 7.2. Run the DB test via Make

From `php-docker-task`:

```bash
make db-test
```

This runs:

```bash
docker compose exec php php /var/www/html/test_db.php
```

Expected output:

- `DB connection OK` → PHP extensions installed, DB reachable, credentials valid.  
- `DB connection FAILED: <message>` → check credentials, service name, or extension installation.

This confirms that the custom PHP image (from Dockerfile) and MariaDB service work together correctly inside the Compose network. [mariadb](https://mariadb.com/docs/server/server-management/automated-mariadb-deployment-and-administration/docker-and-mariadb/installing-and-using-mariadb-via-docker)

***

## 8. Docker Permissions (docker group)

If you get:

```text
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
```

Fix:

1. Add your user to the `docker` group:

   ```bash
   sudo usermod -aG docker $USER
   ```

2. Close your terminal/WSL session completely, open a new one.  
3. Confirm:

   ```bash
   groups
   # should include: docker
   docker ps
   ```

4. Retry:

   ```bash
   cd php-docker-task
   make up
   ```

Docker’s Linux post-install docs require adding the user to the `docker` group and starting a new session for permissions to apply. [docs.docker](https://docs.docker.com/engine/install/linux-postinstall/)

***

## 9. Git Repository Setup and Push to GitHub

From the root of the project (`~/dockerstackphp`):

### 9.1. Initialize and add files

```bash
git init
git add .
```

### 9.2. Configure Git identity

If Git complains about “empty ident name”:

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

This sets the author/committer identity required for commits. [bbs.archlinux](https://bbs.archlinux.org/viewtopic.php?id=163624)

### 9.3. Commit

```bash
git commit -m "feat: php-nginx-mariadb stack setup"
```

### 9.4. Set main branch and remote

```bash
git branch -M main
git remote add origin https://github.com/<your-user>/php-nginx-mariadb-setup.git
```


## 10. Verification Checklist

- `docker --version` and `docker compose version` run without errors. [docs.docker](https://docs.docker.com/compose/install/)
- `docker ps` works from your user account without `sudo` (after docker group fix). [datacamp](https://www.datacamp.com/tutorial/add-users-to-docker-group)
- `make up` starts PHP, Nginx, and MariaDB containers.  
- `http://localhost:8080` shows `phpinfo()` page. [digitalocean](https://www.digitalocean.com/community/tutorials/how-to-set-up-laravel-nginx-and-mysql-with-docker-compose)
- `make db-test` prints `DB connection OK`. [stackoverflow](https://stackoverflow.com/questions/71230710/cant-connect-to-local-mariadb-running-with-docker-with-php-pdo)

