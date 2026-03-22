---
name: eventbrite
description: Create and manage events on Eventbrite — event creation, publishing, attendee tracking, venue management via the Eventbrite REST API. Free for free events.
metadata: { "openclaw": { "inject": true, "always": true, "emoji": "🎟️" } }
---

# Eventbrite — Event Management

Create, publish, and manage DOAC community events on Eventbrite. Eventbrite handles all fan-facing comms: invitations, RSVPs, waitlists, reminders, and check-ins.

## Prerequisites (must be done once)

1. Sign up at https://www.eventbrite.com
2. Go to Account Settings → Developer Links → API Keys → Create API Key
3. Get Organization ID: call `GET /v3/users/me/organizations/` with your API key

## Environment Variables

```bash
export EVENTBRITE_API_KEY="your_oauth_token"
export EVENTBRITE_ORG_ID="123456789"
```

Free tier: 1,000 API calls/hour, no fees for free events with <25 attendees.

## API Base

All requests: `https://www.eventbriteapi.com/v3` with `Authorization: Bearer $EVENTBRITE_API_KEY`

## Get Organization ID (if not known)

```bash
curl "https://www.eventbriteapi.com/v3/users/me/organizations/" \
  -H "Authorization: Bearer $EVENTBRITE_API_KEY"
```

Returns list of organizations with their `id` fields.

## Full Event Creation Flow

**IMPORTANT**: Events must follow this exact sequence: Create → Add Tickets → Publish

### Step 1: Create Event (Draft)

```bash
curl -X POST "https://www.eventbriteapi.com/v3/organizations/$EVENTBRITE_ORG_ID/events/" \
  -H "Authorization: Bearer $EVENTBRITE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event": {
      "name": {"html": "DOAC Community Dinner — NYC"},
      "description": {"html": "<p>Join fellow DOAC fans for an evening dinner in NYC! Meet the community, make new friends, enjoy great food.</p>"},
      "start": {"timezone": "America/New_York", "utc": "2026-04-10T23:00:00Z"},
      "end": {"timezone": "America/New_York", "utc": "2026-04-11T02:00:00Z"},
      "currency": "USD",
      "capacity": 30,
      "online_event": false,
      "listed": true,
      "shareable": true,
      "invite_only": false
    }
  }'
```

Returns event object with `id` — save this as `event_id`.

### Step 2: Create Ticket Class (REQUIRED before publishing)

```bash
curl -X POST "https://www.eventbriteapi.com/v3/events/{event_id}/ticket_classes/" \
  -H "Authorization: Bearer $EVENTBRITE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "ticket_class": {
      "name": "General Admission",
      "free": true,
      "quantity_total": 30
    }
  }'
```

**Without a ticket class, the publish step will fail.**

### Step 3: Create/Attach Venue (Optional)

```bash
curl -X POST "https://www.eventbriteapi.com/v3/organizations/$EVENTBRITE_ORG_ID/venues/" \
  -H "Authorization: Bearer $EVENTBRITE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "venue": {
      "name": "The Venue NYC",
      "address": {
        "address_1": "123 Main St",
        "city": "New York",
        "region": "NY",
        "postal_code": "10001",
        "country": "US"
      }
    }
  }'
```

Then update the event with the venue:
```bash
curl -X POST "https://www.eventbriteapi.com/v3/events/{event_id}/" \
  -H "Authorization: Bearer $EVENTBRITE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"event": {"venue_id": "{venue_id}"}}'
```

### Step 4: Publish Event

```bash
curl -X POST "https://www.eventbriteapi.com/v3/events/{event_id}/publish/" \
  -H "Authorization: Bearer $EVENTBRITE_API_KEY"
```

Returns `{"published": true}`. Event is now live and accepting RSVPs.

## Check Attendees / RSVPs

```bash
curl "https://www.eventbriteapi.com/v3/events/{event_id}/attendees/" \
  -H "Authorization: Bearer $EVENTBRITE_API_KEY"
```

Returns attendee list with `profile.first_name`, `profile.last_name`, `profile.email`, etc.

**Privacy rule**: Only extract `first_name`, `last_name`, and RSVP status. NEVER store `email`, `cell_phone`, or `addresses` in DuckDB.

## List Events

```bash
curl "https://www.eventbriteapi.com/v3/organizations/$EVENTBRITE_ORG_ID/events/?status=live" \
  -H "Authorization: Bearer $EVENTBRITE_API_KEY"
```

Status options: `draft`, `live`, `started`, `ended`, `completed`, `canceled`

## Cancel Event

```bash
curl -X POST "https://www.eventbriteapi.com/v3/events/{event_id}/cancel/" \
  -H "Authorization: Bearer $EVENTBRITE_API_KEY"
```

## Gotchas

- Events are always created as drafts — you must publish separately
- Ticket class is REQUIRED before publishing (most common error)
- `GET /v3/users/me/events/` is DEPRECATED — use organization-based endpoints
- Event search API was removed in 2019 — list by organization instead
- Free events with 25+ attendees may incur fees (check current pricing)
- Rate limit: 1,000 calls/hour per OAuth token

## Links
- API Docs: https://www.eventbrite.com/platform/api
- Developer Portal: https://www.eventbrite.com/platform/
- Dashboard: https://www.eventbrite.com/organizations/events
