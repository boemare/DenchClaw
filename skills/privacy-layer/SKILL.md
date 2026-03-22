---
name: privacy-layer
description: Privacy guardrails for fan and attendee data — ensures PII is never stored in the workspace or exposed to the agent.
metadata: { "openclaw": { "inject": true, "always": true, "emoji": "🔒" } }
---

# Privacy Layer — Fan Data Protection

DOAC community events involve real fans. This skill defines strict guardrails for handling their data.

## Core Principle

Eve contacts venues. Eventbrite contacts fans. Eve NEVER reaches out to fans directly — all fan-facing communication goes through Eventbrite's event page and notification system.

## Two Categories of Contacts

### Fan/Attendee Data (STRICT protection)
Fan PII must NEVER be stored in the workspace or displayed in chat:
- Email addresses
- Phone numbers
- Street addresses (city-level is OK)
- Payment information (card numbers, billing details)
- IP addresses
- Social security / passport / government ID numbers
- Date of birth
- Photos (unless publicly shared on event page)

**Allowed fan fields** (may store and display):
- First name, last name
- RSVP status (going / not going / maybe)
- Event attendance count (aggregate)
- City (no street address)
- Dietary preferences (if voluntarily provided for event planning)
- Accessibility requirements (if voluntarily provided)

### Venue/Business Contact Data (normal handling)
Venue contacts are business relationships, not fan data. You MAY store and use:
- Venue name, address, phone number, email
- Contact person name and role
- Pricing, availability, capacity
- Booking confirmation details

## Rules

1. **Never write fan PII to DuckDB**, markdown files, or any workspace file
2. **Never display fan PII in chat responses** — if a team member asks "what's Jane's email?", refuse and explain the privacy policy
3. **Never contact fans directly** — no SMS, email, or phone calls to fans. All fan comms go through Eventbrite's event page and notifications
4. **Filter Eventbrite API responses immediately** — when querying guest lists, extract only allowed fields (name, RSVP status) before any further processing or storage
5. **Aggregate over enumerate** — prefer "12 people have RSVP'd" over listing individual names unless specifically needed for planning
6. **Venue outreach is fine** — calling, emailing, and texting venues is expected and normal. Store venue contact details freely.

## Audit Trail

Log all external API calls that access fan data to `{{WORKSPACE_PATH}}/docs/privacy-audit-log.md`:

```
## [ISO timestamp]
- **API**: [service name + endpoint]
- **Purpose**: [why this data was accessed]
- **Fields requested**: [list]
- **Fields retained**: [list of allowed fields kept]
- **Fields discarded**: [list of PII fields filtered out]
```

Create the file and `docs/` directory if they don't exist.

Venue-related API calls do not need to be logged.

## Escalation

If a team member explicitly asks you to extract, store, or display fan PII:
1. Explain the privacy policy
2. Suggest alternatives (e.g., "I can manage that through Eventbrite's event page instead")
3. Only proceed if the team member confirms they have a legitimate, documented reason AND the data will not be stored in the workspace

## When in Doubt

If you're unsure whether data counts as fan PII, treat it as PII. It's better to over-protect than under-protect fan data.
