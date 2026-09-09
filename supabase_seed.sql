-- ============================================================================
-- ManoFit — Phase 1 auth seed
-- Run AFTER supabase_schema.sql (tables + RLS) in the Supabase SQL editor.
--
-- Auth model: the app maps a Service ID onto a synthetic email
--   <service-id-lowercased, non-alphanumerics -> "-">@manofit.app
-- and signs in with Supabase email/password. Each auth user needs a matching
-- row in public.profiles (same id) or the app rejects the login.
--
-- Seeded logins (password for all: ManoFit@123):
--   CAPF-8821    -> capf-8821@manofit.app     personnel
--   HR-ADMIN-01  -> hr-admin-01@manofit.app   hr_admin
--   WELFARE-07   -> welfare-07@manofit.app    welfare_officer
--   CMD-UNIT-42  -> cmd-unit-42@manofit.app   commander
--   OVERSIGHT-01 -> oversight-01@manofit.app  oversight_board
-- ============================================================================

-- ── Step 1. Create the auth users ──────────────────────────────────────────
-- EASIEST / MOST RELIABLE: create them in the dashboard, then run Step 2.
--   Authentication -> Users -> "Add user"
--   * Email:  capf-8821@manofit.app   Password: ManoFit@123
--   * tick "Auto Confirm User"
--   repeat for the other three emails above.
--
-- OR do it in SQL with this block (works on current Supabase/GoTrue):

do $$
declare
  v_pass text := 'ManoFit@123';
  r record;
  v_uid uuid;
begin
  for r in
    select * from (values
      ('capf-8821@manofit.app'),
      ('hr-admin-01@manofit.app'),
      ('welfare-07@manofit.app'),
      ('cmd-unit-42@manofit.app'),
      ('oversight-01@manofit.app')
    ) as t(email)
  loop
    select id into v_uid from auth.users where email = r.email;

    if v_uid is null then
      v_uid := gen_random_uuid();

      -- NOTE: every text token column MUST be '' (never NULL) or GoTrue's
      -- login query fails with "Database error querying schema".
      insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, created_at, updated_at,
        raw_app_meta_data, raw_user_meta_data,
        confirmation_token, recovery_token, email_change_token_new,
        email_change, email_change_token_current, phone_change,
        phone_change_token, reauthentication_token,
        email_change_confirm_status, is_sso_user, is_anonymous
      ) values (
        '00000000-0000-0000-0000-000000000000',
        v_uid, 'authenticated', 'authenticated', r.email,
        crypt(v_pass, gen_salt('bf')),
        now(), now(), now(),
        '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
        '', '', '', '', '', '', '', '',
        0, false, false
      );

      insert into auth.identities (
        provider_id, user_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at
      ) values (
        v_uid::text, v_uid,
        jsonb_build_object('sub', v_uid::text, 'email', r.email),
        'email', now(), now(), now()
      );
    end if;
  end loop;
end $$;

-- ── Step 1b. Repair any auth.users rows that already have NULL token columns
-- (safe to run every time; only touches the seeded @manofit.app accounts).
update auth.users set
  confirmation_token          = coalesce(confirmation_token, ''),
  recovery_token              = coalesce(recovery_token, ''),
  email_change_token_new      = coalesce(email_change_token_new, ''),
  email_change                = coalesce(email_change, ''),
  email_change_token_current  = coalesce(email_change_token_current, ''),
  phone_change                = coalesce(phone_change, ''),
  phone_change_token          = coalesce(phone_change_token, ''),
  reauthentication_token      = coalesce(reauthentication_token, ''),
  email_change_confirm_status = coalesce(email_change_confirm_status, 0),
  is_sso_user                 = coalesce(is_sso_user, false),
  is_anonymous                = coalesce(is_anonymous, false)
where email like '%@manofit.app';

-- ── Step 2. Create / refresh the matching profile rows ─────────────────────
insert into public.profiles
  (id, service_id, full_name, rank, unit, role, phone,
   streak_count, readiness_score, stress_zone)
select u.id, v.service_id, v.full_name, v.rank, v.unit, v.role::user_role,
       v.phone, v.streak_count, v.readiness_score, v.stress_zone
from (values
  ('capf-8821@manofit.app',   'CAPF-8821',   'Constable Dhruv',      'Constable',                   '144th Bn CAPF',                 'personnel',       '+91 98765 88214',  3,  88, 'Zone A'),
  ('hr-admin-01@manofit.app', 'HR-ADMIN-01', 'Inspector Sharma',     'Inspector (HR)',              'Sector HQ HR Cell',             'hr_admin',        '+91 98111 22334', 12,  92, 'Optimal'),
  ('welfare-07@manofit.app',  'WELFARE-07',  'Dr. Ananya Varma',     'Clinical Welfare Officer',    'Medical & Psychological Wing',  'welfare_officer', '+91 99222 33445', 20,  95, 'Optimal'),
  ('cmd-unit-42@manofit.app', 'CMD-UNIT-42', 'Col. Rajesh Rao',      'Commandant',                  'Northern Frontier Command',     'commander',       '+91 97333 44556', 15,  90, 'Optimal'),
  ('oversight-01@manofit.app','OVERSIGHT-01','Oversight Board Member','Ethics & Oversight Board',    'Independent Review Panel',      'oversight_board', '+91 96444 55667',  0,   0, 'N/A')
) as v(email, service_id, full_name, rank, unit, role, phone,
       streak_count, readiness_score, stress_zone)
join auth.users u on u.email = v.email
on conflict (id) do update set
  service_id      = excluded.service_id,
  full_name       = excluded.full_name,
  rank            = excluded.rank,
  unit            = excluded.unit,
  role            = excluded.role,
  phone           = excluded.phone,
  streak_count    = excluded.streak_count,
  readiness_score = excluded.readiness_score,
  stress_zone     = excluded.stress_zone,
  updated_at      = now();

-- ── Verify ────────────────────────────────────────────────────────────────
select p.service_id, p.full_name, p.role, u.email
from public.profiles p join auth.users u on u.id = p.id
order by p.role;
