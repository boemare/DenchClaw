#!/bin/bash
# Eve Integration Tests — verifies all three APIs are working
# Usage: bash scripts/test-integrations.sh

# set -e  # disabled so all tests run even if some fail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
PASS=0
FAIL=0

# API Keys
EVENTBRITE_API_KEY="67ME7MOJSJJXIN3RHT3P"
AGENTMAIL_API_KEY="am_us_63b86078126299514e0b00cac0dc6922dc4fbcee90a2b2c9e71858c1897bacb6"
AGENTMAIL_EMAIL="eveevent@agentmail.to"
RETELL_API_KEY="key_3ab9816682fbb6ed39ec045aaea3"
RETELL_DISCOVERY_AGENT_ID="agent_307683886318cb6d75df72a001"
RETELL_BOOKING_AGENT_ID="agent_80d03758ee80a7fb3d9c1e00ca"
RETELL_FROM_NUMBER="+12542326700"

pass() { echo -e "  ${GREEN}✓ $1${NC}"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}✗ $1${NC}"; echo -e "    ${RED}$2${NC}"; FAIL=$((FAIL+1)); }

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  EVE INTEGRATION TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ═══════════════════════════════════════════
# EVENTBRITE
# ═══════════════════════════════════════════
echo -e "${YELLOW}▸ Eventbrite${NC}"

# Test 1: Auth — get user info
EB_USER=$(curl -s "https://www.eventbriteapi.com/v3/users/me/" \
  -H "Authorization: Bearer $EVENTBRITE_API_KEY" 2>&1)

if echo "$EB_USER" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null | grep -q .; then
  EB_NAME=$(echo "$EB_USER" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('name','unknown'))" 2>/dev/null)
  pass "Auth works (user: $EB_NAME)"
else
  fail "Auth failed" "$EB_USER"
fi

# Test 2: Get organization ID
EB_ORGS=$(curl -s "https://www.eventbriteapi.com/v3/users/me/organizations/" \
  -H "Authorization: Bearer $EVENTBRITE_API_KEY" 2>&1)

EB_ORG_ID=$(echo "$EB_ORGS" | python3 -c "import sys,json; d=json.load(sys.stdin); orgs=d.get('organizations',[]); print(orgs[0]['id'] if orgs else '')" 2>/dev/null)

if [ -n "$EB_ORG_ID" ]; then
  pass "Organization ID: $EB_ORG_ID"
else
  fail "No organizations found — create one at eventbrite.com/organizations" ""
fi

# Test 3: Create a draft event
if [ -n "$EB_ORG_ID" ]; then
  EB_EVENT=$(curl -s -X POST "https://www.eventbriteapi.com/v3/organizations/$EB_ORG_ID/events/" \
    -H "Authorization: Bearer $EVENTBRITE_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "event": {
        "name": {"html": "Eve Integration Test Event"},
        "description": {"html": "<p>Automated test — will be deleted</p>"},
        "start": {"timezone": "America/New_York", "utc": "2026-12-25T20:00:00Z"},
        "end": {"timezone": "America/New_York", "utc": "2026-12-25T23:00:00Z"},
        "currency": "USD",
        "online_event": true,
        "listed": false
      }
    }' 2>&1)

  EB_EVENT_ID=$(echo "$EB_EVENT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)

  if [ -n "$EB_EVENT_ID" ]; then
    pass "Create draft event (ID: $EB_EVENT_ID)"

    # Test 4: Create ticket class
    EB_TICKET=$(curl -s -X POST "https://www.eventbriteapi.com/v3/events/$EB_EVENT_ID/ticket_classes/" \
      -H "Authorization: Bearer $EVENTBRITE_API_KEY" \
      -H "Content-Type: application/json" \
      -d '{
        "ticket_class": {
          "name": "Test Ticket",
          "free": true,
          "quantity_total": 10
        }
      }' 2>&1)

    if echo "$EB_TICKET" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null | grep -q .; then
      pass "Create ticket class"
    else
      fail "Create ticket class failed" "$EB_TICKET"
    fi

    # Test 5: List events
    EB_LIST=$(curl -s "https://www.eventbriteapi.com/v3/organizations/$EB_ORG_ID/events/?status=draft" \
      -H "Authorization: Bearer $EVENTBRITE_API_KEY" 2>&1)

    if echo "$EB_LIST" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('events',[])))" 2>/dev/null | grep -q "[0-9]"; then
      EB_COUNT=$(echo "$EB_LIST" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d['events']))" 2>/dev/null)
      pass "List events ($EB_COUNT drafts)"
    else
      fail "List events failed" "$EB_LIST"
    fi

    # Cleanup: delete test event
    curl -s -X DELETE "https://www.eventbriteapi.com/v3/events/$EB_EVENT_ID/" \
      -H "Authorization: Bearer $EVENTBRITE_API_KEY" > /dev/null 2>&1
    echo -e "  ${GREEN}  (cleaned up test event)${NC}"
  else
    fail "Create draft event failed" "$EB_EVENT"
  fi
fi

echo ""

# ═══════════════════════════════════════════
# AGENTMAIL
# ═══════════════════════════════════════════
echo -e "${YELLOW}▸ AgentMail${NC}"

# Test 6: List inboxes
AM_INBOXES=$(curl -s "https://api.agentmail.to/v0/inboxes" \
  -H "Authorization: Bearer $AGENTMAIL_API_KEY" 2>&1)

if echo "$AM_INBOXES" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('inboxes',[])))" 2>/dev/null | grep -q "[0-9]"; then
  AM_COUNT=$(echo "$AM_INBOXES" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d['inboxes']))" 2>/dev/null)
  pass "Auth works ($AM_COUNT inboxes)"
else
  fail "Auth failed" "$AM_INBOXES"
fi

