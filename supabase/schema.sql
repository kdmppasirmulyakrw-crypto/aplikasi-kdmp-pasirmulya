-- KDMP Pasirmulya: initial PostgreSQL schema draft for Supabase.
-- Apply only after reviewing roles, privacy, and operational requirements.
create extension if not exists pgcrypto;
create type public.tx_direction as enum ('masuk','keluar');
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null,
 role text not null check (role in ('admin','bendahara','sekretaris','bidang_anggota','bidang_usaha')),
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table public.members (
 id uuid primary key default gen_random_uuid(),
 member_number text not null unique,
 full_name text not null,
 phone text,
 address text,
 status text not null default 'aktif' check(status in ('aktif','nonaktif')),
 created_at timestamptz not null default now(),
 created_by uuid references auth.users(id)
);
create table public.cash_transactions (
 id uuid primary key default gen_random_uuid(),
 transaction_date date not null,
 direction public.tx_direction not null,
 amount numeric(16,2) not null check(amount>0),
 description text not null,
 unit text not null default 'kas',
 created_at timestamptz not null default now(),
 created_by uuid references auth.users(id),
 device_id text,
 client_mutation_id uuid unique
);
create table public.invoices (
 id uuid primary key default gen_random_uuid(),
 invoice_number text not null unique,
 invoice_date date not null,
 due_date date,
 customer_name text not null,
 subtotal numeric(16,2) not null default 0,
 discount numeric(16,2) not null default 0,
 down_payment numeric(16,2) not null default 0,
 total numeric(16,2) not null default 0,
 status text not null default 'draft',
 created_at timestamptz not null default now(),
 created_by uuid references auth.users(id)
);
create table public.invoice_items (
 id uuid primary key default gen_random_uuid(),
 invoice_id uuid not null references public.invoices(id) on delete cascade,
 description text not null,
 quantity numeric(14,3) not null default 1,
 unit text,
 unit_price numeric(16,2) not null default 0,
 line_total numeric(16,2) not null default 0
);
create table public.audit_logs (
 id bigint generated always as identity primary key,
 actor_id uuid references auth.users(id),
 action text not null,
 table_name text not null,
 record_id uuid,
 created_at timestamptz not null default now(),
 metadata jsonb not null default '{}'::jsonb
);
-- Enable RLS before production use. Add role-scoped policies after confirming
-- the final permission matrix; do not expose tables with permissive policies.
alter table public.profiles enable row level security;
alter table public.members enable row level security;
alter table public.cash_transactions enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;
alter table public.audit_logs enable row level security;