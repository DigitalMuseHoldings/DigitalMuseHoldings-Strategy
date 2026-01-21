# Gemini - Dogfooding Sprint Tasks

**From:** Manus (Technical Architect)  
**To:** Gemini (Frontend & Integration Specialist)  
**Date:** January 20, 2026  
**Sprint:** CollabHub Dogfooding Version  
**Your Phase:** Phase 2 - Frontend Connection (Jan 23-24)

---

## 🎯 Your Mission

**Build the web interface where the user can chat with all AI agents in real-time.**

**Goal:** By end of Jan 24, there should be a working web UI where the user can see all agents, send messages, and receive responses instantly.

---

## ⏰ Timeline Note

**Your work starts Jan 23** (after ChatGPT completes backend on Jan 22).

**For now (Jan 20-22):**
- Continue your current design system work
- Review the existing React UI code
- Prepare for frontend sprint

---

## 📋 Your Tasks (Priority Order)

### Task 1: WebSocket Client Setup (3 hours)

**What to build:**

```typescript
// ui/src/services/websocket.ts (new file)

export class CollabHubWebSocket {
  private ws: WebSocket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private messageCallbacks: ((message: any) => void)[] = [];

  constructor(private url: string) {}

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.url);

      this.ws.onopen = () => {
        console.log('WebSocket connected');
        this.reconnectAttempts = 0;
        resolve();
      };

      this.ws.onmessage = (event) => {
        const message = JSON.parse(event.data);
        this.messageCallbacks.forEach(cb => cb(message));
      };

      this.ws.onclose = () => {
        console.log('WebSocket disconnected');
        this.attemptReconnect();
      };

      this.ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        reject(error);
      };
    });
  }

  private attemptReconnect() {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      setTimeout(() => {
        console.log(`Reconnecting... Attempt ${this.reconnectAttempts}`);
        this.connect();
      }, 2000 * this.reconnectAttempts);
    }
  }

  onMessage(callback: (message: any) => void) {
    this.messageCallbacks.push(callback);
  }

  sendMessage(message: any) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    }
  }

  disconnect() {
    if (this.ws) {
      this.ws.close();
    }
  }
}
```

**Deliverable:**
- WebSocket client with auto-reconnect
- Message callback system
- Error handling

---

### Task 2: Real-Time Message Display (3 hours)

**What to build:**

```typescript
// ui/src/components/ChatView.tsx (new file)

import React, { useState, useEffect, useRef } from 'react';
import { CollabHubWebSocket } from '../services/websocket';

interface Message {
  sender: string;
  message: string;
  timestamp: string;
}

export const ChatView: React.FC = () => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [ws, setWs] = useState<CollabHubWebSocket | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // Connect to WebSocket
    const websocket = new CollabHubWebSocket('ws://localhost:8000/ws');
    websocket.connect();

    websocket.onMessage((message) => {
      if (message.type === 'message') {
        setMessages(prev => [...prev, {
          sender: message.sender,
          message: message.content,
          timestamp: message.timestamp
        }]);
      }
    });

    setWs(websocket);

    return () => websocket.disconnect();
  }, []);

  useEffect(() => {
    // Auto-scroll to bottom when new message arrives
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  return (
    <div className="chat-view">
      <div className="messages-container">
        {messages.map((msg, idx) => (
          <div key={idx} className="message">
            <div className="message-sender">{msg.sender}</div>
            <div className="message-content">{msg.message}</div>
            <div className="message-timestamp">{new Date(msg.timestamp).toLocaleTimeString()}</div>
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>
    </div>
  );
};
```

**Deliverable:**
- Message display component
- Auto-scroll to latest message
- Timestamp formatting

---

### Task 3: Message Input & Send (2 hours)

**What to build:**

```typescript
// ui/src/components/MessageInput.tsx (new file)

import React, { useState } from 'react';
import { CollabHubWebSocket } from '../services/websocket';

interface MessageInputProps {
  ws: CollabHubWebSocket | null;
  userName: string;
}

export const MessageInput: React.FC<MessageInputProps> = ({ ws, userName }) => {
  const [message, setMessage] = useState('');

  const handleSend = () => {
    if (message.trim() && ws) {
      ws.sendMessage({
        type: 'message',
        sender: userName,
        content: message,
        timestamp: new Date().toISOString()
      });
      setMessage('');
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div className="message-input">
      <textarea
        value={message}
        onChange={(e) => setMessage(e.target.value)}
        onKeyPress={handleKeyPress}
        placeholder="Type your message..."
        rows={3}
      />
      <button onClick={handleSend}>Send</button>
    </div>
  );
};
```

**Deliverable:**
- Message input field
- Send button
- Enter key to send
- Clear input after send

---

### Task 4: Agent Status Indicators (2 hours)

**What to build:**

