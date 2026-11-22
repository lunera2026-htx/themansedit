-- THE MANS EDIT production foundation — COD only.
-- Run after the existing supabase/schema.sql. Never expose service_role keys in the browser.
begin;

-- Enforce the confirmed business decision: Cash on Delivery only.
alter table public.orders drop constraint if exists orders_payment_method_check;
alter table public.orders add constraint orders_payment_method_cod_only check (payment_method = 'cod');
alter table public.orders alter column payment_method set default 'cod';

-- Expand catalogue fields without replacing existing product records.
alter table public.categories add column if not exists parent_id uuid references public.categories(id) on delete set null;
alter table public.categories add column if not exists image_url text;
alter table public.categories add column if not exists sort_order integer not null default 0;
alter table public.products add column if not exists subcategory_id uuid references public.categories(id) on delete set null;
alter table public.products add column if not exists compare_at_price_paise bigint check (compare_at_price_paise is null or compare_at_price_paise >= 0);
alter table public.products add column if not exists is_featured boolean not null default false;
alter table public.products add column if not exists is_new_arrival boolean not null default false;
alter table public.products add column if not exists is_best_seller boolean not null default false;
alter table public.products add column if not exists updated_at timestamptz not null default now();

-- Variant-specific gallery: each colour/size combination is represented by a variant.
alter table public.product_images add column if not exists variant_id uuid references public.product_variants(id) on delete cascade;
alter table public.product_images add column if not exists alt_text text;
alter table public.product_images add column if not exists is_primary boolean not null default false;
alter table public.product_images add column if not exists storage_path text;
alter table public.product_variants add column if not exists color_hex text;
alter table public.product_variants add column if not exists compare_at_price_paise bigint check (compare_at_price_paise is null or compare_at_price_paise >= 0);
alter table public.product_variants add column if not exists low_stock_threshold integer not null default 3 check (low_stock_threshold >= 0);

create index if not exists product_images_variant_idx on public.product_images(variant_id, sort_order);
create index if not exists products_category_status_idx on public.products(category_id, status);
create index if not exists variants_product_idx on public.product_variants(product_id);
create index if not exists orders_created_idx on public.orders(created_at desc);
create index if not exists orders_phone_idx on public.orders(phone);

-- Customer-owned saved addresses.
create table if not exists public.customer_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  label text not null default 'Home',
  recipient_name text not null,
  phone text not null,
  house_number text not null,
  street text not null,
  area text not null,
  city text not null,
  state text not null,
  pincode text not null check (pincode ~ '^[0-9]{6}$'),
  instructions text,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.customer_addresses enable row level security;
drop policy if exists "customer manages own addresses" on public.customer_addresses;
create policy "customer manages own addresses" on public.customer_addresses
for all to authenticated using(user_id = (select auth.uid()) or public.is_admin())
with check(user_id = (select auth.uid()) or public.is_admin());

