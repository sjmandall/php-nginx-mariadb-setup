# PHP + Nginx + MariaDB Docker Setup

A simple Docker-based setup for running **PHP-FPM**, **Nginx**, and **MariaDB** with:

- Custom PHP image using `Dockerfile`
- Nginx virtual host support
- `phpinfo()` page
- MariaDB connection test
- Bootstrap script for auto setup
- Makefile for daily container operations

This project was first created to serve `info.php` on a port-based URL, and was later extended to serve it through a local virtual host such as `http://webpage`.

## Stack

- PHP 8.3 FPM
- Nginx
- MariaDB 11
- Docker Compose
- Bash bootstrap script
- Makefile

## Project Structure

```text
.
├── setup.sh
├── php-docker-task/
│   ├── Dockerfile
│   ├── Makefile
│   ├── docker-compose.yml
│   ├── nginx/
│   │   └── default.conf
│   └── app/
│       ├── info.php
│       └── test_db.php
```

## Features

- Builds a custom PHP image with:
  - `mysqli`
  - `pdo`
  - `pdo_mysql`
- Runs Nginx and MariaDB as separate containers, which is the common PHP-FPM architecture.[1][2]
- Uses a named Docker volume for MariaDB data persistence.[3]
- Supports virtual host access using `server_name` in Nginx and a local hosts file entry.[4][5]

## Setup

### 1. Clone the repository

```bash
git clone <your-repo-url>
cd <your-repo-folder>
```

### 2. Run the bootstrap script

```bash
chmod +x setup.sh
./setup.sh
```

This script:
- checks whether Docker is installed,
- installs Docker if missing,
- creates the Dockerfile, Compose file, Nginx config, PHP files, and Makefile.

### 3. Start the stack

```bash
cd php-docker-task
make up
```

This runs:

```bash
docker compose up -d --build
```

## Accessing the application

### Port-based access

Earlier, the app was served on a custom port such as:

```text
http://localhost:8050
```

### Virtual host access

The project was extended to serve the page using a local virtual host such as:

```text
http://webpage
```

To make this work:

1. Set the Nginx `server_name` in `nginx/default.conf`:

```nginx
server_name webpage localhost;
```

2. Map Nginx to host port 80 in `docker-compose.yml`:

```yaml
ports:
  - "80:80"
```

3. Add the hostname to your hosts file.

#### Windows hosts file

Edit:

```text
C:\Windows\System32\drivers\etc\hosts
```

Add:

```text
127.0.0.1 webpage
```

#### Ubuntu / WSL hosts file

Edit:

```bash
sudo nano /etc/hosts
```

Add:

```text
127.0.0.1 webpage
```

After making changes, restart the stack:

```bash
docker compose down
docker compose up -d --build
```

## PHP test page

The PHP info page is available through:

```text
http://webpage
```

File used:

```php
<?php
phpinfo();
```

## Database connection test

A small PHP script is included to test MariaDB connection from inside the PHP container.

Run:

```bash
make db-test
```

This executes:

```bash
docker compose exec php php /var/www/html/test_db.php
```

Expected output:

```text
DB connection OK
```

## Makefile commands

Inside `php-docker-task/`:

```bash
make up
make down
make restart
make logs
make ps
make clean
make db-test
```

## Notes

- `Dockerfile` is used only for the PHP container.
- Nginx is kept in its own service in `docker-compose.yml`, which is the recommended separation for PHP-FPM setups.[1][4]
- `test_db.php` is not required for the Dockerfile itself; it is only used to verify database connectivity.

## Troubleshooting

### Permission denied on Docker socket

If `docker compose` gives a permission error:

```bash
sudo usermod -aG docker $USER
```

Then restart the terminal session and verify:

```bash
groups
docker ps
```

### Virtual host not working

Check that these three values match exactly:

- Browser URL: `http://webpage`
- Hosts file entry: `127.0.0.1 webpage`
- Nginx config: `server_name webpage localhost;`

If they do not match, Nginx may not serve the correct virtual host.[6][7]

## Learning outcome

This project helped practice:

- Docker installation and post-install setup
- Custom PHP image creation using Dockerfile
- Multi-container setup with Docker Compose
- Nginx + PHP-FPM integration
- MariaDB connectivity testing
- Makefile-based container management
- Local virtual host configuration in Docker
