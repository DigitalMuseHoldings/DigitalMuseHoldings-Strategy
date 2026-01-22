# Ordonis Integration Plan (Asana / Jira Sync)

## Goal
Create a reliable “work orchestration spine” that keeps CollabHub sessions, tasks, and AI-agent work in sync with external project management tools (Asana, Jira) while maintaining verifiable attribution (VERA).

## Guiding principles

1. **One source of truth per field**
   - Decide which system owns:
     - task title/description
     - status
     - assignments
     - priority
     - due dates
   - Common approach:
     - External system owns status + assignments
     - CollabHub owns agent reasoning, artifacts, and attribution

2. **Idempotent sync**
   - Every inbound webhook event must be safe to replay.

3. **Event log first**
   - Store raw webhook payloads (JSONB) for audit/debug.

4. **Back-pressure and retries**
   - Sync should run via a job queue (Celery / RQ / Sidekiq equivalent), not inside request threads.

## Architecture

### Services

- `api` (FastAPI):
  - receives webhooks
  - serves UI
  - enqueues sync jobs

- `worker` (Celery):
  - processes sync tasks
  - calls Asana/Jira APIs
  - writes mapping + state

- `redis`:
  - broker + cache

- `postgres`:
  - durable state: mappings, tasks, runs, VERA ledger

### Data model (minimum)

- `integrations`
  - `integration_id`, `workspace_id`, `provider` ('asana'|'jira')
  - `config` (encrypted at rest if possible)

- `external_objects`
  - maps external ids → internal ids
  - `(provider, external_id, object_type) -> internal_id`

- `webhook_events`
  - append-only inbox of raw events

- `tasks`
  - internal representation (minimal set)

- VERA linkage
  - each task update creates a `vera_ledger` entry

## Sync flows

### A) Inbound: Asana/Jira → CollabHub

1. webhook hits `/integrations/{provider}/webhook`
2. write `webhook_events` row (raw JSON)
3. enqueue job `process_webhook_event(event_id)`
4. worker:
   - normalizes payload
   - upserts `tasks`
   - updates `external_objects` mapping
   - writes VERA ledger entries for:
     - status change
     - reassignment
     - description edits

### B) Outbound: CollabHub → Asana/Jira

1. UI or agent action changes internal task
2. write internal change event
3. enqueue `push_task_update(task_id)`
4. worker:
   - calls external API
   - handles rate limits and retries

## Security and reliability

- Use per-workspace secrets.
- Support secret rotation.
- Verify webhook signatures (Jira and Asana both support mechanisms).
- Store minimal scopes.

## MVP scope for board demo

- Pick **one provider** first (Jira or Asana).
- Implement:
  - mapping table
  - inbound webhook receive + logging
  - task upsert
  - visible task list in CollabHub UI
  - VERA ledger entries for each change

Expand after demo.
