# THE MANS EDIT — build status

## Committed
- Editorial responsive storefront shell
- Collection navigation, category filtering and product search
- Demo product cards and client-side bag interactions
- Newsletter interaction placeholder
- Initial Supabase relational schema and RLS policies
- Starter category/location seed data

## Not yet production-connected
- Supabase project has not been configured or SQL executed
- Product catalogue currently uses demo data and remote sample photography
- Customer sign-in, account, admin dashboard and inventory management
- Secure server-side checkout, order creation and stock reservation
- Payment gateway integration and verified payment webhooks
- Email notifications, shipping integration, returns and legal pages
- Browser/device and end-to-end tests

## Payment decision
UPI is excluded. Planned choices are Cash on Delivery and, only after a suitable provider is configured, card/netbanking. No payment method is represented as live until tested.

## Safety/security
Never commit API secrets. The Supabase service-role key belongs only in server-side secrets. Checkout must validate prices and stock server-side and must not trust totals supplied by the browser.