# Test 7: Find inbox ID for eveevent@agentmail.to
AM_INBOX_ID=$(echo "$AM_INBOXES" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for inbox in d.get('inboxes',[]):
    if inbox.get('email_address','') == '$AGENTMAIL_EMAIL' or inbox.get('username','') == 'eveevent':
        print(inbox.get('inbox_id', inbox.get('id','')))
        break
" 2>/dev/null)

if [ -n "$AM_INBOX_ID" ]; then
  pass "Inbox found: $AGENTMAIL_EMAIL (ID: $AM_INBOX_ID)"
else
  # Try to get first inbox
  AM_INBOX_ID=$(echo "$AM_INBOXES" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['inboxes'][0].get('inbox_id', d['inboxes'][0].get('id','')))" 2>/dev/null)
  if [ -n "$AM_INBOX_ID" ]; then
    pass "Using first inbox (ID: $AM_INBOX_ID)"
  else
    fail "No inbox found for $AGENTMAIL_EMAIL" "$AM_INBOXES"
  fi
fi

# Test 8: Send a test email (to ourselves)
if [ -n "$AM_INBOX_ID" ]; then
  AM_SEND=$(curl -s -X POST "https://api.agentmail.to/v0/inboxes/$AM_INBOX_ID/messages/send" \
    -H "Authorization: Bearer $AGENTMAIL_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"to\": \"$AGENTMAIL_EMAIL\",
      \"subject\": \"Eve Integration Test — $(date +%H:%M:%S)\",
      \"text\": \"This is an automated integration test from Eve. You can ignore this.\",
      \"html\": \"<p>This is an automated integration test from Eve. You can ignore this.</p>\"
    }" 2>&1)

  AM_MSG_ID=$(echo "$AM_SEND" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message_id', d.get('id','')))" 2>/dev/null)

  if [ -n "$AM_MSG_ID" ]; then
    pass "Send email (message ID: $AM_MSG_ID)"
  else
    fail "Send email failed" "$AM_SEND"
  fi

  # Test 9: List threads
  AM_THREADS=$(curl -s "https://api.agentmail.to/v0/inboxes/$AM_INBOX_ID/threads" \
    -H "Authorization: Bearer $AGENTMAIL_API_KEY" 2>&1)

  if echo "$AM_THREADS" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    pass "List threads"
  else
    fail "List threads failed" "$AM_THREADS"
  fi
fi

echo ""

# ═══════════════════════════════════════════
# RETELL AI
# ═══════════════════════════════════════════
echo -e "${YELLOW}▸ Retell AI${NC}"

# Test 10: List agents
RT_AGENTS=$(curl -s "https://api.retellai.com/list-agents" \
  -H "Authorization: Bearer $RETELL_API_KEY" 2>&1)

if echo "$RT_AGENTS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null | grep -q "[0-9]"; then
  RT_COUNT=$(echo "$RT_AGENTS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null)
  pass "Auth works ($RT_COUNT agents)"
else
  fail "Auth failed" "$(echo "$RT_AGENTS" | head -5)"
fi

# Test 11: Verify discovery agent exists
RT_DISC=$(curl -s "https://api.retellai.com/get-agent/$RETELL_DISCOVERY_AGENT_ID" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" 2>&1)

RT_DISC_NAME=$(echo "$RT_DISC" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('agent_name',''))" 2>/dev/null)

if [ -n "$RT_DISC_NAME" ]; then
  pass "Discovery agent: $RT_DISC_NAME"
else
  fail "Discovery agent not found ($RETELL_DISCOVERY_AGENT_ID)" "$(echo "$RT_DISC" | head -3)"
fi

# Test 12: Verify booking agent exists
RT_BOOK=$(curl -s "https://api.retellai.com/get-agent/$RETELL_BOOKING_AGENT_ID" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" 2>&1)

RT_BOOK_NAME=$(echo "$RT_BOOK" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('agent_name',''))" 2>/dev/null)

if [ -n "$RT_BOOK_NAME" ]; then
  pass "Booking agent: $RT_BOOK_NAME"
else
  fail "Booking agent not found ($RETELL_BOOKING_AGENT_ID)" "$(echo "$RT_BOOK" | head -3)"
fi

# Test 13: Verify phone number
RT_NUMBERS=$(curl -s "https://api.retellai.com/list-phone-numbers" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" 2>&1)

RT_HAS_NUMBER=$(echo "$RT_NUMBERS" | python3 -c "
import sys,json
d=json.load(sys.stdin)
items = d if isinstance(d, list) else d.get('items', d.get('phone_numbers', []))
found = any(n.get('phone_number','') == '$RETELL_FROM_NUMBER' for n in items)
print('yes' if found else 'no')
" 2>/dev/null)

if [ "$RT_HAS_NUMBER" = "yes" ]; then
  pass "Phone number verified: $RETELL_FROM_NUMBER"
else
  fail "Phone number $RETELL_FROM_NUMBER not found" "$RT_NUMBERS"
fi

# Test 14: List recent calls
RT_CALLS=$(curl -s -X POST "https://api.retellai.com/v2/list-calls" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"sort_order": "descending", "limit": 5}' 2>&1)

if echo "$RT_CALLS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null | grep -q "[0-9]"; then
  RT_CALL_COUNT=$(echo "$RT_CALLS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null)
  pass "List calls ($RT_CALL_COUNT recent)"
else
  fail "List calls failed" "$RT_CALLS"
fi

echo ""

# ═══════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASS+FAIL))
if [ $FAIL -eq 0 ]; then
  echo -e "  ${GREEN}All $TOTAL tests passed ✓${NC}"
else
  echo -e "  ${GREEN}$PASS passed${NC} / ${RED}$FAIL failed${NC} (out of $TOTAL)"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit $FAIL
