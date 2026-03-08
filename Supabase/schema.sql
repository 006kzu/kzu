-- Supabase Schema for Kzu Curriculum Engine
-- Run this in the Supabase SQL Editor to create the necessary table & policies

-- 1. Create the curriculum_units table
CREATE TABLE IF NOT EXISTS public.curriculum_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    unit_id TEXT UNIQUE NOT NULL,       -- Matches CurriculumUnit.unitId
    subject TEXT NOT NULL,              -- 'math', 'literacy', 'visionary'
    grade_min INTEGER NOT NULL,         -- Lower bound of grade range (e.g. 0 for K)
    grade_max INTEGER NOT NULL,         -- Upper bound of grade range
    visionary_theme TEXT,               -- 'ai', 'robotics', etc. (null for standard content)
    unit_data JSONB NOT NULL,           -- The full JSON representation of the CurriculumUnit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Add an index to speed up querying by subject and grade range
CREATE INDEX IF NOT EXISTS idx_curriculum_subject_grade 
ON public.curriculum_units (subject, grade_min, grade_max);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.curriculum_units ENABLE ROW LEVEL SECURITY;

-- 4. Create a policy that allows ANYONE to read (SELECT) the curriculum units
-- Since curriculum is public data for the app to consume, no auth token is required for read access.
CREATE POLICY "Allow public read access to curriculum units"
ON public.curriculum_units FOR SELECT
USING (true);

-- Note: 
-- You will insert/update units through the Supabase Dashboard UI or an authenticated admin script.
-- The app itself will only ever READ (Select) from this table anonymously.
