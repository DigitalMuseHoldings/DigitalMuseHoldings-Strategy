# CollabHub AI Platform — Backend Audit (snapshot from provided ZIP)

## What I reviewed

- `app/main.py`
- `app/orchestrator/*` (LangGraph management + council graphs + checkpointers)
- `app/services/*` (provider router, agent runtime, session store, CrewAI orchestrator)
- `app/routes/*` (chat streaming, sessions, agents, approvals, crews)
- `app/db.py` and `app/veritas.py`

This audit is based on the ZIP you uploaded (not a live clone), so if your working directory differs, treat this as a “known-good reference” for comparing files.

## Executive summary

The codebase is a **good prototype foundation**, but it is **not production-safe yet** for the board’s reliability/scalability expectations.

Right now, multiple critical parts are **stubbed or in-memory**:

- **Session persistence** is in-memory (`InMemorySessionStore`).
- **VERA attribution** is referenced but **not implemented** (missing `VERAService`), and the crews route uses an in-memory ledger.
- **Database migrations/initialization** are incomplete: `init_db()` exists but is **not called at startup**, so tables may not exist.
- **LangGraph graphs** (management + council) are functional structurally, but currently return static/dummy outputs.
- There is **duplication/ambiguity** around checkpointers (`checkpointers.py` vs `checkpointer_factory.py`).

The path to a board-demo-ready backend is straightforward: **pick one orchestration path for the demo**, implement **a real DB-backed VERA ledger**, and make the app **fail-fast** on missing schema/config.

## Key strengths

1. **Clean API surface area (FastAPI)**
   - `/health` works and can be used by load balancers.
   - Routers split by domain (`routes/*`).

2. **Provider abstraction**
   - `services/provider_router.py` + `adapters/models.py` provides a single call path to multiple LLM providers.

3. **Streaming response path already exists**
   - `routes/chat.py` supports streaming and is usable by a UI immediately.

4. **Veritas signing primitive exists**
   - `app/veritas.py` provides signing & verification scaffolding.

## Critical gaps and risks

### 1) Persistence and horizontal scaling

- **Sessions / runtime state are in-memory** (`InMemorySessionStore`).
  - This breaks immediately under:
    - multiple workers (`uvicorn --workers > 1`)
    - multiple API replicas behind a load balancer
    - container restarts

**Recommendation:** Use Postgres for durable state and Redis for transient pub/sub.

### 2) Database schema lifecycle

- `app/db.py` defines async engine/session and has `init_db()` that creates the `approvals` table.
- But **`init_db()` is never called**, so a clean DB won’t have the table.

**Recommendation:** Add a startup hook that runs migrations (preferred) or at least runs `init_db()` for demo.

### 3) VERA attribution is a placeholder

- `routes/crews.py` references “VERA attribution” but stores attribution in a simple Python dict.
- `services/crewai_orchestrator.py` expects a `vera_service` object with:
  - `log_contribution(...)`
  - `log_crew_completion(...)`

…but **no `VERAService` implementation exists**.

**Recommendation:** Implement a DB-backed append-only ledger (schema provided separately) and ensure every agent action creates a ledger entry.

### 4) Orchestration duplication

There are at least two orchestration paths:

- **LangGraph**: `app/orchestrator/graph.py`, `app/orchestrator/council_graph.py`
- **CrewAI-style**: `app/services/crewai_orchestrator.py`

Running both in parallel increases debugging surface and creates “two sources of truth.”

**Recommendation (board demo):** choose one orchestration path as the official demo path, keep the other behind a feature flag.

### 5) Checkpointer confusion

- `app/orchestrator/checkpointers.py` defines `get_checkpointer()` returning `SqliteSaver.from_conn_string("runs.db")`.
- `app/orchestrator/checkpointer_factory.py` defines a different implementation returning `SqliteSaver("/app/runs.db")`.

**Recommendation:** delete one, standardize on a single `get_checkpointer()` that:
- selects Postgres if available,
- otherwise uses sqlite,
- is configured by env (`CHECKPOINT_DSN` / `CHECKPOINT_SQLITE_PATH`).

### 6) “Optional imports” hide broken features

`main.py` wraps some router imports in `try/except` and silently disables features if imports fail.

**Recommendation:** log the exception with stack trace and expose a `/diagnostics` endpoint listing enabled/disabled modules.

## Suggested “board demo” backend scope

To have a reliable demo platform for showing team collaboration and attribution:

1. **Session creation** (DB-backed)
2. **Chat streaming** (`/chat/stream`) wired to a real provider
3. **Crew run** endpoint (or LangGraph run endpoint) that:
   - creates a run record
   - logs each agent contribution into the VERA ledger
   - produces a final artifact
4. **Approvals flow** that:
   - references a decision id
   - writes approval record to DB

Everything else can be staged behind flags.

## Immediate code changes I recommend

1. Add app startup DB init / migrations:
   - If you aren’t using Alembic yet, at minimum call `await init_db()`.

2. Implement `app/services/vera_service.py` and wire it into CrewAI orchestrator.

3. Replace `InMemorySessionStore` with Postgres-backed session store (or Redis + Postgres hybrid).

4. Normalize the checkpointer strategy to **one** module.

5. Ensure Docker uses **Python 3.11** (works well with `asyncpg`, `pydantic`, `langgraph`).

## What likely caused your earlier Docker build errors

From your logs, one environment was building with **Python 3.13**, which causes native build failures for dependencies like `asyncpg` and some versions of `pydantic-core`.

This ZIP’s `app/Dockerfile` uses `python:3.11-slim` — keep it that way for now.

## What I need from you (optional)

- Confirm which orchestration approach the board wants for the demo:
  - LangGraph council/management graphs, or
  - Crew-based orchestrator

I can generate a commit-ready set of files for either path.
