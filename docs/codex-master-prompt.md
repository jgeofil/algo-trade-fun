# Codex Master Prompt: Rust Executor + TS Strategy + Pure RPC + Postgres

You are building a mono-repo that implements a **Rust executor** (chain-facing), a **TypeScript strategy** (signals/ranking), **pure Solana RPC** ingest, and **Postgres** for persistence/backtest. The system must integrate: **new-launch detection**, **early feature extraction**, **bonding-curve modeling**, **flow signals**, **regime switch on migration**, and **safety filters**. No exploit tactics. Prioritize correctness, observability, and safe defaults.

## Output requirements
1. Generate the repository layout, migrations, protobufs, and skeleton services.
2. Implement Phase A–B end-to-end:
   - gRPC contract + streaming wiring
   - DB migrations (Postgres)
   - RPC ingest pipeline using `logsSubscribe` → signatures → `getTransaction`
   - Persist `raw_logs`, `transactions`, and `features_1m`
   - Deterministic replay from DB
3. Provide a local dev story:
   - `docker compose` for Postgres
   - `.env` templates
   - `make` or `task` targets for bootstrap + run
4. Provide tests where practical (schema, decode, feature aggregation). If tests are stubbed, mark TODO clearly.

## Key trust boundary
**Rust executor** = chain-facing “source of truth”
- Ingest WS + HTTP
- Decode & normalize
- Store snapshots + rolling windows + risk flag inputs
- Risk gate + execution (Phase F later)
- Write Postgres for replay/backtest

**TypeScript strategy** = math + ranking
- Consumes normalized events/features over gRPC
- Emits `TradeIntent`
- Runs offline backtests from Postgres

## Non-goals for Phases A–B
- No signing/sending transactions
- No speed games or exploit logic
- No off-chain private feeds

---

# Architecture & Components

## 1) Services
- `executor-rs` (Rust): RPC ingest + decode + normalize + persist + gRPC server
- `strategy-ts` (TypeScript): gRPC client + signal computation + intent emission
- `db` (Postgres): event store, features, and audit tables

## 2) Interfaces (gRPC)
Define protobufs for streaming **events** and **intents**:

### Events: executor → strategy
- `TokenLaunched`
- `TradeObserved`
- `CurveSnapshot`
- `AmmSnapshot`
- `FeatureBucket` (1m)
- `RiskFlagEvent`
- `Heartbeat`

### Intents: strategy → executor
- `TradeIntent` (venue/side/size/slippage/ttl + reason codes)
- `CancelIntent` (future)

## 3) Database schema
Use the schema below for migrations (adapt as needed):

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
  block_time timestamptz,
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

create table curve_snapshots (
  mint text not null references tokens(mint),
  slot bigint not null,
  sold_pct numeric,
  price_est numeric,
  mc_est numeric,
  state jsonb,
  primary key (mint, slot)
);

create table amm_snapshots (
  mint text not null references tokens(mint),
  slot bigint not null,
  venue text not null,
  reserves jsonb,
  price_est numeric,
  liquidity_est numeric,
  primary key (mint, slot, venue)
);

create table features_1m (
  mint text not null references tokens(mint),
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

create table holder_snapshots (
  mint text not null,
  sampled_at timestamptz not null,
  top5_share numeric,
  top10_share numeric,
  holders int,
  details jsonb,
  primary key (mint, sampled_at)
);

create table risk_flags (
  mint text not null references tokens(mint),
  flagged_at timestamptz not null,
  flag text not null,
  severity int not null,
  details jsonb,
  primary key (mint, flagged_at, flag)
);

create table intents (
  id bigserial primary key,
  created_at timestamptz default now(),
  mint text not null,
  venue text not null,
  side text not null,
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

# Phase A — Contracts + DB + Skeleton Services

### Requirements
- Protobufs for gRPC streaming (events and intents)
- Rust gRPC server with event stream
- TypeScript gRPC client
- Postgres migrations (SQL)
- Heartbeat stream and `TRADING_DISABLED` rejection path

### Acceptance Gate
- Services run for 1 hour
- WS reconnect works
- Events persisted

---

# Phase B — Pure RPC Ingest Pipeline

### Requirements
- `logsSubscribe` to Pump.fun program
- Resolve tx via `getTransaction`
- Persist `raw_logs` + `transactions`
- Minimal decoder (best-effort) to infer mint + side/size from token balance deltas
- Aggregate `features_1m`

### Acceptance Gate
- Non-empty `features_1m` for active mints
- Deterministic replay from DB

---

# Technical Expectations

## RPC Setup
Use a list of RPCs in config. Start with free defaults:
- HTTP: `https://api.mainnet-beta.solana.com`
- WS: `wss://api.mainnet-beta.solana.com/`

Include health scoring and rotation, with paid RPCs in prod.

## Feature Extraction (Executor)
Compute in streaming mode and write time-bucketed features:
- trades/min
- unique buyers/min
- net SOL inflow (buys − sells)
- average trade size + dispersion
- whale dominance (top N by volume)

## Curve Modeling (Executor)
- Attach `accountSubscribe` to curve accounts discovered in txs
- Store `curve_snapshots`
- Maintain fee policy in DB; include in cost/slippage estimation

## Flow Signals (Strategy)
- Net inflow acceleration (2nd derivative)
- Buyer growth rate
- Slope/curvature of implied price vs time
- Emit intents with reason codes

## Regime Switch (Migration)
- Detect migration via logs/tx decode
- Mark token `status=MIGRATED`
- Track AMM pool state; use AMM regime thresholds

## Safety Filters
- Holder concentration snapshots
- Creator dump detection (shortlist only)
- Launcher frequency tracking
- Emit `RiskFlagEvent`

---

# Deliverables
1. Mono-repo structure with `executor-rs/`, `strategy-ts/`, `proto/`, `migrations/`, `docs/`.
2. `docker-compose` for Postgres + local env.
3. `README` with setup/run instructions.
4. Phase A–B complete and runnable.

---

# Constraints
- **No exploit tactics**.
- **No try/catch around imports** in TS.
- Logging + metrics for observability.
- Make the design production-oriented but keep Phase A–B minimal.

---

# References
- Solana Websocket `logsSubscribe`
- Pump.fun public docs repo
- Pump.fun fee schedule
- Raydium program addresses (if AMM integration is used later)
