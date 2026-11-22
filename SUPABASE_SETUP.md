# THE MANS EDIT — Supabase project setup

This guide is for connecting the repository to a new Supabase project. The project has **not** been created or connected yet, so no live database changes have been made.

## 1. Create the project

1. Open https://supabase.com and sign in to the account that will own the store infrastructure.
2. Create a new project named `the-mans-edit`.
3. Choose a region in India (Mumbai, if offered) to keep the database near customers.
4. Set a strong database password and store it in a password manager. Do not put it in GitHub, website code, screenshots, or chat.
5. Wait until the project finishes provisioning.

If the provider requires the account holder to meet an age requirement or accept business/legal terms, a parent or guardian should own and manage that account. Do not enter a false date of birth.

## 2. Create the database schema

1. In the Supabase project, open **SQL Editor**.
2. Open this repository file: `supabase/schema.sql`.
3. Copy its complete contents into a new SQL query and run it once on this empty project.
4. Then open `supabase/migrations/001_production_cod.sql`, copy the complete contents into a second query, and run it.
5. Check the SQL Editor result for errors before continuing.

The first file creates the initial tables and policies. The migration upgrades the schema to the final **Cash on Delivery only** order rule and adds the transactional order-placement foundation. Do not run the initial schema repeatedly on an already initialized database.

## 3. Keep credentials private

In **Project Settings → API** (the menu wording may vary), copy:
- Project URL
- Publishable/anon public key

These two public-client values will be used by the storefront. Never expose the database password or the `service_role` secret in browser code, public GitHub files, or messages. The service-role secret belongs only in the Supabase Edge Function secret settings.

## 4. What is deliberately not enabled yet

- Do not accept real customer orders yet.
- The COD Edge Function still needs deployment and secret configuration.
- Admin account creation and role promotion must be done securely by the project owner; public sign-up must never grant admin.
- Product images need a private/admin-managed upload policy and a public read policy.
- The storefront must be connected to this project's URL and public key, then tested end-to-end before launch.

## 5. Send only the safe connection details

Once the project exists, the Project URL and publishable/anon key can be entered into the site's public configuration file. Never send the service-role key or database password.
