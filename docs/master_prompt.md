# Codex Master Prompt: Rust Executor + TS Strategy + Pure RPC + Postgres

You are building a mono-repo for a Solana algorithmic trading research system with a **Rust chain-facing executor** and a **TypeScript strategy service**. The system must use **pure RPC (HTTP + WebSocket)** and store everything in **Postgres**. The architecture is split by trust boundary:

- **executor-rs (Rust)**: on-chain ingest, decoding, normalization, state snapshots, risk gating, tx building/execution, persistence, gRPC server.
- **strategy-ts (TypeScript)**: math + ranking, signal generation, backtesting, emits trade intents over gRPC.

The system must incorporate legitimate algorithmic signals (no exploit tactics):
- New-launch detection
- Early feature extraction
- Bonding-curve modeling
- Flow signals (momentum/acceleration)
- Regime switch on migration (bonding → AMM)
- Safety filters (holder concentration, creator behavior, repeat launcher patterns)

## Deliverables
1. **Monorepo scaffold** with:
   - `executor-rs/` (Rust)
   - `strategy-ts/` (TypeScript)
   - `proto/` (protobufs for gRPC)
   - `migrations/` (Postgres schema)
   - `docker-compose.yml` for Postgres + services
   - `README.md` with setup + run instructions
2. **Phase A–B pipeline implemented**:
   - gRPC contracts (events + intents)
   - Postgres migrations (schema below)
   - executor ingest pipeline using RPC logsSubscribe + getTransaction
   - minimal decoder to infer mint + side/size
   - persistence of raw logs + transactions + 1m features
   - strategy consumer that logs events + emits placeholder intents
3. **Tests/Checks**: simple unit tests or integration checks that validate decoder + DB inserts.

## Constraints
- **Pure RPC only** (no private indexers).
- **Postgres is the source of truth** for replay/backtest.
- Must be resilient to reconnects and RPC failure.
- All IDs (programs/venues) live in config; no hard-coded addresses.

## Protobuf (gRPC)
Create a minimal set of messages and services:

- **Executor → Strategy** (streaming):
  - `TokenLaunched`
  - `TradeObserved`
  - `FeatureBucket` (1m bucket)
  - `RiskFlagEvent`
  - `Heartbeat`

- **Strategy → Executor**:
  - `TradeIntent` (venue, side, size, slippage, ttl, reasons)
  - `IntentRejected` (e.g., `TRADING_DISABLED`)

## Postgres Schema (MVP)
Implement migrations for:

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
  mint text not null,
  slot bigint not null,
  sold_pct numeric,
  price_est numeric,
  mc_est numeric,
  state jsonb,
  primary key (mint, slot)
);

create table amm_snapshots (
  mint text not null,
  slot bigint not null,
  venue text not null,
  reserves jsonb,
  price_est numeric,
  liquidity_est numeric,
  primary key (mint, slot, venue)
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
  mint text not null,
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

## Executor Ingest (Phase B requirements)
- Use WS `logsSubscribe` against configurable program IDs (Pump.fun to start).
- For each log entry:
  - Fetch transaction via `getTransaction`.
  - Persist `raw_logs` + `transactions`.
  - Decode: infer mint, creator, and trade deltas from token balances.
  - Emit `TokenLaunched` or `TradeObserved` as appropriate.
- Aggregate 1-minute buckets of features in the executor and write to `features_1m`.

## Strategy (Phase B requirements)
- Connect to executor gRPC stream.
- Log events for now; compute placeholder signals.
- Emit test `TradeIntent` with `TRADING_DISABLED` handling.

## Safety Filters (Phase D, scaffolding only for now)
- Add table + code stubs for:
  - Holder concentration sampler
  - Creator dump detector
  - Repeat launcher tracker
- No exploit behavior. Only risk screening and downweighting.

## Migration / Regime Switch (Phase D scaffolding)
- Detect migration events from logs + decoding.
- Update token status to `MIGRATED`.
- Stub AMM account tracking after migration.

## Configuration
- Use config files or ENV for:
  - RPC endpoints (HTTP + WS)
  - Program IDs
  - Postgres DSN
  - Feature bucket windows
  - Trading enabled flag

## Acceptance Gates
- Phase A: services run 1 hour; WS reconnects; events persisted.
- Phase B: non-empty `features_1m` for active mints; deterministic replay from DB.
- Phase C+: stubs in place for curve snapshots, fee policy, safety filters.

## Style & Safety
- No exploit tactics or market manipulation.
- Provide clear module boundaries and error handling.
- Keep all addresses configurable; document sources for any program IDs.

---

Deliver the repo structure, migrations, protobufs, and Phase A–B pipeline end-to-end with build instructions and minimal tests.
