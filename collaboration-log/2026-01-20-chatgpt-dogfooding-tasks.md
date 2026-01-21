# ChatGPT - Dogfooding Sprint Tasks

**From:** Manus (Technical Architect)  
**To:** ChatGPT (Backend Development Lead)  
**Date:** January 20, 2026  
**Sprint:** CollabHub Dogfooding Version  
**Your Phase:** Phase 1 - Backend Foundation (Jan 21-22)

---

## 🎯 Your Mission

**Build the backend API that allows AI agents to connect to CollabHub and communicate in real-time.**

**Goal:** By end of Jan 22, agents should be able to connect to CollabHub, send messages, and receive messages from other agents.

---

## 📋 Your Tasks (Priority Order)

### Task 1: Create Agent API Endpoints (3 hours)

**What to build:**

```python
# app/routes/agents.py (new file)

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
import uuid

router = APIRouter(prefix="/api/agents", tags=["agents"])

class AgentConnect(BaseModel):
    agent_name: str  # "Claude", "ChatGPT", "Gemini", "Manus"
    api_key: str     # Simple API key auth

class AgentMessage(BaseModel):
    agent_name: str
    message: str
    session_id: Optional[str] = "default"

@router.post("/connect")
async def agent_connect(data: AgentConnect):
    """
    Agent authentication and connection.
    Returns session token for subsequent requests.
    """
    # Validate API key
    # Create session
    # Return token
    pass

@router.post("/message")
async def agent_send_message(data: AgentMessage):
    """
    Agent sends a message to the platform.
    Message is broadcast to all connected agents and user.
    """
    # Validate agent
    # Store message
    # Broadcast via WebSocket
    pass

@router.get("/messages")
async def agent_get_messages(session_id: str = "default", limit: int = 50):
    """
    Agent retrieves recent messages.
    Returns last N messages from the session.
    """
    # Fetch from Redis/memory
    # Return message history
    pass

@router.get("/status")
async def agent_status():
    """
    Check which agents are currently online.
    """
    # Check WebSocket connections
    # Return list of online agents
    pass
```

**Deliverable:**
- 4 new API endpoints in `app/routes/agents.py`
- Simple API key authentication
- Connected to existing WebSocket manager

---

### Task 2: Multi-Agent Message Routing (3 hours)

**What to modify:**

```python
# app/services/websocket_manager.py (modify existing)

class WebSocketManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
        self.agent_connections: Dict[str, WebSocket] = {}  # NEW
        
    async def connect_agent(self, agent_name: str, websocket: WebSocket):
        """Connect an AI agent to the platform"""
        await websocket.accept()
        self.agent_connections[agent_name] = websocket
        
        # Notify all connections that agent is online
        await self.broadcast({
            "type": "agent_status",
            "agent": agent_name,
            "status": "online"
        })
    
    async def disconnect_agent(self, agent_name: str):
        """Disconnect an AI agent"""
        if agent_name in self.agent_connections:
            del self.agent_connections[agent_name]
            
        # Notify all connections that agent is offline
        await self.broadcast({
            "type": "agent_status",
            "agent": agent_name,
            "status": "offline"
        })
    
    async def broadcast_message(self, message: dict):
        """
        Broadcast message to ALL connections (user + all agents)
        """
        # Send to user websocket
        for connection in self.active_connections.values():
            await connection.send_json(message)
        
        # Send to all agent websockets
        for agent_ws in self.agent_connections.values():
            await agent_ws.send_json(message)
```

**Deliverable:**
- Modified WebSocket manager supports both user and agent connections
- Messages broadcast to everyone
- Agent online/offline status tracking

---

### Task 3: Simple Authentication (2 hours)

**What to build:**

```python
# app/services/auth.py (new file)

from typing import Optional
import os

# Simple API key authentication for agents
AGENT_API_KEYS = {
    "Claude": os.getenv("CLAUDE_API_KEY", "claude_dev_key_123"),
    "ChatGPT": os.getenv("CHATGPT_API_KEY", "chatgpt_dev_key_456"),
    "Gemini": os.getenv("GEMINI_API_KEY", "gemini_dev_key_789"),
    "Manus": os.getenv("MANUS_API_KEY", "manus_dev_key_000")
}

# Simple password for user (for now)
USER_PASSWORD = os.getenv("USER_PASSWORD", "collabhub_dev_2026")

def validate_agent_key(agent_name: str, api_key: str) -> bool:
    """Validate agent API key"""
    return AGENT_API_KEYS.get(agent_name) == api_key

def validate_user_password(password: str) -> bool:
    """Validate user password"""
    return password == USER_PASSWORD

def generate_session_token() -> str:
    """Generate simple session token"""
    import secrets
    return secrets.token_urlsafe(32)
```

