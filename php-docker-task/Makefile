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
