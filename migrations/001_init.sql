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
