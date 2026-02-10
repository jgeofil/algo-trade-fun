# algo-trade-fun

This repository contains planning artifacts and a starter skeleton for a Rust executor + TypeScript strategy stack.

## Codex master prompt
See the detailed master prompt for building Phase A–B services and schema:
- `docs/codex-master-prompt.md`

## Local development
1. Copy environment variables:
   - `cp .env.example .env`
2. Start Postgres:
   - `docker compose up -d db`
3. Run migrations manually (placeholder):
   - `psql -h localhost -U $POSTGRES_USER -d $POSTGRES_DB -f migrations/001_init.sql`

## Repo layout
- `executor-rs/`: Rust executor skeleton
- `strategy-ts/`: TypeScript strategy skeleton
- `proto/`: gRPC protobuf definitions
- `migrations/`: Postgres schema