-- Persistent editable homepage content.
create table if not exists public.site_content (
  id uuid primary key default gen_random_uuid(),
  content_key text not null unique,
  content jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.site_content enable row level security;
drop policy if exists "public reads active site content" on public.site_content;
create policy "public reads active site content" on public.site_content
for select to anon, authenticated using(is_active or public.is_admin());
drop policy if exists "admin manages site content" on public.site_content;
create policy "admin manages site content" on public.site_content
for all to authenticated using(public.is_admin()) with check(public.is_admin());

-- Timestamped order lifecycle, including delivery/return stages.
create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  status text not null,
  note text,
  changed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.order_status_history enable row level security;
drop policy if exists "customer reads own order status history" on public.order_status_history;
create policy "customer reads own order status history" on public.order_status_history
for select to authenticated using (
  exists(select 1 from public.orders o where o.id = order_id and (o.user_id = (select auth.uid()) or public.is_admin()))
);
drop policy if exists "admin manages order status history" on public.order_status_history;
create policy "admin manages order status history" on public.order_status_history
for all to authenticated using(public.is_admin()) with check(public.is_admin());

-- Internal notes must never be visible to customers.
create table if not exists public.order_internal_notes (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  note text not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.order_internal_notes enable row level security;
drop policy if exists "admin manages internal order notes" on public.order_internal_notes;
create policy "admin manages internal order notes" on public.order_internal_notes
for all to authenticated using(public.is_admin()) with check(public.is_admin());

-- COD-only order creation. Called only by a trusted server/Edge Function using service role.
-- JSON items must contain variant_id and quantity; prices/names are always read from DB.
create or replace function public.place_cod_order(
  p_customer_name text,
  p_email text,
  p_phone text,
  p_shipping_address jsonb,
  p_items jsonb,
  p_user_id uuid default null
) returns table(order_id uuid, order_number bigint, total_paise bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order_id uuid := gen_random_uuid();
  v_order_number bigint;
  v_subtotal bigint := 0;
  v_total bigint := 0;
  v_item jsonb;
  v_variant public.product_variants%rowtype;
  v_qty integer;
  v_available integer;
  v_line bigint;
  v_name text;
  v_sku text;
begin
  if length(trim(coalesce(p_customer_name,''))) < 2 then raise exception 'Enter a valid customer name'; end if;
  if p_phone !~ '^[6-9][0-9]{9}$' then raise exception 'Enter a valid 10-digit Indian mobile number'; end if;
  if p_email is null or position('@' in p_email) < 2 then raise exception 'Enter a valid email address'; end if;
  if jsonb_typeof(p_shipping_address) <> 'object' then raise exception 'A complete delivery address is required'; end if;
  if coalesce(p_shipping_address->>'pincode','') !~ '^[0-9]{6}$' then raise exception 'Enter a valid 6-digit PIN code'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Your bag is empty'; end if;
  if jsonb_array_length(p_items) > 30 then raise exception 'Too many different items in one order'; end if;

  -- Lock all requested stock rows in deterministic order to prevent overselling.
  for v_item in select value from jsonb_array_elements(p_items) order by value->>'variant_id'
  loop
    v_qty := (v_item->>'quantity')::integer;
    if v_qty < 1 or v_qty > 20 then raise exception 'Invalid item quantity'; end if;
    select * into v_variant from public.product_variants
      where id = (v_item->>'variant_id')::uuid and is_active for update;
    if not found then raise exception 'A selected product option is unavailable'; end if;
    if not exists(select 1 from public.products p where p.id=v_variant.product_id and p.status='active') then
      raise exception 'A selected product is unavailable';
    end if;
    select coalesce(sum(i.quantity),0) into v_available
      from public.inventory i where i.variant_id=v_variant.id;
    if v_available < v_qty then raise exception 'Insufficient stock for a selected item'; end if;
    v_subtotal := v_subtotal + (v_variant.price_paise * v_qty);
  end loop;

  -- COD order is recorded and stock reserved atomically.
  v_total := v_subtotal;
  insert into public.orders(id,user_id,customer_name,email,phone,shipping_address,
    subtotal_paise,shipping_paise,total_paise,status,payment_method,payment_status)
  values(v_order_id,p_user_id,trim(p_customer_name),lower(trim(p_email)),p_phone,
    p_shipping_address,v_subtotal,0,v_total,'pending','cod','pending')
  returning orders.order_number into v_order_number;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_qty := (v_item->>'quantity')::integer;
    select * into v_variant from public.product_variants where id=(v_item->>'variant_id')::uuid;
    select p.name, v_variant.sku into v_name,v_sku from public.products p where p.id=v_variant.product_id;
    insert into public.order_items(order_id,variant_id,product_name,sku,size,color,unit_price_paise,quantity,line_total_paise)
    values(v_order_id,v_variant.id,v_name,v_sku,v_variant.size,v_variant.color,
      v_variant.price_paise,v_qty,v_variant.price_paise*v_qty);
    update public.inventory set quantity=quantity-v_qty
      where variant_id=v_variant.id and quantity > 0;
    if not found then raise exception 'Stock changed while placing the order. Please try again.'; end if;
  end loop;

  insert into public.order_status_history(order_id,status,note)
  values(v_order_id,'pending','COD order placed; stock reserved.');
  return query select v_order_id,v_order_number,v_total;
end;
$$;

revoke all on function public.place_cod_order(text,text,text,jsonb,jsonb,uuid) from public, anon, authenticated;
grant execute on function public.place_cod_order(text,text,text,jsonb,jsonb,uuid) to service_role;

-- Product/customer-facing data is still governed by RLS. Only admin may change inventory.
commit;
