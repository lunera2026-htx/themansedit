# THE MANS EDIT

Luxury editorial menswear storefront.

## Payment policy
**Cash on Delivery only.** UPI, cards, net banking and online payment gateways are intentionally excluded.

## Repository
- `index.html`, `styles.css`, `app.js`: current editorial storefront.
- `supabase/schema.sql`: initial database schema.
- `supabase/migrations/001_production_cod.sql`: additive COD-only production foundation.

## Database setup
1. Create a Supabase project.
2. Open SQL Editor.
3. Run `supabase/schema.sql` first (only if starting with a new project).
4. Run `supabase/migrations/001_production_cod.sql`.
5. Do not expose the service-role key in frontend files.

The migration adds variant-linked product images, customer addresses, CMS content, order status history, internal notes and a transactional COD order RPC. The RPC is restricted to the server-side `service_role`; it must be called only from a trusted Edge Function after input validation.

## Current limitation
The SQL migration is source-controlled but has not been executed or tested against a live Supabase project. The current public storefront still uses demo catalogue data and an in-memory cart. Do not accept real orders until Supabase, server-side checkout, admin authentication, storage policies and production testing are complete.

## Brand direction
Keep THE MANS EDIT's approved black/ivory/beige luxury editorial identity, serif display typography and clean sans-serif UI. LUNÉRA is a functional reference only.
