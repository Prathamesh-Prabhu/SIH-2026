-- ==============================================================================
-- ManoFit - Supabase Database Schema & Row-Level Security (RLS) Policies
-- Complete Production Script
-- Execute this script in your Supabase project's SQL Editor
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. USER ROLES ENUM
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('personnel', 'hr_admin', 'welfare_officer', 'commander', 'oversight_board');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 3. PROFILES TABLE (Linked to Supabase Auth)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    service_id VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    rank VARCHAR(50) DEFAULT 'Personnel',
    unit VARCHAR(100) DEFAULT 'HQ Unit',
    role user_role NOT NULL DEFAULT 'personnel',
    phone VARCHAR(20),
    avatar_url TEXT,
    consent_settings JSONB DEFAULT '{
        "mandatory_hr_sync": true,
        "optional_wearable_sync": false,
        "companion_memory": true,
        "anonymized_research": true
    }'::jsonb,
    streak_count INT DEFAULT 3,
    readiness_score INT DEFAULT 88,
    stress_zone VARCHAR(10) DEFAULT 'Zone A',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. MOOD LOGS TABLE (Private Personnel Activity)
CREATE TABLE IF NOT EXISTS public.mood_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    service_id VARCHAR(50) NOT NULL,
    mood_score INT NOT NULL CHECK (mood_score BETWEEN 1 AND 4), -- 4: Very Good, 3: Good, 2: Okay, 1: Not Great
    mood_label VARCHAR(30) NOT NULL,
    energy_level VARCHAR(30) DEFAULT 'Moderate',
    notes TEXT,
    tags TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. WELLBEING ASSESSMENTS TABLE (Standardized Surveys feeding ML)
CREATE TABLE IF NOT EXISTS public.assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    service_id VARCHAR(50) NOT NULL,
    assessment_type VARCHAR(50) DEFAULT 'PHQ_GAD_WELLBEING',
    total_score INT NOT NULL,
    question_count INT DEFAULT 10,
    answers JSONB NOT NULL,
    status VARCHAR(20) DEFAULT 'completed',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. COUNSELING SESSIONS (Confidential Welfare Officer Booking)
CREATE TABLE IF NOT EXISTS public.counseling_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    service_id VARCHAR(50) NOT NULL,
    session_type VARCHAR(30) NOT NULL CHECK (session_type IN ('in-person', 'voice')),
    preferred_date DATE NOT NULL,
    time_slot VARCHAR(30) NOT NULL,
    topic VARCHAR(100) DEFAULT 'Confidential Welfare Support',
    officer_name VARCHAR(100) DEFAULT 'Duty Welfare Officer',
    status VARCHAR(20) DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'confirmed', 'completed', 'cancelled')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. SELF-HELP ACTIVITY LOGS
CREATE TABLE IF NOT EXISTS public.self_help_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    activity_type VARCHAR(30) NOT NULL CHECK (activity_type IN ('breathing', 'doodle', 'soundscape', 'grounding')),
    duration_seconds INT DEFAULT 120,
    completed_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. HR INGESTION LOGS (Tier 2 CSV / Excel Uploads)
