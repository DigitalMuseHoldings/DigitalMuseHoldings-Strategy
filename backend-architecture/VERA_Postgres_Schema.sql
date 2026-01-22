-- VERA (Verifiable Attribution) — PostgreSQL schema
-- Goal: durable, append-only attribution ledger that supports human + agent contributions.

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Optional (if you plan embeddings later)
-- CREATE EXTENSION IF NOT EXISTS vector;

-- Workspaces (maps to your ChatGPT Business workspace / org, etc.)
CREATE TABLE IF NOT EXISTS workspaces (
  workspace_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Human users
CREATE TABLE IF NOT EXISTS users (
  user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  handle TEXT,
  email TEXT,
  display_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- AI agents (Claude, ChatGPT, ManusAI, Gemini, etc.)
CREATE TABLE IF NOT EXISTS agents (
  agent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  provider TEXT NOT NULL,          -- e.g. openai/anthropic/google
  model TEXT,                      -- e.g. gpt-4.1, claude-3.5
  name TEXT NOT NULL,              -- display name
  config JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Collaboration sessions (board demo can start here)
CREATE TABLE IF NOT EXISTS sessions (
  session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  created_by UUID REFERENCES users(user_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Messages (human + agent) — keep raw content + metadata
CREATE TABLE IF NOT EXISTS messages (
  message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  session_id UUID REFERENCES sessions(session_id) ON DELETE CASCADE,
  author_type TEXT NOT NULL CHECK (author_type IN ('human','agent','system')),
  author_user_id UUID REFERENCES users(user_id),
  author_agent_id UUID REFERENCES agents(agent_id),
  role TEXT NOT NULL,              -- user/assistant/system
  content TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Artifacts produced by runs (docs, code patches, decisions, images, etc.)
CREATE TABLE IF NOT EXISTS artifacts (
  artifact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  session_id UUID REFERENCES sessions(session_id) ON DELETE SET NULL,
  kind TEXT NOT NULL,              -- e.g. 'plan','spec','patch','report'
  title TEXT,
  uri TEXT,                        -- optional pointer to object storage / git / file
  content TEXT,                    -- small artifacts can be stored directly
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Decisions (e.g. council decision) — links to approvals
CREATE TABLE IF NOT EXISTS decisions (
  decision_id TEXT PRIMARY KEY,    -- e.g. dec_20260120T235959Z
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  session_id UUID REFERENCES sessions(session_id) ON DELETE SET NULL,
  recommendation TEXT NOT NULL,
  votes JSONB NOT NULL DEFAULT '{}'::jsonb,
  summary TEXT,
  veritas_bundle JSONB NOT NULL DEFAULT '{}'::jsonb, -- store signed bundle payload (not just an id)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Approvals (already in code; use UUID or keep your current id style)
CREATE TABLE IF NOT EXISTS approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id TEXT NOT NULL REFERENCES decisions(decision_id) ON DELETE CASCADE,
  approver TEXT NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- VERA ledger: append-only attribution entries (this is the core)
-- Idea: every meaningful action produces a ledger entry.
CREATE TABLE IF NOT EXISTS vera_ledger (
  entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  session_id UUID REFERENCES sessions(session_id) ON DELETE SET NULL,

  -- who contributed
  actor_type TEXT NOT NULL CHECK (actor_type IN ('human','agent','system')),
  actor_user_id UUID REFERENCES users(user_id),
  actor_agent_id UUID REFERENCES agents(agent_id),

  -- what they contributed to
  entity_type TEXT NOT NULL,       -- message/artifact/decision/task/commit/etc.
  entity_id TEXT NOT NULL,         -- UUID string, git sha, task id, etc.
  action TEXT NOT NULL,            -- create/edit/review/approve/merge/run/etc.

  -- value attribution
  points NUMERIC(18,6) NOT NULL DEFAULT 0,   -- attribution points (can be normalized later)
  cost_usd NUMERIC(18,6) NOT NULL DEFAULT 0, -- optional (API cost, compute)
  tokens_in INT,
  tokens_out INT,

  -- integrity + flexibility
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

  -- tamper-evidence (simple hash chain)
  prev_hash TEXT,
  entry_hash TEXT NOT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vera_ledger_workspace_time ON vera_ledger(workspace_id, created_at);
CREATE INDEX IF NOT EXISTS idx_vera_ledger_session_time   ON vera_ledger(session_id, created_at);
CREATE INDEX IF NOT EXISTS idx_vera_ledger_actor_agent    ON vera_ledger(actor_agent_id);
CREATE INDEX IF NOT EXISTS idx_vera_ledger_actor_user     ON vera_ledger(actor_user_id);

-- Optional rollups for UI dashboards
CREATE TABLE IF NOT EXISTS vera_rollups_daily (
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  day DATE NOT NULL,
  actor_type TEXT NOT NULL,
  actor_user_id UUID,
  actor_agent_id UUID,
  points NUMERIC(18,6) NOT NULL,
  cost_usd NUMERIC(18,6) NOT NULL,
  PRIMARY KEY (workspace_id, day, actor_type, actor_user_id, actor_agent_id)
);
