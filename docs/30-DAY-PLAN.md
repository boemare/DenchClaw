# 30-Day Production Readiness Plan for Eve

## Context

Eve works end-to-end but has three critical gaps before production: (1) security is minimal — no encryption, no sandboxing, no prompt injection defense, (2) the agent uses AgentMail's @agentmail.to domain which looks like a bot, not a real company, and (3) Retell AI's built-in voices sound generic — the team wants a custom voice trained on actual community managers using Fish Audio. This plan addresses all three plus ambitious feature work.

---

## Week 1: Security Hardening (Days 1-7)

### Day 1-2: Patch & Sandbox
- Update OpenClaw to >= v2026.2.26 (patches 6 critical CVEs including shell execution bypass, path traversal, auth bypass)
- Set `sandbox: "all"` — every agent session runs sandboxed
- Set `workspaceAccess: "ro"` — agent can read workspace but not write arbitrary files
- Set exec approvals to `allowlist` mode — only whitelisted commands (curl to approved APIs, DuckDB queries)
- Disable browser skill in production (high attack surface — web scraping can trigger prompt injection)

### Day 3-4: Encryption at Rest
- Enable DuckDB AES-GCM-256 encryption for `workspace.duckdb` (events, venues, communications tables)
- Encrypt session transcripts (call recordings, email threads stored as JSONL)
- Move `.env` API keys to OS keychain or HashiCorp Vault — stop storing plaintext secrets on disk
- Set `chmod 700` on `~/.openclaw-dench/` and `chmod 600` on all config files

### Day 5-6: Prompt Injection Defense
- Implement input sanitization on all inbound data: email bodies (venue replies), webhook payloads (Eventbrite RSVPs), web page content (browser research)
- Add content boundary markers in the system prompt separating instructions from external data
- Disable automatic link preview in all messaging integrations
- Add a validation layer: before Eve executes any API call, validate the target domain against a whitelist (Eventbrite, Retell, AgentMail/Postmark only)
- Strip shell metacharacters from any user-provided strings before they reach exec

### Day 7: Audit Logging
- Implement structured JSON audit logging for every agent action: tool invocations, API calls, file reads, DuckDB queries
- Each log entry: timestamp, operator ID, session ID, action, parameters, result, duration
- Set up log rotation (90-day retention)
- Privacy audit trail: log every API call that touches attendee data with fields requested vs. fields retained

**Files to modify:**
- `extensions/dench-identity/index.ts` — add input sanitization hooks
- `src/cli/bootstrap-external.ts` — enforce sandbox + encryption in onboarding
- `skills/event-orchestration/SKILL.md` — add domain whitelist instructions
- New: `extensions/security-hardening/index.ts` — audit logging plugin
- New: `scripts/setup-encryption.sh` — DuckDB encryption setup

---

## Week 2: Custom Voice + Custom Email (Days 8-14)

### Day 8-10: Fish Audio Custom Voice
- Record 30-60 seconds of clean audio from a DOAC community manager (natural conversation tone, not scripted)
- Train custom voice model via Fish Audio API (`POST /model` with audio upload) — processing takes ~5 minutes
- Get `voice_id` back — this is Eve's permanent voice identity
- Integration approach: **Replace Retell entirely with custom telephony stack**
  - Use **Twilio SIP trunk** for phone connectivity (buy number, configure SIP)
  - Use **Fish Audio TTS** for voice synthesis (custom trained voice)
  - Use **Deepgram** or **Whisper** for speech-to-text
  - Use **Claude API** directly for conversation logic (same prompts from venue-discovery and venue-booking flows)
  - Orchestrate via a lightweight WebSocket server (Node.js) that bridges: Twilio call → STT → Claude → Fish Audio TTS → back to caller
- Alternative simpler approach: Keep Retell but add Fish Audio as TTS fallback provider (Retell supports custom TTS fallback natively at `docs.retellai.com/build/tts-fallback`)
- Update `skills/retell-ai/SKILL.md` with Fish Audio voice config
- Update onboarding to prompt for `FISH_AUDIO_API_KEY` and `FISH_AUDIO_VOICE_ID`

### Day 11-13: Custom Domain Email (Postmark)
- Switch from AgentMail to **Postmark** for professional email:
  - `eve@doac.com` instead of `eveevent@agentmail.to`
  - 99%+ inbox delivery rate (Postmark only handles transactional email, never shares IP with marketing)
  - Built-in inbound email parsing with `StrippedTextReply` (just the new reply, no quoted history)
- DNS setup on doac.com:
  - SPF record: `v=spf1 include:spf.mtasv.net ~all`
  - DKIM: 2x CNAME records (provided by Postmark)
  - DMARC: `v=DMARC1; p=reject; rua=mailto:dmarc@doac.com`
  - MX record: point to Postmark for inbound email
- Rewrite `skills/agent-mail/SKILL.md` → `skills/email/SKILL.md` using Postmark API:
  - Send: `POST https://api.postmarkapp.com/email` with Server API Token
  - Inbound: Postmark webhooks POST parsed email JSON to Eve's backend
  - Threading: Postmark maintains `MessageID` and `In-Reply-To` headers automatically
