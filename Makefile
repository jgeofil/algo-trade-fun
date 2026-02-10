.PHONY: bootstrap-db migrate

bootstrap-db:
	docker compose up -d db

migrate:
	@echo "TODO: run migrations with psql or migration tool"
