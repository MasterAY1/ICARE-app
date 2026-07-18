-- Run this SQL in your Supabase SQL Editor to support Group Leader Name storage in the groups table:
ALTER TABLE public.groups ADD COLUMN IF NOT EXISTS leader_name TEXT;