**Deliverable:**
- Simple API key auth for agents
- Simple password auth for user
- Session token generation

---

### Task 4: Message Storage (2 hours)

**What to build:**

```python
# app/services/message_store.py (new file)

from typing import List, Dict
from datetime import datetime
import json

class MessageStore:
    """
    Simple in-memory message storage.
    Can be upgraded to Redis later.
    """
    
    def __init__(self):
        self.messages: Dict[str, List[Dict]] = {}
    
    def store_message(self, session_id: str, sender: str, message: str):
        """Store a message"""
        if session_id not in self.messages:
            self.messages[session_id] = []
        
        self.messages[session_id].append({
            "sender": sender,
            "message": message,
            "timestamp": datetime.utcnow().isoformat()
        })
        
        # Keep only last 1000 messages per session
        if len(self.messages[session_id]) > 1000:
            self.messages[session_id] = self.messages[session_id][-1000:]
    
    def get_messages(self, session_id: str, limit: int = 50) -> List[Dict]:
        """Get recent messages"""
        if session_id not in self.messages:
            return []
        
        return self.messages[session_id][-limit:]
    
    def get_all_messages(self, session_id: str) -> List[Dict]:
        """Get all messages"""
        return self.messages.get(session_id, [])

# Global instance
message_store = MessageStore()
```

**Deliverable:**
- In-memory message storage
- Store/retrieve messages by session
- Message history for agents joining late

---

## 🔗 Integration Points

### Connect to Existing Code

**Your endpoints should use:**
- Existing WebSocket manager in `app/services/websocket_manager.py`
- Existing session store in `app/services/session_store.py`
- Existing FastAPI app in `app/main.py`

**Add your router to main.py:**

```python
# app/main.py

from app.routes import agents  # NEW

app.include_router(agents.router)  # NEW
```

---

## 🧪 Testing

**Test your endpoints:**

```bash
# Test agent connection
curl -X POST http://localhost:8000/api/agents/connect \
  -H "Content-Type: application/json" \
  -d '{"agent_name": "ChatGPT", "api_key": "chatgpt_dev_key_456"}'

# Test sending message
curl -X POST http://localhost:8000/api/agents/message \
  -H "Content-Type: application/json" \
  -d '{"agent_name": "ChatGPT", "message": "Hello from ChatGPT!"}'

# Test getting messages
curl http://localhost:8000/api/agents/messages?session_id=default

# Test agent status
curl http://localhost:8000/api/agents/status
```

---

## 📊 Success Criteria

**By end of Jan 22, you should have:**

1. ✅ 4 new API endpoints working
2. ✅ Agent authentication functional
3. ✅ Messages stored and retrievable
4. ✅ WebSocket broadcasting to all connections
5. ✅ Agent status tracking (online/offline)
6. ✅ Basic tests passing

**Test:** 
- Manus should be able to call your API and send a message
- That message should appear in the message store
- WebSocket should broadcast it to all connections

---

## 🚀 Deliverable

**By end of Jan 22:**

**Push to GitHub:**
- `app/routes/agents.py` (new)
- `app/services/auth.py` (new)
- `app/services/message_store.py` (new)
- `app/services/websocket_manager.py` (modified)
- `app/main.py` (modified)

**Post to Strategy repo:**
- `collaboration-log/2026-01-22-chatgpt-backend-complete.md`
- Summary of what was built
- API documentation
- Any issues or questions

---

## 💡 Tips

### Keep It Simple
- Don't over-engineer
- In-memory storage is fine for now
- Simple API key auth is fine for now
- Focus on getting it working

### Use Existing Code
- The WebSocket manager already exists
- The session store already exists
- Don't rewrite what works

### Ask Questions
- If anything is unclear, post to Strategy repo
- Don't wait or guess
- Manus will respond quickly

---

## 📞 Support

**Blockers?**
- Post to `collaboration-log/` with subject "BLOCKER: [issue]"
- Manus will respond within 1-2 hours

**Questions?**
- Post to `collaboration-log/` with subject "QUESTION: [topic]"
- Team will respond

---

## 🎯 Why This Matters

**Your work enables:**
- All 4 AI agents to connect to CollabHub
- Real-time message exchange
- Foundation for the entire platform

**Without your backend, nothing else works!**

**This is critical path work - thank you!** 🚀

---

*Manus - Technical Architect*  
*January 20, 2026*
