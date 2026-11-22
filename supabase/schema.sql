-- THE MANS EDIT initial database foundation. Run in Supabase SQL Editor.
create extension if not exists pgcrypto;
create type public.app_role as enum ('customer','admin');
create type public.order_status as enum ('pending','confirmed','processing','shipped','delivered','cancelled');
create table public.profiles(id uuid primary key references auth.users(id) on delete cascade,full_name text,phone text,role public.app_role not null default 'customer',created_at timestamptz not null default now());
create table public.categories(id uuid primary key default gen_random_uuid(),name text not null unique,slug text not null unique,is_active boolean not null default true);
create table public.products(id uuid primary key default gen_random_uuid(),category_id uuid references public.categories(id),name text not null,slug text not null unique,description text,status text not null default 'draft' check(status in ('draft','active','archived')),created_at timestamptz not null default now());
create table public.product_images(id uuid primary key default gen_random_uuid(),product_id uuid not null references public.products(id) on delete cascade,image_url text not null,sort_order int not null default 0);
create table public.product_variants(id uuid primary key default gen_random_uuid(),product_id uuid not null references public.products(id) on delete cascade,sku text not null unique,size text,color text,price_paise bigint not null check(price_paise>=0),is_active boolean not null default true,unique(product_id,size,color));
create table public.inventory_locations(id uuid primary key default gen_random_uuid(),name text not null unique,location_type text not null check(location_type in('store','warehouse')));
create table public.inventory(id uuid primary key default gen_random_uuid(),variant_id uuid not null references public.product_variants(id) on delete cascade,location_id uuid not null references public.inventory_locations(id) on delete cascade,quantity int not null default 0 check(quantity>=0),unique(variant_id,location_id));
create table public.orders(id uuid primary key default gen_random_uuid(),order_number bigint generated always as identity unique,user_id uuid references auth.users(id) on delete set null,customer_name text not null,email text not null,phone text not null,shipping_address jsonb not null,subtotal_paise bigint not null check(subtotal_paise>=0),shipping_paise bigint not null default 0,total_paise bigint not null check(total_paise>=0),status public.order_status not null default 'pending',payment_method text not null check(payment_method in('cod','card','netbanking')),payment_status text not null default 'pending',created_at timestamptz not null default now());
create table public.order_items(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.orders(id) on delete cascade,variant_id uuid references public.product_variants(id) on delete set null,product_name text not null,sku text,size text,color text,unit_price_paise bigint not null,quantity int not null check(quantity>0),line_total_paise bigint not null);
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path='' as $$ begin insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','')); return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.profiles where id=(select auth.uid()) and role='admin'); $$;
alter table public.profiles enable row level security; alter table public.categories enable row level security; alter table public.products enable row level security; alter table public.product_images enable row level security; alter table public.product_variants enable row level security; alter table public.inventory_locations enable row level security; alter table public.inventory enable row level security; alter table public.orders enable row level security; alter table public.order_items enable row level security;
create policy "profile self read" on public.profiles for select to authenticated using(id=(select auth.uid()) or public.is_admin());
create policy "profile self update" on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()) and role='customer');
create policy "public active categories" on public.categories for select to anon,authenticated using(is_active or public.is_admin());
create policy "public active products" on public.products for select to anon,authenticated using(status='active' or public.is_admin());
create policy "public product images" on public.product_images for select to anon,authenticated using(exists(select 1 from public.products p where p.id=product_id and (p.status='active' or public.is_admin())));
create policy "public active variants" on public.product_variants for select to anon,authenticated using((is_active and exists(select 1 from public.products p where p.id=product_id and p.status='active')) or public.is_admin());
create policy "admin manage profiles" on public.profiles for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin manage categories" on public.categories for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin manage products" on public.products for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin manage images" on public.product_images for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin manage variants" on public.product_variants for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin manage locations" on public.inventory_locations for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin manage inventory" on public.inventory for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "customer read own orders" on public.orders for select to authenticated using(user_id=(select auth.uid()) or public.is_admin());
create policy "admin manage orders" on public.orders for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "customer read own items" on public.order_items for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id and (o.user_id=(select auth.uid()) or public.is_admin())));
create policy "admin manage items" on public.order_items for all to authenticated using(public.is_admin()) with check(public.is_admin());
-- Checkout must be implemented server-side with atomic stock validation and verified payment callbacks.
-- UPI is deliberately not an accepted payment method. Only COD, card and netbanking are planned.
