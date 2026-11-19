# Mobily content calendar — notes for Claude

Internal tool for Mohammed and Ali to plan Mobily's social posts month by month.
Live at https://mobily-calendar.vercel.app — every push to `main` deploys automatically on Vercel.

## Stack
- **No build step.** `index.html` is the whole app (HTML + CSS + JS in one file). `config.js` holds the Supabase URL and anon key (public by design).
- **Supabase** project `mobily-calendar` (ref `uwcdhpptemykyivfmqvd`):
  - table `public.posts` — `id, date ('YYYY-MM-DD'), time ('HH:MM' or ''), caption, media (jsonb [{path,type}]), design, animation, links (jsonb {X,Instagram,Facebook,TikTok,Snapchat}), landing, note, updated_at`
  - private storage bucket `media`; the app shows files through signed URLs
  - **No sign-in (Mohammed's decision, 19 Nov 2026):** RLS lets the anon key read and write `posts`, `dictionary`, the `media` bucket, and read `activity`. Anyone with the link can view and edit. See `supabase/open-access.sql`.
  - The site asks once per browser «مين أنت؟» (محمد / علي), keeps it in localStorage, and sends it as the `x-actor` header; the activity trigger records it as the actor.
  - realtime is on for `posts`, so open pages refresh by themselves.
  - table `public.dictionary` — shared spelling whitelist (`word`).
  - table `public.activity` — change log filled by the `posts_activity` trigger (who did what to which post). Kept 90 days. See `supabase/activity.sql`.
  - schema lives in `supabase/schema.sql`.
- Libraries come from CDNs (supabase-js, ExcelJS, JSZip). Pin exact versions.

## Product rules (agreed with Mohammed)
- UI is Arabic, RTL, Saudi dialect, light Apple-style grey with frosted-glass surfaces. No dark mode.
- A post is **not ready** (yellow highlight + reason badges) when it has no image, no design-files link, no caption, no time, or no platform links. If `landing` is filled but short links are missing it shows "بانتظار الاختصار". It turns normal by itself once fixed.
- Platform short links are collapsed in the editor; the landing (original) URL field is always visible and is **never** exported to Excel.
- Time picker: one-tap presets 11:00 / 15:00 / 19:00 (marked «محجوز» if another post that day uses it; new posts auto-pick the first free one), plus «وقت ثاني» (hour select, minutes 00/15/30/45, AM ☀ / PM ☾) and «بدون وقت».
- Date picker: a week strip with post-count dots per day, plus an optional month grid.
- «آخر التحديثات» sidebar on the left (content changes + dev commits); it can be hidden, and the choice is remembered per browser.
- Post cards are compact (~200px wide).
- Excel export keeps the team's sheet layout (Date / Time / Visual / Caption / Design / Animation / Platform / Landing Page), with an option to keep only the Snapchat link. Excel import reads the same layout.
- No approval buttons; the site is only for the two editors.
- Caption spelling review uses the public LanguageTool API (Arabic). It only flags issues and suggestions, it never edits the caption. Words marked "مو غلط" go into the shared `public.dictionary` table and are skipped next time.

## Working on it
- **Commit messages: write the first line in simple Arabic** describing the change for a non-technical reader (e.g. «إضافة فلتر حسب المنصة»). The site's «آخر التحديثات» sidebar shows that line to Mohammed and Ali as a development update. Technical detail can go in the body.
- Edit `index.html`, test locally with any static server, commit to `main`, push. Vercel deploys in ~10 s.
- Keep everything in one file unless there's a strong reason not to.
- Never commit the Supabase service-role key or any secret.
