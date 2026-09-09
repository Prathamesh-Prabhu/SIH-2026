-- ==============================================================================
-- ManoFit - System Configuration & Dynamic Service Discovery Schema
-- Allows start-backends.ps1 to publish dynamic tunnel URLs and Flutter clients
-- to automatically discover live Tara and ML services without manual URL pasting.
-- Execute this script in your Supabase project's SQL Editor:
-- https://supabase.com/dashboard/project/ognnnttqjbvmvjfvlpia/sql
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.system_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row-Level Security
ALTER TABLE public.system_config ENABLE ROW LEVEL SECURITY;

-- Allow any client (anon) to read service endpoints
DROP POLICY IF EXISTS "Allow public read on system_config" ON public.system_config;
CREATE POLICY "Allow public read on system_config"
    ON public.system_config FOR SELECT
    USING (true);

-- Allow backend script (anon or authenticated) to upsert service endpoints
DROP POLICY IF EXISTS "Allow public upsert on system_config" ON public.system_config;
CREATE POLICY "Allow public upsert on system_config"
    ON public.system_config FOR ALL
    USING (true)
    WITH CHECK (true);

-- Insert initial placeholder entries
INSERT INTO public.system_config (key, value)
VALUES
    ('ml_url', 'http://localhost:8000'),
    ('tara_url', 'http://localhost:3000')
ON CONFLICT (key) DO NOTHING;
