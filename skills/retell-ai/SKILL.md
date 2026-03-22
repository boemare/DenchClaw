---
name: retell-ai
description: Make and manage AI-powered phone calls via Retell AI — voice calls with built-in transcripts, recordings, and call analytics. Use for venue outreach and booking.
metadata: { "openclaw": { "inject": true, "always": true, "emoji": "📞" } }
---

# Retell AI — Voice Calls

Make AI-powered phone calls with automatic transcription, recording, and analytics. Used for calling venues to check availability, get quotes, and confirm bookings.

## Prerequisites (must be done once in the Retell dashboard)

Before Eve can make calls, a human must:
1. Sign up at https://www.retellai.com and get an API key
2. Import **two agent templates** from the `skills/retell-ai/templates/` folder:
   - `venue-discovery.json` — "Eve - Venue Discovery" agent for checking availability, pricing, and venue details
   - `venue-booking.json` — "Eve - Venue Booking" agent for confirming and locking reservations
3. Buy a **phone number** ($2/month for testing) in the dashboard under Telephony → Phone Numbers
4. Bind both agents to the number for outbound calls

After setup, Eve needs: `RETELL_API_KEY`, `RETELL_DISCOVERY_AGENT_ID`, `RETELL_BOOKING_AGENT_ID`, `RETELL_FROM_NUMBER`

## Two Call Flows

### Discovery Call (Agent: Eve - Venue Discovery)
Used for initial outreach. Gathers: availability, capacity, pricing, what's included, catering options, deposit, setup times, accessibility, parking, cancellation policy. Keeps call under 5 minutes.

### Booking Call (Agent: Eve - Venue Booking)
Used after team approves a venue. Confirms: date, price, deposit/invoice, timing, booking reference, next steps, day-of contact. Does NOT agree to price changes or date changes without team approval. Keeps call under 4 minutes.

## Environment Variables

```bash
export RETELL_API_KEY="your_retell_api_key"
export RETELL_DISCOVERY_AGENT_ID="agent_discovery_123"
export RETELL_BOOKING_AGENT_ID="agent_booking_456"
export RETELL_FROM_NUMBER="+14157774444"
```

Free tier: $10 credits (~60-90 minutes of calls). No monthly commitment.

## API Base

All requests: `https://api.retellai.com/v2` with `Authorization: Bearer $RETELL_API_KEY`

## Make a Discovery Call

Use the discovery agent to check venue availability, pricing, and details.

```bash
curl -X POST "https://api.retellai.com/v2/create-phone-call" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "from_number": "'$RETELL_FROM_NUMBER'",
    "to_number": "+1VENUE_PHONE_E164",
    "override_agent_id": "'$RETELL_DISCOVERY_AGENT_ID'",
    "retell_llm_dynamic_variables": {
      "venue_name": "The Venue NYC",
      "event_date": "Friday March 28",
      "headcount": "30 people",
      "event_type": "community dinner",
      "organization": "DOAC",
      "budget": "$2,000"
    },
    "metadata": {
      "call_type": "discovery",
      "venue": "The Venue NYC",
      "event": "NYC Dinner"
    }
  }'
```

## Make a Booking Call

Use the booking agent AFTER team approval to lock the reservation.

```bash
curl -X POST "https://api.retellai.com/v2/create-phone-call" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "from_number": "'$RETELL_FROM_NUMBER'",
    "to_number": "+1VENUE_PHONE_E164",
    "override_agent_id": "'$RETELL_BOOKING_AGENT_ID'",
    "retell_llm_dynamic_variables": {
      "venue_name": "The Venue NYC",
      "event_date": "Friday March 28",
      "headcount": "30",
      "event_type": "community dinner",
      "organization": "DOAC",
      "agreed_price": "$1,800",
      "setup_time": "5:00 PM",
      "event_start": "7:00 PM",
      "event_end": "11:00 PM",
      "email": "eve@agentmail.to",
      "cancellation_policy": "Full refund up to 7 days before",
      "contact_name": "Sarah"
    },
    "metadata": {
      "call_type": "booking",
      "venue": "The Venue NYC",
      "event": "NYC Dinner"
    }
  }'
```

**Important**: Phone numbers must be E.164 format: `+1234567890` (plus sign, country code, no spaces/hyphens).

Response includes `call_id` — use to retrieve transcript after the call ends.

The `retell_llm_dynamic_variables` are injected into the agent's prompt so it knows the context. Always pass all relevant variables from the event and venue records.

## Get Call (Transcript + Recording + Analysis)

```bash
curl "https://api.retellai.com/v2/get-call/{call_id}" \
  -H "Authorization: Bearer $RETELL_API_KEY"
```

Response fields:
- `transcript` — plain text: `"Agent: Hello...\nUser: Hi there..."`
- `transcript_object` — array of utterance objects with `role` ("agent"/"user"), `content`, and word-level timestamps
- `recording_url` — audio recording URL
- `call_analysis` — AI summary with `call_summary`, `in_voicemail` (bool), `user_sentiment`
- `start_timestamp`, `end_timestamp`, `duration_ms`
- `call_status` — "ended", "error", etc.
- `disconnection_reason` — why the call ended
- `call_cost` — cost in dollars

## List Calls

```bash
curl -X POST "https://api.retellai.com/v2/list-calls" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "sort_order": "descending", "limit": 20 }'
```

## Workflow for Venue Calls

1. **Before calling**: Confirm with the team member who to call and why
2. **Make the call**: `POST /v2/create-phone-call` with dynamic variables containing venue name, event details, and purpose
3. **Wait for completion**: Poll `GET /v2/get-call/{call_id}` until `call_status` is "ended" (check every 10 seconds)
4. **Extract results**: Get `transcript_object`, `call_analysis`, `duration_ms`, `recording_url`
5. **Save transcript**: Write as a JSONL chat session to `{{WORKSPACE_PATH}}/.openclaw/web-chat/call-{call_id}.jsonl` (see event-orchestration skill for format)
6. **Log to DuckDB**: Create entry in `communications` object
7. **Report to team**: Post inline status update with duration, outcome, and transcript link

## Gotchas

- Basic $2/month numbers may get flagged as spam by carriers. For production, use verified numbers ($100/month)
- Retell expects calls to last <10 minutes by default. Set `max_call_duration_ms` on the agent if longer calls are needed
- If venue doesn't answer, `call_analysis.in_voicemail` will be true — check this before processing transcript
- `call_status: "error"` means the call failed to connect — handle gracefully

## Links
- API Docs: https://docs.retellai.com/api-references
- Dashboard: https://app.retellai.com
- Pricing: https://www.retellai.com/pricing
