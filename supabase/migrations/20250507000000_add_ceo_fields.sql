-- Add CEO fields to companies table
ALTER TABLE companies ADD COLUMN IF NOT EXISTS ceo_first_name TEXT;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS ceo_last_name TEXT;
