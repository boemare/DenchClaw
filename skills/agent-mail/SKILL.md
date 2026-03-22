---
name: agentmail
description: Eve's email inbox via AgentMail. Send and receive emails, manage threads, track venue conversations. Own @agentmail.to address with no IMAP/SMTP config needed.
metadata: { "openclaw": { "inject": true, "always": true, "emoji": "📧" } }
---

# AgentMail — Eve's Email

Eve has his own email inbox at AgentMail. Send emails, receive replies, and track conversation threads — all via simple REST API. No IMAP config needed.

## Prerequisites (must be done once)

1. Sign up at https://console.agentmail.to (free, no credit card)
2. Create an API key in the console
3. Create an inbox — the API will give Eve an email address like `eve@agentmail.to`

## Environment Variables

```bash
export AGENTMAIL_API_KEY="am_your_api_key"
export AGENTMAIL_INBOX_ID="inbox_abc123"
export AGENTMAIL_EMAIL="eve@agentmail.to"
```

Free tier: 100 emails/day, 3 inboxes, 3,000 emails/month.

## API Base

All requests: `https://api.agentmail.to/v0` with `Authorization: Bearer $AGENTMAIL_API_KEY`

## Create Inbox (one-time setup)

```bash
curl -X POST "https://api.agentmail.to/v0/inboxes" \
  -H "Authorization: Bearer $AGENTMAIL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "eve",
    "display_name": "Eve"
  }'
```

Returns `inbox_id` and `email_address`. Save the `inbox_id` as `AGENTMAIL_INBOX_ID`.

The `display_name` shows as the sender name: "Eve <eve@agentmail.to>"

## Send Email

```bash
curl -X POST "https://api.agentmail.to/v0/inboxes/$AGENTMAIL_INBOX_ID/messages/send" \
  -H "Authorization: Bearer $AGENTMAIL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "venue@example.com",
    "subject": "Booking inquiry — DOAC NYC Dinner, March 28",
    "text": "Hi, I am reaching out on behalf of DOAC...",
    "html": "<p>Hi, I am reaching out on behalf of DOAC...</p>"
  }'
```

**Always include both `text` and `html`** — improves deliverability.

Returns `message_id` and `thread_id` for tracking the conversation.

## Reply to an Email

```bash
curl -X POST "https://api.agentmail.to/v0/inboxes/$AGENTMAIL_INBOX_ID/messages/{message_id}/reply" \
  -H "Authorization: Bearer $AGENTMAIL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Thank you for confirming. We would like to proceed with the booking.",
    "html": "<p>Thank you for confirming. We would like to proceed with the booking.</p>"
  }'
```

AgentMail automatically maintains threading — the reply stays in the same conversation.

## List Threads (Check for Replies)

```bash
curl "https://api.agentmail.to/v0/inboxes/$AGENTMAIL_INBOX_ID/threads" \
  -H "Authorization: Bearer $AGENTMAIL_API_KEY"
```

## Get Full Thread (All Messages in a Conversation)

```bash
curl "https://api.agentmail.to/v0/inboxes/$AGENTMAIL_INBOX_ID/threads/{thread_id}" \
  -H "Authorization: Bearer $AGENTMAIL_API_KEY"
```

Returns all messages in the thread. Each message has:
- `from_address`, `to` — sender and recipients
- `subject` — email subject
- `text`, `html` — email body
- `extracted_text` — just the new reply content (quoted history auto-removed)
- `timestamp` — when sent/received
- `attachments` — list of attachment objects

## Workflow for Venue Emails

1. **Send initial email**: Use `messages/send` with venue contact email, subject, and body
2. **Track thread**: Save the `thread_id` returned
3. **Check for replies**: Periodically `GET /threads` or use webhooks
4. **Read reply**: `GET /threads/{thread_id}` — use `extracted_text` for just the new reply
5. **Reply back**: `POST /messages/{message_id}/reply` to continue the conversation
6. **Save to workspace**: Store the thread as a JSONL chat session (see event-orchestration skill)
7. **Log to DuckDB**: Create/update entry in `communications` object

## Gotchas

- Free tier: 100 emails/day hard limit. Upgrade to Developer ($20/month) for 10,000/month
- Always include both `text` AND `html` in emails for best deliverability
- `@agentmail.to` addresses may land in spam for some recipients. For production, use custom domain (Developer plan)
- No visual inbox dashboard — everything is API-only. Eve's chat session view is the visual interface

## Links
- Console: https://console.agentmail.to
- API Docs: https://docs.agentmail.to
- Pricing: https://www.agentmail.to/pricing
