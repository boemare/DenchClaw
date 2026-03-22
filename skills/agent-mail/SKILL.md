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

## Email Flow 1: Venue Discovery

Send this when first reaching out to a venue to check availability and pricing.

**Subject:** `Event inquiry — {{organization}} {{event_type}}, {{event_date}}`

**Body template:**
```
Hi,

My name is Eve and I'm reaching out on behalf of {{organization}}. We're planning a {{event_type}} for approximately {{headcount}} guests and are looking at venues in your area.

We'd love to know:
- Are you available on {{event_date}}?
- What is the pricing for a group of {{headcount}}? (room hire, minimum spend, etc.)
- Do you offer in-house catering, or can we arrange outside catering?
- What's included in the hire? (tables, chairs, AV, staff)
- What deposit is required to secure the booking?

If {{event_date}} doesn't work, we're flexible on nearby dates.

Would love to hear from you. Happy to jump on a quick call if that's easier.

Best,
Eve
{{organization}}
```

## Email Flow 2: Venue Booking Confirmation

Send this after the team approves a venue and you want to lock the reservation.

**Subject:** `Booking confirmation — {{organization}} {{event_type}}, {{event_date}}`

**Body template:**
```
Hi {{contact_name}},

Thank you for the information from our earlier conversation. We'd like to go ahead and confirm the booking.

Here are the details:
- Date: {{event_date}}
- Guests: {{headcount}}
- Setup time: {{setup_time}}
- Event: {{event_start}} — {{event_end}}
- Agreed price: {{agreed_price}}

Could you please:
1. Send a deposit invoice to this email address
2. Confirm the booking reference / confirmation number
3. Share any forms or paperwork we need to complete before the event
4. Let us know the cancellation policy and day-of contact person

If anything needs a signature, please send it over and we'll return it promptly.

Looking forward to the event!

Best,
Eve
{{organization}}
```

## Email Flow 3: Follow-up

Send if a venue hasn't replied within 48 hours of discovery or booking email.

**Subject:** `Re: [original subject]` (use reply endpoint to keep thread)

**Body template:**
```
Hi,

Just following up on my earlier email about the {{event_type}} on {{event_date}} for {{headcount}} guests. Would love to hear if your venue might be a good fit.

Happy to jump on a quick call if that's easier — just let me know a good time.

Best,
Eve
```

## General Workflow

1. **Discovery**: Send discovery email with venue contact. Save `thread_id`.
2. **Wait for reply**: Check threads periodically or via heartbeat.
3. **Read reply**: Use `extracted_text` to get just the new content.
4. **Booking**: Once team approves, reply in the same thread with booking confirmation email.
5. **Follow-up**: If no reply in 48h, send follow-up in the same thread.
6. **Log everything**: Save thread as JSONL chat session + log to `communications` DuckDB object.

## Gotchas

- Free tier: 100 emails/day hard limit. Upgrade to Developer ($20/month) for 10,000/month
- Always include both `text` AND `html` in emails for best deliverability
- `@agentmail.to` addresses may land in spam for some recipients. For production, use custom domain (Developer plan)
- No visual inbox dashboard — everything is API-only. Eve's chat session view is the visual interface

## Links
- Console: https://console.agentmail.to
- API Docs: https://docs.agentmail.to
- Pricing: https://www.agentmail.to/pricing