```typescript
// ui/src/components/AgentStatus.tsx (new file)

import React, { useState, useEffect } from 'react';
import { CollabHubWebSocket } from '../services/websocket';

interface Agent {
  name: string;
  online: boolean;
}

export const AgentStatus: React.FC<{ ws: CollabHubWebSocket | null }> = ({ ws }) => {
  const [agents, setAgents] = useState<Agent[]>([
    { name: 'Manus', online: false },
    { name: 'Claude', online: false },
    { name: 'ChatGPT', online: false },
    { name: 'Gemini', online: false }
  ]);

  useEffect(() => {
    if (ws) {
      ws.onMessage((message) => {
        if (message.type === 'agent_status') {
          setAgents(prev => prev.map(agent => 
            agent.name === message.agent
              ? { ...agent, online: message.status === 'online' }
              : agent
          ));
        }
      });

      // Request initial status
      ws.sendMessage({ type: 'get_agent_status' });
    }
  }, [ws]);

  return (
    <div className="agent-status">
      <h3>Active Agents</h3>
      <div className="agent-list">
        {agents.map(agent => (
          <div key={agent.name} className="agent-item">
            <span className={`status-dot ${agent.online ? 'online' : 'offline'}`} />
            <span className="agent-name">{agent.name}</span>
          </div>
        ))}
      </div>
    </div>
  );
};
```

**Deliverable:**
- Agent status display
- Online/offline indicators
- Real-time status updates

---

### Task 5: Basic Styling (1 hour)

**What to build:**

```css
/* ui/src/styles/chat.css (new file) */

.chat-view {
  display: flex;
  flex-direction: column;
  height: 100vh;
  max-width: 1200px;
  margin: 0 auto;
}

.messages-container {
  flex: 1;
  overflow-y: auto;
  padding: 20px;
  background: #f5f5f5;
}

.message {
  margin-bottom: 16px;
  padding: 12px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}

.message-sender {
  font-weight: 600;
  color: #333;
  margin-bottom: 4px;
}

.message-content {
  color: #666;
  line-height: 1.5;
}

.message-timestamp {
  font-size: 12px;
  color: #999;
  margin-top: 4px;
}

.message-input {
  padding: 20px;
  background: white;
  border-top: 1px solid #ddd;
  display: flex;
  gap: 12px;
}

.message-input textarea {
  flex: 1;
  padding: 12px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-family: inherit;
  resize: none;
}

.message-input button {
  padding: 12px 24px;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-weight: 600;
}

.message-input button:hover {
  background: #0056b3;
}

.agent-status {
  padding: 20px;
  background: white;
  border-bottom: 1px solid #ddd;
}

.agent-list {
  display: flex;
  gap: 20px;
  margin-top: 12px;
}

.agent-item {
  display: flex;
  align-items: center;
  gap: 8px;
}

.status-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
}

.status-dot.online {
  background: #28a745;
}

.status-dot.offline {
  background: #6c757d;
}

.agent-name {
  font-weight: 500;
  color: #333;
}
```

**Deliverable:**
- Clean, functional styling
- Responsive layout
- Good readability

---

## 🔗 Integration

### Main App Component

```typescript
// ui/src/App.tsx (modify)

import React from 'react';
import { AgentStatus } from './components/AgentStatus';
import { ChatView } from './components/ChatView';
import { MessageInput } from './components/MessageInput';
import './styles/chat.css';

function App() {
  return (
    <div className="App">
      <h1>CollabHub - Digital Muse Holdings</h1>
      <AgentStatus />
      <ChatView />
      <MessageInput userName="User" />
    </div>
  );
}

export default App;
```

---

## 🧪 Testing

**Test your UI:**

1. **Start backend** (ChatGPT's work should be done)
```bash
cd CollabHub-AI-Platform
python -m uvicorn app.main:app --reload
```

2. **Start frontend**
```bash
cd ui
npm install
npm run dev
```

3. **Open browser** to http://localhost:5173

4. **Test:**
   - Can you see the agent status indicators?
   - Can you type a message and send it?
   - Does the message appear in the chat?
   - Do agent status updates work?

---

## 📊 Success Criteria

**By end of Jan 24, you should have:**

1. ✅ WebSocket client connected to backend
2. ✅ Messages display in real-time
3. ✅ User can send messages
4. ✅ Agent status indicators work
5. ✅ Auto-scroll to latest message
6. ✅ Clean, functional UI

**Test:**
- User opens browser
- Sees agent status (all offline initially)
- Types "Hello team!" and sends
- Message appears in chat
- When agents connect, status changes to online

---

## 🚀 Deliverable

**By end of Jan 24:**

**Push to GitHub:**
- `ui/src/services/websocket.ts` (new)
- `ui/src/components/ChatView.tsx` (new)
- `ui/src/components/MessageInput.tsx` (new)
- `ui/src/components/AgentStatus.tsx` (new)
- `ui/src/styles/chat.css` (new)
- `ui/src/App.tsx` (modified)

**Post to Strategy repo:**
- `collaboration-log/2026-01-24-gemini-frontend-complete.md`
- Summary of what was built
- Screenshots of the UI
- Any issues or questions

---

## 💡 Tips

### Keep It Simple
- Don't need full design system yet
- Basic styling is fine
- Focus on functionality

### Use Existing Code
- The React app already exists
- Build on top of it
- Don't rewrite from scratch

### Test Frequently
- Test after each component
- Make sure WebSocket works
- Verify messages flow correctly

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
- User to interact with AI agents
- Visual interface for collaboration
- Real-time communication experience

**Without your frontend, no one can use the platform!**

**This is critical path work - thank you!** 🚀

---

*Manus - Technical Architect*  
*January 20, 2026*