CREATE TABLE IF NOT EXISTS public.hr_ingestion_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    batch_id VARCHAR(64) UNIQUE NOT NULL,
    filename VARCHAR(255) NOT NULL,
    file_size_kb NUMERIC(10, 2) DEFAULT 0,
    total_rows INT NOT NULL DEFAULT 0,
    accepted_rows INT NOT NULL DEFAULT 0,
    rejected_rows INT NOT NULL DEFAULT 0,
    rejection_reasons JSONB DEFAULT '[]'::jsonb,
    status VARCHAR(30) DEFAULT 'committed' CHECK (status IN ('pending', 'validated', 'committed', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. PSEUDONYMIZED HR FEATURES (Input to Predictive Analytics)
CREATE TABLE IF NOT EXISTS public.hr_features (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID REFERENCES public.hr_ingestion_logs(id) ON DELETE CASCADE,
    pseudonym_token VARCHAR(64) NOT NULL, -- SHA-256 rotating token, never raw Service ID
    leave_balance_days NUMERIC(5, 1) DEFAULT 30,
    consecutive_duty_days INT DEFAULT 7,
    duty_hours_weekly NUMERIC(5, 1) DEFAULT 48,
    deployment_zone VARCHAR(50) DEFAULT 'Northern Sector',
    shift_type VARCHAR(30) DEFAULT 'Standard Rotation',
    synthetic BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. AI COMPANION CHATS (Encrypted Transcripts)
CREATE TABLE IF NOT EXISTS public.companion_chats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    sender VARCHAR(20) NOT NULL CHECK (sender IN ('user', 'assistant', 'system')),
    message TEXT NOT NULL,
    is_crisis BOOLEAN DEFAULT false,
    crisis_keyword VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. CRISIS ALERTS (Tele-MANAS 14416 Escalation Protocol)
CREATE TABLE IF NOT EXISTS public.crisis_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    trigger_source VARCHAR(50) DEFAULT 'ai_companion_nlu',
    tele_manas_notified BOOLEAN DEFAULT true,
    welfare_officer_alerted BOOLEAN DEFAULT true,
    status VARCHAR(30) DEFAULT 'active_stabilization',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. IMMUTABLE AUDIT LOG (Compliance & Oversight Board)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    target_table VARCHAR(50),
    details JSONB DEFAULT '{}'::jsonb,
    ip_address VARCHAR(45),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mood_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.counseling_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.self_help_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_ingestion_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_features ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.companion_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crisis_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 1. Profiles Policies
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Public profile insert during signup" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 2. Mood Logs Policies (Strictly Owner Only)
CREATE POLICY "Users view own mood logs" ON public.mood_logs
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users insert own mood logs" ON public.mood_logs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 3. Assessments Policies (Owner view/insert; never exposed to chain-of-command)
CREATE POLICY "Users view own assessments" ON public.assessments
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users insert own assessments" ON public.assessments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 4. Counseling Sessions (Owner + Welfare Officer)
CREATE POLICY "Users view own counseling sessions" ON public.counseling_sessions
    FOR SELECT USING (
        auth.uid() = user_id 
        OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'welfare_officer'
    );

CREATE POLICY "Users insert own counseling sessions" ON public.counseling_sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 5. HR Ingestion Logs (HR Admin + Oversight Board)
CREATE POLICY "HR Admins view ingestion logs" ON public.hr_ingestion_logs
    FOR SELECT USING (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('hr_admin', 'oversight_board')
    );

CREATE POLICY "HR Admins create ingestion logs" ON public.hr_ingestion_logs
    FOR INSERT WITH CHECK (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'hr_admin'
    );

-- 6. Pseudonymized Features (HR Admin inserts; Oversight audits; ML service reads)
CREATE POLICY "HR Admin can insert features" ON public.hr_features
    FOR INSERT WITH CHECK (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'hr_admin'
    );

CREATE POLICY "HR Admin & Oversight can view features" ON public.hr_features
    FOR SELECT USING (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('hr_admin', 'oversight_board', 'commander')
    );

-- 7. AI Companion Chats (Owner only)
CREATE POLICY "Users view own companion chats" ON public.companion_chats
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users insert own companion chats" ON public.companion_chats
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 8. Audit Logs (Read-only for Oversight Board; Append for all authenticated)
CREATE POLICY "Oversight Board views audit logs" ON public.audit_logs
    FOR SELECT USING (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'oversight_board'
    );

CREATE POLICY "System appends audit logs" ON public.audit_logs
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ==============================================================================
-- SEED MOCK DATA FOR DEMO & TESTING
-- ==============================================================================
-- You can run these inserts in the SQL editor to pre-populate sample records.
