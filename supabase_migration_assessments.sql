-- ============================================================================
-- ManoFit — assessments migration: the 6 private check-ins (PRD §7)
-- Run in the Supabase SQL editor, after supabase_schema.sql.
-- Safe to re-run.
--
-- The analytics layer reads these six as named 1–5 columns rather than digging
-- through the `answers` JSONB. Scale direction is a contract with the model:
--   higher = WORSE : workload_perception, physical_exhaustion
--   higher = BETTER: sleep_quality, mood_rating, manager_relationship,
--                    peer_social_support
-- ============================================================================

alter table public.assessments
  add column if not exists workload_perception  smallint,
  add column if not exists sleep_quality        smallint,
  add column if not exists physical_exhaustion  smallint,
  add column if not exists mood_rating          smallint,
  add column if not exists manager_relationship smallint,
  add column if not exists peer_social_support  smallint;

-- 1–5 bounds (added separately so re-runs don't error on existing constraints).
do $$
declare
  col text;
begin
  foreach col in array array[
    'workload_perception','sleep_quality','physical_exhaustion',
    'mood_rating','manager_relationship','peer_social_support'
  ]
  loop
    if not exists (
      select 1 from pg_constraint
      where conrelid = 'public.assessments'::regclass
        and conname  = 'assessments_' || col || '_range'
    ) then
      execute format(
        'alter table public.assessments add constraint %I check (%I is null or %I between 1 and 5)',
        'assessments_' || col || '_range', col, col
      );
    end if;
  end loop;
end $$;

-- `answers` is written by the app but must never be required.
alter table public.assessments alter column answers drop not null;
alter table public.assessments alter column answers set default '{}'::jsonb;

-- New rows are the six-item check-in.
alter table public.assessments
  alter column assessment_type set default 'SIX_CHECKIN_V1';

-- The ML service reads assessments (architecture §data-layer, line 123).
-- Owner-only read/insert already exists from supabase_schema.sql; index the
-- scoring path (per user, newest first).
create index if not exists assessments_user_created_idx
  on public.assessments (user_id, created_at desc);

-- ── Verify ──────────────────────────────────────────────────────────────────
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'assessments'
order by ordinal_position;
