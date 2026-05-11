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

  if [ ! -f "${PROJECT_DIR}/docker-compose.yml" ]; then
    cat > "${PROJECT_DIR}/docker-compose.yml" <<'YAML'
services:
  php:
    image: php:8.3-fpm
    container_name: php_app
    volumes:
      - ./app:/var/www/html
    depends_on:
      - mariadb

  nginx:
    image: nginx:alpine
    container_name: nginx_web
    ports:
      - "8050:80"
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

  if [ ! -f "${PROJECT_DIR}/app/index.php" ]; then
    cat > "${PROJECT_DIR}/app/index.php" <<'PHP'
<?php
phpinfo();
PHP
    echo "Created app/index.php"
  else
    echo "app/index.php already exists, skipping."
  fi

  if [ ! -f "${PROJECT_DIR}/Makefile" ]; then
    cat > "${PROJECT_DIR}/Makefile" <<'MAKE'
.PHONY: up down restart logs ps clean

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down && docker compose up -d

logs:
	docker compose logs -f

ps:
	docker compose ps

clean:
	docker compose down -v
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
  echo "Then open:"
  echo "  http://localhost:8050"
}

main
