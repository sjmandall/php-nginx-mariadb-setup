# Runbook: Exposing info.php via Virtual Host `http://webpage`

## 1. Previous state

- Stack: Docker Compose with **Nginx + PHP-FPM + MariaDB**, plus a custom PHP Dockerfile and `info.php`.
- Nginx was published as:

```yaml
ports:
  - "8050:80"
```

- `info.php` was accessible at:

```text
http://localhost:8050
```

***

## 2. Goal

Serve `info.php` using a **virtual host URL**:

```text
http://webpage
```

instead of `http://localhost:8050`.

***

## 3. Nginx config change (`default.conf`)

Updated `php-docker-task/nginx/default.conf` to define a virtual host and make `info.php` the default page:

```nginx
server {
    listen 80;
    server_name webpage localhost;

    root /var/www/html;
    index info.php index.php index.html;

    location / {
        try_files $uri $uri/ /info.php?$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass php:9000;
        fastcgi_index info.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
```

Key changes:

- `listen 80;` – Nginx listens on port 80 in the container.  
- `server_name webpage localhost;` – handle requests for `webpage` and `localhost`.  
- `index info.php ...` – `info.php` becomes default.  
- `try_files` – fall back to `info.php` for unknown paths.

***

## 4. Docker Compose port change

Changed Nginx service ports in `docker-compose.yml` from:

```yaml
ports:
  - "8050:80"
```

to:

```yaml
ports:
  - "80:80"
```

Now host port 80 goes directly to Nginx port 80, so no `:8050` in the URL.

***

## 5. Hosts file updates

To resolve `webpage` to `127.0.0.1`, added entries:

### Windows (for browser)

Edit `C:\Windows\System32\drivers\etc\hosts`:

```text
127.0.0.1 webpage
```

### Ubuntu/WSL (optional, for curl inside WSL)

Edit `/etc/hosts`:

```text
127.0.0.1 webpage
```

***

## 6. Script update

- Extended `setup.sh` to:
  - Generate the updated `nginx/default.conf` with `server_name webpage localhost` and `index info.php`.
  - Ensure ports and files are created consistently (so new environment gets the virtual host config automatically).

***

## 7. Restart and verification

From `php-docker-task`:

```bash
cd ..
rm -rf php-docker-task
./make.sh
cd php-docker-task
make up
```

Then verify in the browser:

```text
http://webpage
```

Expected result: PHP info page (`info.php`) is served via the virtual host `webpage`.
