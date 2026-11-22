# THE MANS EDIT — implementation status

Last repository inspection: 2026-11-22.

## Confirmed existing files
- Responsive editorial storefront in HTML/CSS.
- Demo-only catalogue and in-memory cart.
- Category filter and text search.
- Supabase starter schema, not yet connected to a live Supabase project.

## Current milestone
- Added a production-oriented SQL migration for COD-only orders.
- Added colour/size variant image relationships and catalogue metadata.
- Added saved customer addresses, editable homepage content, order status history and private admin notes.
- Added transactional server-only COD order placement with database price lookup, stock locking/reservation, validation and duplicate-safe order-number generation.

## Next setup dependency\n- Supabase project has not been created yet. A step-by-step setup guide is in `SUPABASE_SETUP.md`.\n\n## Not yet live or verified
- This migration has not been executed against a Supabase project.
- No Supabase URL/anon key has been configured in the frontend.
- No Edge Function has yet been deployed to call the COD order RPC.
- Admin UI/auth flows, customer login, real catalogue CRUD, persistent image upload, customer order tracking, email, shipping and full mobile/end-to-end tests remain to be implemented.
- No live website deployment has been verified.

## Payment rule — final
THE MANS EDIT accepts Cash on Delivery only. UPI, cards, net banking, payment gateway code and online payment collection are excluded.

## Required security setup
- Admin access must be granted manually to a verified account by a trusted project owner; public signup must never grant admin.
- Supabase service-role key is server-only and must never be committed or placed in browser JavaScript.
- Public clients must never be allowed to call the privileged COD RPC directly.
