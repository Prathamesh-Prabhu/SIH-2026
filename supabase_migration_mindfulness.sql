-- ============================================================================
-- ManoFit — Mindfulness section + test logins  (run once in the Supabase SQL
-- editor, after supabase_schema.sql). Everything new lives in this one file.
--
--   PART A  Mindfulness tables + RLS
--             public.mindfulness_logs   breathing + meditation sessions
--             public.mindfulness_moods  Samsung-style 5-point mood check-ins
--
--   PART B  Two extra logins (Service ID -> <slug>@manofit.app):
--             login "cadet" / password123  -> role personnel  (mobile app + Mindfulness)
--             login "admin" / password123  -> role hr_admin   (HR console)
--
-- Safe to re-run. PART B only ever touches those two accounts.
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════════
-- PART A — MINDFULNESS
-- ════════════════════════════════════════════════════════════════════════════

-- 1. MINDFULNESS ACTIVITY LOGS (breathing + meditation)
CREATE TABLE IF NOT EXISTS public.mindfulness_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    service_id VARCHAR(50),
    activity_type VARCHAR(20) NOT NULL CHECK (activity_type IN ('breathing', 'meditation', 'doodle')),
    title VARCHAR(120) NOT NULL,          -- 'Box' / 'Daily Calm' / 'Zen Doodling'
    category VARCHAR(40),                 -- 'Relaxation' / 'Sleep' / 'Music' / 'Creative' ...
    pattern VARCHAR(20),                  -- breathing only: '4-4-4-4'
    planned_seconds INT DEFAULT 0,
    actual_seconds INT DEFAULT 0,
    cycles_completed INT DEFAULT 0,
    completed BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mindfulness_logs_user_time
    ON public.mindfulness_logs (user_id, created_at DESC);

-- Widen activity_type if the table pre-dates the 'doodle' activity.
ALTER TABLE public.mindfulness_logs
    DROP CONSTRAINT IF EXISTS mindfulness_logs_activity_type_check;
ALTER TABLE public.mindfulness_logs
    ADD CONSTRAINT mindfulness_logs_activity_type_check
    CHECK (activity_type IN ('breathing', 'meditation', 'doodle'));

-- 2. MINDFULNESS MOOD CHECK-INS (5-point scale + contributing factors)
CREATE TABLE IF NOT EXISTS public.mindfulness_moods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    service_id VARCHAR(50),
    mood_level INT NOT NULL CHECK (mood_level BETWEEN 1 AND 5), -- 5 Awesome … 1 Terrible
    mood_label VARCHAR(20) NOT NULL,
    factors TEXT[] DEFAULT '{}',
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mindfulness_moods_user_time
    ON public.mindfulness_moods (user_id, created_at DESC);

-- 3. ROW LEVEL SECURITY — owner only, select + insert
ALTER TABLE public.mindfulness_logs  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mindfulness_moods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view own mindfulness logs" ON public.mindfulness_logs;
CREATE POLICY "Users view own mindfulness logs" ON public.mindfulness_logs
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own mindfulness logs" ON public.mindfulness_logs;
CREATE POLICY "Users insert own mindfulness logs" ON public.mindfulness_logs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users view own mindfulness moods" ON public.mindfulness_moods;
CREATE POLICY "Users view own mindfulness moods" ON public.mindfulness_moods
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own mindfulness moods" ON public.mindfulness_moods;
CREATE POLICY "Users insert own mindfulness moods" ON public.mindfulness_moods
    FOR INSERT WITH CHECK (auth.uid() = user_id);


-- ════════════════════════════════════════════════════════════════════════════
-- PART B — TEST LOGINS  (cadet / admin, password123)
-- ════════════════════════════════════════════════════════════════════════════

-- B1. Create the two auth users if missing; otherwise reset their password.
DO $$
DECLARE
  v_pass text := 'password123';
  r record;
  v_uid uuid;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('cadet@manofit.app'),
      ('admin@manofit.app')
    ) AS t(email)
  LOOP
    SELECT id INTO v_uid FROM auth.users WHERE email = r.email;

    IF v_uid IS NULL THEN
      v_uid := gen_random_uuid();

      -- Every text token column MUST be '' (never NULL) or GoTrue's login
      -- query fails with "Database error querying schema".
      INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, created_at, updated_at,
        raw_app_meta_data, raw_user_meta_data,
        confirmation_token, recovery_token, email_change_token_new,
        email_change, email_change_token_current, phone_change,
        phone_change_token, reauthentication_token,
        email_change_confirm_status, is_sso_user, is_anonymous
      ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        v_uid, 'authenticated', 'authenticated', r.email,
        crypt(v_pass, gen_salt('bf')),
        now(), now(), now(),
        '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
        '', '', '', '', '', '', '', '',
        0, false, false
      );

      INSERT INTO auth.identities (
        provider_id, user_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at
      ) VALUES (
        v_uid::text, v_uid,
        jsonb_build_object('sub', v_uid::text, 'email', r.email),
        'email', now(), now(), now()
      );
    ELSE
      UPDATE auth.users
         SET encrypted_password = crypt(v_pass, gen_salt('bf')),
             email_confirmed_at = coalesce(email_confirmed_at, now()),
             updated_at = now()
       WHERE id = v_uid;
    END IF;
  END LOOP;
END $$;

-- B2. Repair NULL token columns on these rows (safe every run).
UPDATE auth.users SET
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
WHERE email IN ('cadet@manofit.app', 'admin@manofit.app');

-- B3. Matching public.profiles rows.
INSERT INTO public.profiles
  (id, service_id, full_name, rank, unit, role, phone,
   streak_count, readiness_score, stress_zone)
SELECT u.id, v.service_id, v.full_name, v.rank, v.unit, v.role::user_role,
       v.phone, v.streak_count, v.readiness_score, v.stress_zone
FROM (VALUES
  ('cadet@manofit.app', 'CADET', 'Cadet Test', 'Cadet',          'Training Battalion', 'personnel', '+91 90000 00001', 0, 80, 'Zone A'),
  ('admin@manofit.app', 'ADMIN', 'Admin Test', 'Inspector (HR)', 'Sector HQ HR Cell',  'hr_admin',  '+91 90000 00002', 0, 90, 'Optimal')
) AS v(email, service_id, full_name, rank, unit, role, phone,
       streak_count, readiness_score, stress_zone)
JOIN auth.users u ON u.email = v.email
ON CONFLICT (id) DO UPDATE SET
  service_id = excluded.service_id,
  full_name  = excluded.full_name,
  rank       = excluded.rank,
  unit       = excluded.unit,
  role       = excluded.role,
  phone      = excluded.phone,
  updated_at = now();

-- B4. Verify.
SELECT p.service_id, p.full_name, p.role, u.email
FROM public.profiles p
JOIN auth.users u ON u.id = p.id
WHERE u.email IN ('cadet@manofit.app', 'admin@manofit.app');
