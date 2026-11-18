# Mobily content calendar

Static site (no build step) on Vercel, data in Supabase.

- `index.html` – the whole app
- `config.js` – Supabase URL + anon key (public by design; RLS protects data)
- `supabase/schema.sql` – table, row-level security, private `media` bucket

Only users invited in Supabase (Authentication → Users) can sign in; sign-ups are disabled.
Every push to `main` deploys automatically on Vercel.
