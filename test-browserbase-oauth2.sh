#!/bin/bash

# Test OAuth2 functionality for Browserbase MCP Server

set -e

SERVICE_URL="https://browserbase-mcp-server-7c3uq2gnva-uc.a.run.app"

echo "🧪 Testing Browserbase MCP Server OAuth2 functionality"
echo "Service URL: $SERVICE_URL"
echo

# Test 1: Health check
echo "1️⃣ Testing health check..."
HEALTH_STATUS=$(curl -s -w "%{http_code}" -o /tmp/browserbase_health.json "$SERVICE_URL/health")
if [[ "$HEALTH_STATUS" == "200" ]]; then
    echo "✅ Health check passed"
    cat /tmp/browserbase_health.json | jq .
else
    echo "❌ Health check failed (HTTP $HEALTH_STATUS)"
    cat /tmp/browserbase_health.json
fi
echo

# Test 2: Auth status
echo "2️⃣ Testing auth status..."
AUTH_STATUS=$(curl -s -w "%{http_code}" -o /tmp/browserbase_auth.json "$SERVICE_URL/auth/status")
if [[ "$AUTH_STATUS" == "200" ]]; then
    echo "✅ Auth status check passed"
    cat /tmp/browserbase_auth.json | jq .
else
    echo "❌ Auth status check failed (HTTP $AUTH_STATUS)"
    cat /tmp/browserbase_auth.json
fi
echo

# Test 3: SSE endpoint without auth (should challenge)
echo "3️⃣ Testing SSE endpoint without authentication..."
SSE_UNAUTH_STATUS=$(curl -s -w "%{http_code}" -o /tmp/browserbase_sse_unauth.json "$SERVICE_URL/sse")
if [[ "$SSE_UNAUTH_STATUS" == "401" ]]; then
    echo "✅ SSE endpoint correctly requires authentication"
    cat /tmp/browserbase_sse_unauth.json | jq . 2>/dev/null || cat /tmp/browserbase_sse_unauth.json
elif [[ "$SSE_UNAUTH_STATUS" == "403" ]]; then
    echo "✅ SSE endpoint correctly requires authentication (IAM mode)"
    echo "Response: $(cat /tmp/browserbase_sse_unauth.json)"
else
    echo "❌ SSE endpoint should require authentication (got HTTP $SSE_UNAUTH_STATUS)"
    cat /tmp/browserbase_sse_unauth.json
fi
echo

# Test 4: MCP endpoint without auth (should challenge) 
echo "4️⃣ Testing MCP endpoint without authentication..."
MCP_UNAUTH_STATUS=$(curl -s -w "%{http_code}" -o /tmp/browserbase_mcp_unauth.json "$SERVICE_URL/mcp")
if [[ "$MCP_UNAUTH_STATUS" == "401" ]]; then
    echo "✅ MCP endpoint correctly requires authentication"
    cat /tmp/browserbase_mcp_unauth.json | jq . 2>/dev/null || cat /tmp/browserbase_mcp_unauth.json
elif [[ "$MCP_UNAUTH_STATUS" == "403" ]]; then
    echo "✅ MCP endpoint correctly requires authentication (IAM mode)"
    echo "Response: $(cat /tmp/browserbase_mcp_unauth.json)"
else
    echo "❌ MCP endpoint should require authentication (got HTTP $MCP_UNAUTH_STATUS)"
    cat /tmp/browserbase_mcp_unauth.json
fi
echo

# Test 5: OAuth2 login endpoint (if OAuth2 is enabled)
echo "5️⃣ Testing OAuth2 login endpoint..."
if cat /tmp/browserbase_auth.json | jq -r '.auth_type' 2>/dev/null | grep -q "oauth2"; then
    LOGIN_STATUS=$(curl -s -w "%{http_code}" -o /tmp/browserbase_login.html "$SERVICE_URL/oauth/login")
    if [[ "$LOGIN_STATUS" == "302" ]]; then
        echo "✅ OAuth2 login endpoint working (redirects to Google)"
        REDIRECT_URL=$(curl -s -I "$SERVICE_URL/oauth/login" | grep -i "location:" | cut -d' ' -f2)
        echo "Redirect URL: $REDIRECT_URL"
    else
        echo "❌ OAuth2 login endpoint failed (HTTP $LOGIN_STATUS)"
        cat /tmp/browserbase_login.html
    fi
else
    echo "⚠️  OAuth2 not enabled, skipping login test"
fi
echo

# Test 6: Check environment configuration
echo "6️⃣ Environment configuration check..."
if cat /tmp/browserbase_health.json | jq -r '.auth' 2>/dev/null | grep -q "oauth2"; then
    echo "✅ OAuth2 authentication configured"
elif cat /tmp/browserbase_health.json | jq -r '.auth' 2>/dev/null | grep -q "iam"; then
    echo "✅ IAM authentication configured"
else
    echo "❌ Unknown authentication configuration"
fi
echo

echo "🎯 Test Summary:"
echo "- Health check: $(if [[ "$HEALTH_STATUS" == "200" ]]; then echo "✅ PASS"; else echo "❌ FAIL"; fi)"
echo "- Auth status: $(if [[ "$AUTH_STATUS" == "200" ]]; then echo "✅ PASS"; else echo "❌ FAIL"; fi)"
echo "- SSE auth required: $(if [[ "$SSE_UNAUTH_STATUS" == "401" || "$SSE_UNAUTH_STATUS" == "403" ]]; then echo "✅ PASS"; else echo "❌ FAIL"; fi)"
echo "- MCP auth required: $(if [[ "$MCP_UNAUTH_STATUS" == "401" || "$MCP_UNAUTH_STATUS" == "403" ]]; then echo "✅ PASS"; else echo "❌ FAIL"; fi)"
echo "- OAuth2 setup: $(if cat /tmp/browserbase_auth.json | jq -r '.auth_type' 2>/dev/null | grep -q "oauth2"; then echo "✅ ENABLED"; else echo "⚠️  DISABLED"; fi)"
echo

# Cleanup
rm -f /tmp/browserbase_*.json /tmp/browserbase_*.html

echo "🏁 Test completed!"
