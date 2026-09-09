-- ============================================================================
-- ManoFit — RBAC / anonymity migration
-- Run in the Supabase SQL editor AFTER supabase_schema.sql. Safe to re-run.
--
-- Fixes four defects found auditing supabase_schema.sql against
-- manofit-architecture.md §3-§4 and manofit-prd.md §3.2, §6.4, §8:
--
--   1. hr_features was SELECT-able by hr_admin and commander. Architecture §3
--      scopes that table to "ML service + oversight audit only", and PRD §3.2
--      forbids any commander access to individual-level data — per-token duty,
--      leave and deployment rows are exactly that.
--   2. crisis_alerts had RLS enabled with NO policy, so the §4 Tele-MANAS
--      escalation path could neither write nor read. Same for self_help_logs.
--   3. risk_assessments (architecture §3, the ML layer's only write target)
--      did not exist.
--   4. CREATE POLICY is not idempotent, so re-running the schema errored.
--
-- Enforcement model: the ML microservice and Edge Functions connect with the
-- service_role key, which bypasses RLS. Every policy below therefore describes
-- what a *signed-in human* may reach. Where a table has no policy for an
-- action, that action is denied to all authenticated users by design.
-- ============================================================================

-- ── 1. hr_features — pseudonymized individual rows, audit access only ───────
-- Dropping the over-broad policy is the point of this migration; do not
-- re-add hr_admin or commander here.
drop policy if exists "HR Admin & Oversight can view features" on public.hr_features;
drop policy if exists "Oversight audit can view features"      on public.hr_features;

create policy "Oversight audit can view features" on public.hr_features
  for select using (
    (select role from public.profiles where id = auth.uid()) = 'oversight_board'
  );

-- HR Admin keeps INSERT (they supply the data) but loses read-back: PRD §6.4
-- scopes the role to data supply only. The existing insert policy stands; it is
-- recreated here so this file is self-contained and re-runnable.
drop policy if exists "HR Admin can insert features" on public.hr_features;
create policy "HR Admin can insert features" on public.hr_features
  for insert with check (
    (select role from public.profiles where id = auth.uid()) = 'hr_admin'
  );

-- ── 2. crisis_alerts — RLS was on with no policy, deadlocking §4 ────────────
drop policy if exists "Users insert own crisis alerts"    on public.crisis_alerts;
drop policy if exists "Welfare Officer views crisis alerts" on public.crisis_alerts;
drop policy if exists "Users view own crisis alerts"      on public.crisis_alerts;

-- The companion (running as the signed-in person) raises the alert.
create policy "Users insert own crisis alerts" on public.crisis_alerts
  for insert with check (auth.uid() = user_id);

-- The duty Welfare Officer is the human handoff in PRD §4.3 — and is the only
-- role that may read these. Commanders are deliberately excluded: a crisis
-- alert must never reach the chain of command (§7.6).
create policy "Welfare Officer views crisis alerts" on public.crisis_alerts
  for select using (
    (select role from public.profiles where id = auth.uid()) = 'welfare_officer'
  );

-- The person themself can see their own alert history.
create policy "Users view own crisis alerts" on public.crisis_alerts
  for select using (auth.uid() = user_id);

-- Welfare Officer works the alert through to closure.
drop policy if exists "Welfare Officer updates crisis alerts" on public.crisis_alerts;
create policy "Welfare Officer updates crisis alerts" on public.crisis_alerts
  for update using (
    (select role from public.profiles where id = auth.uid()) = 'welfare_officer'
  );

-- ── 3. self_help_logs — RLS on with no policy; owner-only activity data ─────
drop policy if exists "Users view own self help logs"   on public.self_help_logs;
drop policy if exists "Users insert own self help logs" on public.self_help_logs;

create policy "Users view own self help logs" on public.self_help_logs
  for select using (auth.uid() = user_id);

create policy "Users insert own self help logs" on public.self_help_logs
  for insert with check (auth.uid() = user_id);

-- ── 4. risk_assessments — the ML layer's only write target ──────────────────
-- Bands and explainability only. There is deliberately no column for a raw
-- probability: PRD §5 says a raw score is never persisted outside the model.
create table if not exists public.risk_assessments (
    id                          uuid primary key default gen_random_uuid(),
    pseudonym_token             varchar(64) not null,
    unit_code                   varchar(50),
    risk_band                   varchar(10) not null
                                  check (risk_band in ('LOW','MODERATE','ELEVATED')),
    confidence                  numeric(4,3) not null
                                  check (confidence between 0 and 1),
    top_factors                 jsonb not null default '[]'::jsonb,
    recommended_support_pathway text,
    model_version               varchar(30) not null,
    -- Human-in-the-loop gate (PRD §3.3): a model output is not a case until a
    -- Welfare Officer has reviewed it.
    clinically_reviewed         boolean default false,
    reviewed_by                 uuid references public.profiles(id) on delete set null,
    reviewed_at                 timestamptz,
    synthetic                   boolean default true,
    evaluated_at                timestamptz default now()
);

create index if not exists risk_assessments_token_idx
  on public.risk_assessments (pseudonym_token, evaluated_at desc);
create index if not exists risk_assessments_unit_idx
  on public.risk_assessments (unit_code, risk_band);

alter table public.risk_assessments enable row level security;

drop policy if exists "Welfare Officer views risk assessments"   on public.risk_assessments;
drop policy if exists "Welfare Officer records review"           on public.risk_assessments;
drop policy if exists "Oversight samples risk assessments"       on public.risk_assessments;

-- The ONLY role with individual-level read (PRD §8.1).
create policy "Welfare Officer views risk assessments" on public.risk_assessments
  for select using (
    (select role from public.profiles where id = auth.uid()) = 'welfare_officer'
  );

create policy "Welfare Officer records review" on public.risk_assessments
  for update using (
    (select role from public.profiles where id = auth.uid()) = 'welfare_officer'
  );

-- Oversight Board samples cases for the monthly validation loop (PRD §5).
create policy "Oversight samples risk assessments" on public.risk_assessments
  for select using (
    (select role from public.profiles where id = auth.uid()) = 'oversight_board'
  );

-- No INSERT policy: only the ML service (service_role) writes scores.
-- No policy for personnel or commanders: personnel never see their own band
-- (PRD §3.2) and commanders are confined to the aggregate view below.

-- ── 5. Commander aggregate view — the ONLY commander path to risk data ──────
-- A plain view runs with the owner's rights, so it reads through the RLS above
-- while the commander never gains row access to the table itself.
--
-- Small-cell suppression: a unit contributes to the view only when it has at
-- least 5 distinct personnel in the window. Without it, a 3-person outpost
-- showing "1 ELEVATED" re-identifies someone by arithmetic — the exact
-- stigmatization risk PRD §3.2 exists to prevent.
create or replace view public.unit_risk_distribution as
with latest as (
  select distinct on (pseudonym_token)
         pseudonym_token, unit_code, risk_band, evaluated_at
  from public.risk_assessments
  order by pseudonym_token, evaluated_at desc
)
select
  unit_code,
  count(distinct pseudonym_token)                                  as personnel_count,
  count(*) filter (where risk_band = 'LOW')                        as low_count,
  count(*) filter (where risk_band = 'MODERATE')                   as moderate_count,
  count(*) filter (where risk_band = 'ELEVATED')                   as elevated_count,
  max(evaluated_at)                                                as last_evaluated
from latest
where (select role from public.profiles where id = auth.uid())
        in ('commander', 'oversight_board')
group by unit_code
having count(distinct pseudonym_token) >= 5;

revoke all on public.unit_risk_distribution from anon;
grant select on public.unit_risk_distribution to authenticated;

-- ── 6. Audit log immutability ──────────────────────────────────────────────
-- No UPDATE or DELETE policy exists, so both are already denied to every
-- authenticated user (architecture §3: "immutable, append-only"). Asserted
-- here so a future edit that adds one is an obvious regression.
do $$
begin
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'audit_logs'
      and cmd in ('UPDATE', 'DELETE')
  ) then
    raise exception 'audit_logs must stay append-only: an UPDATE/DELETE policy exists';
  end if;
end $$;

-- ── Verify ─────────────────────────────────────────────────────────────────
select tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'public'
  and tablename in ('hr_features','crisis_alerts','self_help_logs','risk_assessments')
order by tablename, cmd, policyname;
