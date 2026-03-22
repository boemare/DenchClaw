# Eve — Community Event Agent for DOAC

> One message in, two real things happen. That's the bar. Eve clears it.

---

## What Eve Does

A team member types: *"Set up a dinner for 30 in NYC next Friday, budget $2000."*

Eve takes it from there — researches venues online, calls the top three to check availability and pricing, emails them for quotes, books the winner, creates an Eventbrite page, and tracks RSVPs. The team member sees every step in real-time: branded subagent cards (📞 Retell AI: Call The Venue NYC), inline status updates, and full call transcripts browsable in the same chat UI.

Two real things happen from one message. Usually five or six.

---

## Architecture

![Eve System Architecture](architecture.png)

Eve is built on [DenchClaw](https://github.com/DenchHQ/DenchClaw) (an OpenClaw framework), rebranded and specialized for event operations. The architecture has five layers:

1. **Chat UI** — Team member sends a message. Eve responds with a plan, spawns subagents, and reports results inline with branded labels.
2. **Eve (Orchestrator)** — Decomposes the request, delegates to specialist skills, synthesizes results. Never does everything herself — delegates to purpose-built subagents.
3. **External APIs** — Retell AI (voice), AgentMail (email), Eventbrite (events). Each has its own skill file defining exactly how to call it.
4. **DuckDB** — Local database tracking events, venues, and communications. Single source of truth.
5. **Privacy Layer** — Sits between Eve and all fan data. Filters PII before it touches the workspace.

---

## Tool Choices and Why

| Tool | What it does | Why this one |
|------|-------------|-------------|
| **Retell AI** | AI voice calls to venues | Built-in transcripts, recordings, and call analytics. Two agent flows: discovery (check availability/pricing) and booking (lock reservation). Conversation-flow architecture means the call follows a structured path without hallucinating. $10 free credits, no monthly commitment. |
| **AgentMail** | Email venues | Eve gets her own email address (eve@agentmail.to). No IMAP config, no app passwords — just an API key. Threading is automatic. The non-technical audience for this tool would never configure SMTP. |
| **Eventbrite** | Event pages, RSVPs, fan notifications | Free for free events. Handles all fan-facing communication — invitations, waitlist, reminders, check-ins. Eve never contacts fans directly; Eventbrite does. This is the privacy boundary. |
| **DenchClaw/OpenClaw** | Agent framework + workspace UI | Existing chat UI, subagent system, DuckDB integration, and skill architecture. We didn't build a UI from scratch — we specialized an existing one. Skills are just markdown files that get injected into the agent's system prompt. |

**What we didn't use and why:**
- *Twilio + ElevenLabs* — Two services to configure instead of one. Retell AI combines voice, transcription, and call intelligence in a single API.
- *Luma* — Requires Luma Plus ($60+/month) for API access. Eventbrite's API is free.
- *IMAP/SMTP email* — Requires App Passwords, server config, and port numbers. AgentMail is paste-an-API-key simple.

---

## Privacy Layer

The privacy architecture is simple: **Eve contacts venues. Eventbrite contacts fans. They never cross.**

### What Eve can access
- Venue business contact details (phone, email, address) — stored freely in DuckDB
- Eventbrite RSVP counts (aggregate numbers only)
- First names from guest lists (for VIP tracking, with team approval)

### What Eve cannot access
- Fan email addresses, phone numbers, street addresses
- Payment information, government IDs, dates of birth
- Any personally identifiable information about attendees

### How it's enforced
1. **Privacy skill** — A dedicated `privacy-layer/SKILL.md` is injected into Eve's system prompt. It classifies PII types, defines allowed fields, and instructs Eve to refuse requests for fan data.
2. **Eventbrite as the boundary** — Eve creates the event page. Eventbrite sends all notifications. Eve never extracts contact info to send directly.
3. **Audit trail** — Every API call that touches user data is logged to `docs/privacy-audit-log.md` with timestamp, fields requested, and fields filtered.
4. **Escalation protocol** — If a team member explicitly asks for fan PII, Eve explains the privacy policy and suggests alternatives ("I can manage that through Eventbrite's event page instead").

This isn't a technical access control — it's a behavioral guardrail baked into the agent's identity. The agent is instructed to treat fan data as off-limits, and the architecture makes it unnecessary to access it in the first place.

---

## Demo Flow

Here's what happens when you type *"Set up a dinner for 30 in NYC next Friday"*:

1. Eve creates a DuckDB entry: Event Name = "DOAC NYC Dinner", Status = "Planning"
2. **🔍 Browser: Research venues in NYC** — subagent spawns, searches for venues matching capacity and budget
3. Eve presents top 3 options with pricing
4. **📞 Retell AI: Call The Venue NYC** — discovery agent calls, checks availability for Friday, 30 guests, asks about pricing, catering, deposit
5. **📧 AgentMail: Email venue quote request** — sends discovery email to venues that didn't answer
6. Eve reports: *"📞 Call completed — The Venue NYC. Duration: 3m 12s. Available Friday 7-11pm. Quote: $1,800."*
7. Team approves → **📞 Retell AI: Book The Venue NYC** — booking agent confirms reservation, requests invoice to eve@agentmail.to
8. **🎟️ Eventbrite: Create DOAC NYC Dinner** — event page goes live with venue, date, capacity
9. Eve updates DuckDB: Status = "Confirmed", Eventbrite URL saved
10. Call transcript and email thread appear in sidebar as browsable chat sessions

Two real things from one message: venue booked + Eventbrite page live. Everything else is bonus.

---

## What We'd Build Next (30 Days)

### Week 1 — Security Hardening
- **Sandbox everything** — Set OpenClaw sandbox to `all` mode, restrict workspace to read-only, whitelist only approved exec commands. Patch all 6 known CVEs (shell execution bypass, path traversal, auth bypass).
- **Encrypt at rest** — DuckDB AES-GCM-256 encryption for all workspace data. Move API keys from plaintext `.env` to OS keychain or HashiCorp Vault.
- **Prompt injection defense** — Sanitize all inbound data (venue reply emails, Eventbrite webhooks, web pages). Add domain whitelist validation before any outbound API call. Strip shell metacharacters from user input.
- **Audit logging** — Structured JSON logs for every agent action with timestamp, operator ID, session ID, action, parameters, and result. 90-day retention. Privacy audit trail for any API call touching attendee data.

### Week 2 — Custom Voice + Professional Email
- **Fish Audio custom voice** — Train Eve's voice on 30-60 seconds of audio from an actual DOAC community manager. Replace Retell's generic TTS with a voice that sounds like the team. Integration via Fish Audio as TTS fallback provider in Retell, or full custom telephony stack (Twilio SIP + Fish Audio TTS + Deepgram STT + Claude).
- **Custom domain email (Postmark)** — Switch from `eveevent@agentmail.to` to `eve@doac.com`. Postmark handles transactional email only (99%+ inbox delivery, never shares IP with marketing spam). DNS setup: SPF, DKIM, DMARC records on doac.com. Inbound email via MX record + webhook — venue replies parsed automatically with `StrippedTextReply`.

### Week 3 — Production Features
- **Egress proxy** — Deploy Envoy/nginx between Eve and the internet. Whitelist only approved API domains. Block all non-HTTPS traffic. Rate limit 100 requests/hour per domain. Log all blocked outbound attempts.
- **Venue intelligence** — DuckDB knowledge base of past venues with ratings, pricing history, and experience notes. Eve references past bookings when recommending venues. City profiles for top 10 DOAC cities.
- **Proactive operations** — Heartbeat checks every 30 minutes: inbox for venue replies, Eventbrite RSVP counts, stale communications needing follow-up. Cron jobs: 48h pre-event confirmation call, day-of logistics checklist, post-event attendance pull and venue thank-you email.
- **Budget tracking** — New `budgets` DuckDB object tracking spend per event and per quarter. Alerts when approaching budget limits.

### Week 4 — Scale + Compliance
- **WhatsApp access** — Team messages Eve from their phone. "How many RSVPs for the NYC dinner?" gets an instant answer from DuckDB.
- **SOC 2 readiness** — Document all security controls. Create access control, data handling, and incident response policies. Data retention: auto-delete transcripts after 90 days, attendee data after event + 30 days. GDPR/CCPA compliance documentation.
- **Red teaming** — Test prompt injection via malicious venue emails, webhook payloads, and web pages. Test data exfiltration, privilege escalation, and PII leakage. Document findings, fix critical issues.
- **Reliability** — Load test 10 concurrent event requests. Graceful degradation (voice fails → fall back to email). Retry logic with exponential backoff. Monitoring dashboard: uptime, API response times, error rates, cost tracking.

---

## Technical Details

- **Package**: `npx eveevent@latest` ([npm](https://www.npmjs.com/package/eveevent))
- **Source**: [github.com/boemare/DenchClaw](https://github.com/boemare/DenchClaw)
- **Built on**: DenchClaw / OpenClaw
- **Model**: Anthropic Claude (configurable)
- **Skills**: 8 custom skills (event-orchestration, retell-ai, agent-mail, eventbrite, privacy-layer, browser, crm, app-builder)
- **Retell Agents**: 2 conversation-flow templates (venue-discovery, venue-booking)

---

*Built by Pablo Berlanga. Designed for the DOAC community.*
