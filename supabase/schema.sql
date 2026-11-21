-- ============================================================
-- KDMP PASIRMULYA | SUPABASE DATABASE + ROLE SECURITY
-- Jalankan sekali di Supabase > SQL Editor > New query.
-- Pastikan project benar sebelum menekan RUN.
-- Role: admin, bendahara, sekretaris, bidang_anggota, bidang_usaha
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- Helpers ----------
create or replace function public.set_updated_at()
returns trigger language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------- User profiles ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null check (role in ('admin','bendahara','sekretaris','bidang_anggota','bidang_usaha')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Helper fungsi role dibuat SETELAH tabel profiles tersedia.
create or replace function public.current_app_role()
returns text
language sql
stable
security definer
set search_path = public
as $
  select p.role
  from public.profiles p
  where p.id = auth.uid() and p.active = true
  limit 1;
$;

create or replace function public.has_role(allowed_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $
  select coalesce(public.current_app_role() = any(allowed_roles), false);
$;

-- ---------- Members and savings ----------
create table if not exists public.members (
  id uuid primary key default gen_random_uuid(),
  member_number text not null unique,
  full_name text not null,
  nik text,
  phone text,
  address text,
  joined_on date not null default current_date,
  status text not null default 'aktif' check (status in ('aktif','nonaktif')),
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.member_savings (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id),
  transaction_date date not null default current_date,
  savings_type text not null check (savings_type in ('pokok','wajib','sukarela','penarikan')),
  direction text not null check (direction in ('masuk','keluar')),
  amount numeric(16,2) not null check (amount > 0),
  description text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- ---------- Cashbook ----------
create table if not exists public.cash_transactions (
  id uuid primary key default gen_random_uuid(),
  transaction_number text unique,
  transaction_date date not null default current_date,
  direction text not null check (direction in ('masuk','keluar')),
  account_code text,
  category text,
  amount numeric(16,2) not null check (amount > 0),
  description text not null,
  source_module text not null default 'kas',
  reference_id uuid,
  attachment_url text,
  created_by uuid references auth.users(id),
  client_mutation_id uuid unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- Business units, products, inventory, sales ----------
create table if not exists public.business_units (
  id uuid primary key default gen_random_uuid(),
  unit_code text not null unique,
  unit_name text not null,
  description text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid references public.business_units(id),
  sku text unique,
  product_name text not null,
  category text,
  unit_name text not null default 'pcs',
  purchase_price numeric(16,2) not null default 0 check (purchase_price >= 0),
  selling_price numeric(16,2) not null default 0 check (selling_price >= 0),
  min_stock numeric(14,3) not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  movement_date date not null default current_date,
  movement_type text not null check (movement_type in ('masuk','keluar','penyesuaian')),
  quantity numeric(14,3) not null check (quantity > 0),
  unit_cost numeric(16,2) not null default 0,
  reference text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  sale_number text not null unique,
  sale_date date not null default current_date,
  unit_id uuid references public.business_units(id),
  customer_name text,
  payment_method text,
  subtotal numeric(16,2) not null default 0,
  discount numeric(16,2) not null default 0,
  total numeric(16,2) not null default 0,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid references public.products(id),
  item_description text not null,
  quantity numeric(14,3) not null check (quantity > 0),
  unit_name text,
  unit_price numeric(16,2) not null default 0,
  line_total numeric(16,2) not null default 0
);

-- ---------- Invoices ----------
create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  invoice_number text not null unique,
  invoice_date date not null default current_date,
  due_date date,
  customer_name text not null,
  customer_address text,
  customer_phone text,
  subtotal numeric(16,2) not null default 0,
  discount numeric(16,2) not null default 0,
  down_payment numeric(16,2) not null default 0,
  total numeric(16,2) not null default 0,
  status text not null default 'draft' check (status in ('draft','terbit','lunas','batal')),
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  description text not null,
  quantity numeric(14,3) not null default 1 check (quantity > 0),
  unit text,
  unit_price numeric(16,2) not null default 0,
  line_total numeric(16,2) not null default 0
);

-- ---------- Management and employees ----------
create table if not exists public.organization_people (
  id uuid primary key default gen_random_uuid(),
  person_number text unique,
  full_name text not null,
  position_name text not null,
  category text,
  nik text,
  phone text,
  address text,
  area text,
  start_date date,
  end_date date,
  status text not null default 'aktif' check (status in ('aktif','nonaktif')),
  photo_url text,
  appointment_document_url text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- SHU (manual allocation and distribution) ----------
create table if not exists public.shu_periods (
  id uuid primary key default gen_random_uuid(),
  fiscal_year integer not null unique,
  net_surplus numeric(16,2) not null default 0 check (net_surplus >= 0),
  rat_date date,
  status text not null default 'draft' check (status in ('draft','disahkan','dibagikan')),
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shu_allocations (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.shu_periods(id) on delete cascade,
  allocation_name text not null,
  percentage numeric(7,4) check (percentage >= 0 and percentage <= 100),
  amount numeric(16,2) not null default 0 check (amount >= 0),
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique(period_id, allocation_name)
);

create table if not exists public.shu_member_distributions (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.shu_periods(id) on delete cascade,
  member_id uuid not null references public.members(id),
  transaction_service_amount numeric(16,2) not null default 0,
  capital_service_amount numeric(16,2) not null default 0,
  total_amount numeric(16,2) not null default 0,
  payment_date date,
  payment_status text not null default 'belum_dibayar' check (payment_status in ('belum_dibayar','dibayar')),
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique(period_id, member_id)
);

-- ---------- Correspondence and delivery notes ----------
create table if not exists public.letters (
  id uuid primary key default gen_random_uuid(),
  letter_number text not null unique,
  letter_type text not null check (letter_type in ('masuk','keluar')),
  letter_date date not null default current_date,
  subject text not null,
  sender text,
  recipient text,
  summary text,
  document_url text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.delivery_notes (
  id uuid primary key default gen_random_uuid(),
  delivery_number text not null unique,
  delivery_date date not null default current_date,
  sender_name text,
  recipient_name text not null,
  destination_address text,
  vehicle_number text,
  driver_name text,
  status text not null default 'diproses' check (status in ('diproses','dikirim','diterima')),
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.delivery_note_items (
  id uuid primary key default gen_random_uuid(),
  delivery_note_id uuid not null references public.delivery_notes(id) on delete cascade,
  item_name text not null,
  quantity numeric(14,3) not null check (quantity > 0),
  unit_name text,
  notes text
);

-- ---------- Audit ----------
create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id),
  action text not null,
  table_name text not null,
  record_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.write_audit_log()
returns trigger language plpgsql security definer
set search_path = public
as $$
declare
  row_data jsonb;
  record_uuid uuid;
begin
  if tg_op = 'DELETE' then
    row_data := to_jsonb(old);
  else
    row_data := to_jsonb(new);
  end if;
  record_uuid := nullif(row_data->>'id','')::uuid;
  insert into public.audit_logs(actor_id, action, table_name, record_id, old_data, new_data)
  values (auth.uid(), tg_op, tg_table_name, record_uuid,
          case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end,
          case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end);
  if tg_op = 'DELETE' then return old; else return new; end if;
end;
$$;

-- ---------- updated_at triggers ----------
do $$
declare t text;
begin
  foreach t in array array['profiles','members','cash_transactions','products','sales','invoices','organization_people','shu_periods','letters','delivery_notes']
  loop
    execute format('drop trigger if exists trg_%I_updated_at on public.%I', t, t);
    execute format('create trigger trg_%I_updated_at before update on public.%I for each row execute function public.set_updated_at()', t, t);
  end loop;
end $$;

-- ---------- Audit triggers ----------
do $$
declare t text;
begin
  foreach t in array array['members','member_savings','cash_transactions','products','inventory_movements','sales','invoices','organization_people','shu_periods','shu_allocations','shu_member_distributions','letters','delivery_notes']
  loop
    execute format('drop trigger if exists trg_%I_audit on public.%I', t, t);
    execute format('create trigger trg_%I_audit after insert or update or delete on public.%I for each row execute function public.write_audit_log()', t, t);
  end loop;
end $$;

-- ---------- Enable RLS ----------
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','members','member_savings','cash_transactions','business_units','products',
    'inventory_movements','sales','sale_items','invoices','invoice_items',
    'organization_people','shu_periods','shu_allocations','shu_member_distributions',
    'letters','delivery_notes','delivery_note_items','audit_logs'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- ---------- Policies (drop/recreate for repeatable setup) ----------
do $$
declare p record;
begin
  for p in select schemaname, tablename, policyname
           from pg_policies
           where schemaname='public'
             and tablename = any(array[
              'profiles','members','member_savings','cash_transactions','business_units','products',
              'inventory_movements','sales','sale_items','invoices','invoice_items',
              'organization_people','shu_periods','shu_allocations','shu_member_distributions',
              'letters','delivery_notes','delivery_note_items','audit_logs'
             ])
  loop
    execute format('drop policy if exists %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;

-- Profiles: user reads own profile; admin manages all profiles.
create policy profiles_read_self_or_admin on public.profiles for select to authenticated
using (id = auth.uid() or public.has_role(array['admin']));
create policy profiles_admin_all on public.profiles for all to authenticated
using (public.has_role(array['admin'])) with check (public.has_role(array['admin']));

-- Members and savings.
create policy members_read on public.members for select to authenticated
using (public.has_role(array['admin','bendahara','bidang_anggota','bidang_usaha']));
create policy members_write on public.members for all to authenticated
using (public.has_role(array['admin','bidang_anggota']))
with check (public.has_role(array['admin','bidang_anggota']));

create policy savings_read on public.member_savings for select to authenticated
using (public.has_role(array['admin','bendahara','bidang_anggota']));
create policy savings_write on public.member_savings for all to authenticated
using (public.has_role(array['admin','bendahara','bidang_anggota']))
with check (public.has_role(array['admin','bendahara','bidang_anggota']));

-- Cashbook: Admin and Treasurer only.
create policy cash_read on public.cash_transactions for select to authenticated
using (public.has_role(array['admin','bendahara']));
create policy cash_write on public.cash_transactions for all to authenticated
using (public.has_role(array['admin','bendahara']))
with check (public.has_role(array['admin','bendahara']));

-- Business units and operations: business team manages; treasurer can read.
create policy units_read on public.business_units for select to authenticated
using (public.has_role(array['admin','bendahara','bidang_usaha']));
create policy units_write on public.business_units for all to authenticated
using (public.has_role(array['admin','bidang_usaha']))
with check (public.has_role(array['admin','bidang_usaha']));

create policy products_read on public.products for select to authenticated
using (public.has_role(array['admin','bendahara','bidang_usaha']));
create policy products_write on public.products for all to authenticated
using (public.has_role(array['admin','bidang_usaha']))
with check (public.has_role(array['admin','bidang_usaha']));

create policy inventory_read on public.inventory_movements for select to authenticated
using (public.has_role(array['admin','bendahara','bidang_usaha']));
create policy inventory_write on public.inventory_movements for all to authenticated
using (public.has_role(array['admin','bidang_usaha']))
with check (public.has_role(array['admin','bidang_usaha']));

create policy sales_read on public.sales for select to authenticated
using (public.has_role(array['admin','bendahara','bidang_usaha']));
create policy sales_write on public.sales for all to authenticated
using (public.has_role(array['admin','bidang_usaha']))
with check (public.has_role(array['admin','bidang_usaha']));

create policy sale_items_read on public.sale_items for select to authenticated
using (public.has_role(array['admin','bendahara','bidang_usaha']));
create policy sale_items_write on public.sale_items for all to authenticated
using (public.has_role(array['admin','bidang_usaha']))
with check (public.has_role(array['admin','bidang_usaha']));

-- Invoices.
create policy invoices_read on public.invoices for select to authenticated
using (public.has_role(array['admin','bendahara','bidang_usaha']));
create policy invoices_write on public.invoices for all to authenticated
using (public.has_role(array['admin','bidang_usaha']))
with check (public.has_role(array['admin','bidang_usaha']));

create policy invoice_items_read on public.invoice_items for select to authenticated
using (public.has_role(array['admin','bendahara','bidang_usaha']));
create policy invoice_items_write on public.invoice_items for all to authenticated
using (public.has_role(array['admin','bidang_usaha']))
with check (public.has_role(array['admin','bidang_usaha']));

-- Management and employee records.
create policy people_read on public.organization_people for select to authenticated
using (public.has_role(array['admin','sekretaris']));
create policy people_write on public.organization_people for all to authenticated
using (public.has_role(array['admin','sekretaris']))
with check (public.has_role(array['admin','sekretaris']));

-- SHU: treasurer and admin. All amounts/percentages are manually entered.
create policy shu_periods_read on public.shu_periods for select to authenticated
using (public.has_role(array['admin','bendahara']));
create policy shu_periods_write on public.shu_periods for all to authenticated
using (public.has_role(array['admin','bendahara']))
with check (public.has_role(array['admin','bendahara']));

create policy shu_allocations_read on public.shu_allocations for select to authenticated
using (public.has_role(array['admin','bendahara']));
create policy shu_allocations_write on public.shu_allocations for all to authenticated
using (public.has_role(array['admin','bendahara']))
with check (public.has_role(array['admin','bendahara']));

create policy shu_member_read on public.shu_member_distributions for select to authenticated
using (public.has_role(array['admin','bendahara']));
create policy shu_member_write on public.shu_member_distributions for all to authenticated
using (public.has_role(array['admin','bendahara']))
with check (public.has_role(array['admin','bendahara']));

-- Correspondence: Secretary and Admin manage letters and delivery notes.
create policy letters_read on public.letters for select to authenticated
using (public.has_role(array['admin','sekretaris']));
create policy letters_write on public.letters for all to authenticated
using (public.has_role(array['admin','sekretaris']))
with check (public.has_role(array['admin','sekretaris']));

create policy delivery_read on public.delivery_notes for select to authenticated
using (public.has_role(array['admin','sekretaris','bidang_usaha']));
create policy delivery_write on public.delivery_notes for all to authenticated
using (public.has_role(array['admin','sekretaris','bidang_usaha']))
with check (public.has_role(array['admin','sekretaris','bidang_usaha']));

create policy delivery_items_read on public.delivery_note_items for select to authenticated
using (public.has_role(array['admin','sekretaris','bidang_usaha']));
create policy delivery_items_write on public.delivery_note_items for all to authenticated
using (public.has_role(array['admin','sekretaris','bidang_usaha']))
with check (public.has_role(array['admin','sekretaris','bidang_usaha']));

-- Audit log: read-only for admin/treasurer. Inserts are trigger-owned.
create policy audit_read on public.audit_logs for select to authenticated
using (public.has_role(array['admin','bendahara']));

-- ---------- Default SHU allocation labels ----------
insert into public.business_units(unit_code, unit_name, description)
values ('LPG3KG','Penjualan LPG 3 Kg','Unit penjualan LPG bersubsidi'),
       ('MANDIRI','Usaha Mandiri','Unit usaha mandiri KDMP')
on conflict (unit_code) do nothing;

-- Percentages are initial editable RAT references only.
-- The remaining 45% is intentionally NOT allocated here.
create table if not exists public.shu_allocation_reference (
  allocation_name text primary key,
  initial_percentage numeric(7,4),
  note text
);
alter table public.shu_allocation_reference enable row level security;
drop policy if exists shu_reference_read on public.shu_allocation_reference;
create policy shu_reference_read on public.shu_allocation_reference for select to authenticated
using (public.has_role(array['admin','bendahara']));
drop policy if exists shu_reference_admin_write on public.shu_allocation_reference;
create policy shu_reference_admin_write on public.shu_allocation_reference for all to authenticated
using (public.has_role(array['admin'])) with check (public.has_role(array['admin']));
insert into public.shu_allocation_reference(allocation_name,initial_percentage,note)
values ('Jasa Pengurus',30,'Nilai awal; sesuaikan keputusan RAT setiap tahun'),
       ('Dana Cadangan',20,'Nilai awal; sesuaikan keputusan RAT setiap tahun'),
       ('Dana Pendidikan & Dana Sosial',5,'Gabungan sesuai arahan; nilai awal dapat diubah')
on conflict (allocation_name) do nothing;

-- Indexes for common reports and lookups.
create index if not exists idx_cash_date on public.cash_transactions(transaction_date);
create index if not exists idx_savings_member_date on public.member_savings(member_id,transaction_date);
create index if not exists idx_sales_date on public.sales(sale_date);
create index if not exists idx_inventory_product_date on public.inventory_movements(product_id,movement_date);
create index if not exists idx_invoice_date on public.invoices(invoice_date);
create index if not exists idx_shu_period_year on public.shu_periods(fiscal_year);
create index if not exists idx_audit_created on public.audit_logs(created_at desc);

-- IMPORTANT: create auth users in Supabase Authentication first, then add
-- one matching public.profiles row per user as described in README.