- Update onboarding: replace AgentMail prompts with Postmark API Token + domain verification
- Update `TOOLS.md`, `BOOTSTRAP.md`, `event-orchestration/SKILL.md` with new email config

### Day 14: Integration Testing
- Run full integration test suite with new voice + email stack
- Test: discovery call with custom voice → discovery email from eve@doac.com → booking call → booking confirmation email
- Verify transcripts and email threads still render in chat UI
- Update `scripts/test-integrations.sh` with Postmark + Fish Audio tests

**Files to modify:**
- `skills/agent-mail/SKILL.md` → rewrite as `skills/email/SKILL.md` (Postmark)
- `skills/retell-ai/SKILL.md` — add Fish Audio voice config
- `src/cli/bootstrap-external.ts` — new onboarding prompts
- `scripts/test-integrations.sh` — new API tests
- New: `skills/retell-ai/templates/` — update with custom voice ID

---

## Week 3: Production Features (Days 15-21)

### Day 15-16: Egress Proxy + Network Security
- Deploy an egress proxy (Envoy or nginx) between Eve and the internet
- Whitelist only approved domains: `api.postmarkapp.com`, `api.retellai.com` (or Fish Audio + Twilio), `www.eventbriteapi.com`, `api.anthropic.com`
- Block all outbound HTTP (force HTTPS only)
- Rate limit: max 100 requests/hour per external domain
- Alert on any DNS queries to non-whitelisted domains
- Log all blocked outbound attempts

### Day 17-18: Venue Intelligence
- Build a `venues` knowledge base in DuckDB: past venues, ratings, pricing history, contact details
- After each event: auto-rate venue (attendance, cost efficiency, ease of booking)
- Eve references past experience when recommending venues: "We used The Venue NYC before, 28/30 attended, $1,800, smooth booking"
- City profiles: pre-research top 10 DOAC cities with venue shortlists

### Day 19-20: Proactive Operations (Heartbeat)
- Wire up HEARTBEAT.md checks to actually run:
  - Check Postmark inbox every 30 min for venue replies
  - Check Eventbrite RSVP counts for active events
  - Flag communications with Outcome = "Pending" older than 48h
  - Auto-send follow-up emails for stale venue inquiries
- Cron jobs:
  - 48h before event: confirmation call to venue
  - Day-of: logistics checklist generated and sent to team
  - Post-event: pull attendance from Eventbrite, update DuckDB, send venue thank-you email

### Day 21: Budget Tracking
- New DuckDB object: `budgets` — tracks spend per event, per quarter
- Eve logs every cost: venue deposit, venue total, Retell call credits, Postmark email costs
- Alert when approaching quarterly budget limits
- Monthly cost report: breakdown by city, event type, venue

**Files to modify:**
- `src/cli/workspace-seed.ts` — add `budgets` seed object
- `skills/event-orchestration/SKILL.md` — add venue intelligence + proactive ops sections
- `~/.openclaw-dench/workspace/HEARTBEAT.md` — wire up real checks
- New: `scripts/setup-egress-proxy.sh`

---

## Week 4: Scale + Compliance (Days 22-30)

### Day 22-23: Multi-Channel Access
- WhatsApp integration via OpenClaw channels — team members message Eve from their phone
- "How many RSVPs for the NYC dinner?" → instant answer from DuckDB
- Voice commands via WhatsApp voice notes (STT → Eve → response)

### Day 24-25: SOC 2 Readiness
- Document all security controls implemented in Weeks 1-3
- Create security policy docs: access controls, data handling, incident response
- Prepare audit evidence: logs, encryption config, sandbox config, exec approvals
- Write data retention policy: auto-delete session transcripts after 90 days, attendee data after event + 30 days
- GDPR/CCPA compliance: document what PII Eve processes, where it's stored, retention periods, deletion procedures

### Day 26-27: Red Teaming
- Test prompt injection attacks: craft malicious venue reply emails, webhook payloads, web pages
- Test data exfiltration: can Eve be tricked into sending data to unauthorized domains?
- Test privilege escalation: can Eve bypass sandbox or exec approvals?
- Test PII leakage: ask Eve for fan email addresses, phone numbers — verify refusal
- Document all findings, fix critical issues immediately

### Day 28-29: Performance + Reliability
- Load test: 10 concurrent event planning requests
- Failover testing: what happens when Retell/Postmark/Eventbrite API is down?
- Graceful degradation: if voice calls fail, fall back to email only
- Error handling: retry logic with exponential backoff for transient API failures
- Monitoring dashboard: uptime, API response times, error rates, cost tracking

### Day 30: Documentation + Launch
- Final security review
- Update EVE-WRITEUP.md with all improvements
- Update architecture diagram with new components (egress proxy, Fish Audio, Postmark)
- Create onboarding video (Loom) showing full setup flow
- Publish final npm package version
- Go live

---

## Verification

After each week:
1. Run `bash scripts/test-integrations.sh` — all tests pass
2. Security scan: check sandbox config, encryption status, exec approvals
3. Red team one prompt injection scenario
4. End-to-end test: "Set up a dinner for 20 in NYC" → full flow completes
5. Verify transcripts and email threads render in chat UI
