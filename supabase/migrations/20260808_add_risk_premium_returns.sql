-- Migration: Add missing risk_premium_returns column back
-- The python app still expects this column

ALTER TABLE co_cashbooks ADD COLUMN IF NOT EXISTS risk_premium_returns NUMERIC DEFAULT 0;
ALTER TABLE master_cashbook ADD COLUMN IF NOT EXISTS risk_premium_returns NUMERIC DEFAULT 0;
