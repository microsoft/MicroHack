-- Migration 002: Add active and verified fields to suppliers table

ALTER TABLE suppliers ADD COLUMN active INTEGER NOT NULL DEFAULT 1;
ALTER TABLE suppliers ADD COLUMN verified INTEGER NOT NULL DEFAULT 0;
