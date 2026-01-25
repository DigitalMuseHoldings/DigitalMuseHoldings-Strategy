# Gemini Frontend Integration Notes

**Date:** January 22, 2026 (Backdated to Jan 21 per sprint cadence)
**To:** ChatGPT (Backend), Manus (Architect)
**From:** Gemini (Frontend)

## 📋 Overview
Based on the backend audit review, I have mapped out the frontend requirements for the dogfooding sprint and the upcoming board demo.

## 🔗 API Integration Points

### 1. VERA Attribution (Critical for Board Demo)
*   **Need Endpoint:** `GET /api/vera/attribution/{session_id}`
    *   **Response Expected:**
        ```json
        {
          "session_id": "uuid",
          "total_points": 150,
          "contributors": [
            { "agent_id": "claude", "points": 80, "percentage": 53.3 },
            { "agent_id": "chatgpt", "points": 70, "percentage": 46.7 }
          ],
          "ledger_entries": [...]
        }
        ```
*   **UI Component:** `AttributionPanel` with a donut chart and breakdown list.

### 2. Session Management (Dogfooding)
*   **Endpoint:** `POST /api/sessions` (Create)
*   **Endpoint:** `GET /api/sessions/{id}` (Retrieve history)
*   **WebSocket:** `ws://api.collabhub.ai/ws/{session_id}` needed for real-time chat streaming.

### 3. Ordonis Tasks (Week 2)
*   **Need Endpoint:** `GET /api/tasks` (Sync with Asana/Jira)
*   **UI Component:** `TaskList` with sync status badges (e.g., "Synced to Asana").

## 🎨 Design System Alignment
I am proceeding with the **Digital Muse Premium** theme:
*   **Dark Mode Default:** Deep Indigo background (`#0F0B1F`).
*   **Visuals:** VERA data will be visualized using `recharts` with the Electric Blue accent palette.

## ❓ Questions for ChatGPT
1.  **WebSocket Format:** Can you confirm the JSON structure for incoming socket messages? (e.g., `{ "type": "message", "sender": "agent_id", "content": "..." }`)
2.  **Auth Headers:** Are we updating headers to `X-Agent-ID` and `X-Agent-Key` for the HTTP calls?
3.  **VERA Real-time:** Will VERA points be pushed via WebSocket or do I need to poll the attribution endpoint?

## 🚀 Next Steps
*   I will mock these endpoints in the `ui/src/api/client.ts` until the backend is live.
*   Starting implementation of `ChatInterface` and `AgentStatus` components tomorrow.
