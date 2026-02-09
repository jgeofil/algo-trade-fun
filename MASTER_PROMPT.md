# Codex Master Prompt: Rust Executor + TS Strategy + Pure RPC + Postgres

Use this master prompt to generate a mono-repo implementing Phase A–B of the plan below. The system consists of a Rust **executor** service, a TypeScript **strategy** service, a Postgres **event store**, and a gRPC **intent/event** interface. The architecture emphasizes **pure RPC ingest** (no private relays), **replayable data**, and **safe strategy primitives** (no exploit tactics).

## Core goals

1. **Pure RPC ingest**: `logsSubscribe` → signature → `getTransaction` → normalize → persist.
2. **Replayable pipeline**: everything persisted for deterministic backtest.
3. **Separation of concerns**: Rust handles chain/source-of-truth + risk gate; TS handles signals and emits intents.
4. **Safety & risk**: strategy is risk-aware and can be disabled globally.

---

## Monorepo layout

```
/
  /executor-rs
  /strategy-ts
  /proto
  /db
  docker-compose.yml
  README.md
```

### executor-rs
* Rust service with WS + HTTP RPC clients.
* Stores raw logs and transactions to Postgres.
* Normalizes minimal events and streams them to strategy via gRPC.
* Provides an intent receiver endpoint (gRPC) that validates and rejects intents if `TRADING_DISABLED`.

### strategy-ts
* TS service reading normalized events via gRPC stream.
* Computes trivial baseline features (counts, flows) and emits intents.
* Can run in **paper trading mode** (no signing, intent only).

### proto
* Protobuf definitions for:
  * Executor → Strategy event stream (TokenLaunched, TradeObserved, RiskFlagEvent)
  * Strategy → Executor intent stream (TradeIntent)
  * Heartbeat + status

### db
* SQL migrations for Postgres (see schema below)
* Optional seed data for `fee_policy` (if used later)

---

## Required features (Phase A–B)

### A) Contracts + DB + skeleton services
* Protobuf + gRPC stream for events and intents.
* Postgres migrations.
* `TRADING_DISABLED` feature flag in executor; strategy should handle rejections.
* Heartbeat stream.

**Gate:** services run for 1 hour, WS reconnects, events persisted.

### B) Pure RPC ingest pipeline
* `logsSubscribe` to Pump.fun program (ID from config).
* For each signature, call `getTransaction`.
* Store:
  * `raw_logs`
  * `transactions`
* Minimal decoder:
  * infer mint
  * infer trade side + size via token balance deltas (best-effort)
* Emit normalized events to strategy.

**Gate:** non-empty `features_1m` for active mints; deterministic replay from DB.

---

## Postgres schema (MVP)

```sql
create table raw_logs (
  id bigserial primary key,
  slot bigint not null,
  signature text not null unique,
  program_id text not null,
  logs jsonb not null,
  received_at timestamptz not null default now()
);

create table transactions (
  signature text primary key,
  slot bigint not null,
  block_time timestamptz not null,
  tx jsonb not null
);

create table tokens (
  mint text primary key,
  creator text,
  launched_slot bigint,
  status text not null,
  curve_account text,
  migrated_slot bigint,
  created_at timestamptz default now()
);

create table features_1m (
  mint text not null,
  bucket_start timestamptz not null,
  venue text not null,
  trades int,
  uniq_signers int,
  vol_in_sol numeric,
  vol_out_sol numeric,
  net_inflow_sol numeric,
  whale_share_top5 numeric,
  primary key (mint, bucket_start, venue)
);

create table intents (
  id bigserial primary key,
  created_at timestamptz default now(),
  mint text not null,
  venue text not null,
  side text not null check (side in ('buy', 'sell')),
  notional_lamports bigint,
  max_slippage_bps int,
  ttl_ms int,
  reasons text[]
);

create table orders (
  id bigserial primary key,
  intent_id bigint references intents(id),
  signature text,
  status text,
  error text,
  created_at timestamptz default now()
);

create table fills (
  id bigserial primary key,
  order_id bigint references orders(id),
  mint text not null,
  side text not null,
  qty numeric,
  notional_sol numeric,
  fee_sol numeric,
  slot bigint,
  created_at timestamptz default now()
);
```

---

## gRPC API sketch

### Events (executor → strategy)
* `TokenLaunched`
* `TradeObserved`
* `RiskFlagEvent`
* `Heartbeat`

### Intents (strategy → executor)
* `TradeIntent`
  * venue
  * side
  * notional_lamports
  * max_slippage_bps
  * ttl_ms
  * reasons[]

### Control
* `Status` or `ServiceState` with `TRADING_DISABLED` enforced by executor.

---

## Implementation hints

* RPC endpoints in config with fallback list.
* WebSocket reconnect with exponential backoff.
* Keep raw logs and tx bodies for replay.
* Minimal decoder: parse token balance deltas from `preTokenBalances`/`postTokenBalances`.
* Strategy can compute features on the fly (e.g., trades per minute) to exercise pipeline.

---

## Deliverables

1. Repository with the above structure.
2. Rust executor that ingests and persists logs/txs.
3. TS strategy that connects to the gRPC stream and emits mock/paper intents.
4. Postgres migrations as SQL files.
5. README describing how to run with docker compose.

---

## Non-goals (Phase A–B)

* No live signing.
* No private relays.
* No exploit tactics.
* No performance optimizations beyond basic batching and reconnects.

---

## Acceptance tests

* `docker compose up` brings up Postgres + executor + strategy.
* Executor ingests Pump.fun logs for at least 5 minutes (or mocked local stream in test mode).
* Strategy receives events and writes at least one intent to Postgres.
* WS reconnect verified by toggling RPC endpoint.
