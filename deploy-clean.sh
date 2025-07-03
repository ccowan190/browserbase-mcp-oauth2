#!/bin/bash

# Clean deployment script for Browserbase MCP Server
# This script deploys from a clean directory to avoid any configuration conflicts

set -e

echo "🧹 Clean deployment of Browserbase MCP Server"
echo "📁 Deploying from: $(pwd)"
echo "🎯 Service: browserbase-mcp-server"
echo "🌍 Project: hundredx-mcp"
echo "📍 Region: us-central1"
echo ""

# Verify we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: package.json not found. Are you in the right directory?"
    exit 1
fi

if [ ! -f "cli.js" ]; then
    echo "❌ Error: cli.js not found. Are you in the right directory?"
    exit 1
fi

if [ ! -d "dist" ]; then
    echo "❌ Error: dist directory not found. The application needs to be built first."
    exit 1
fi

echo "✅ All required files found"
echo ""

# Clean deployment
echo "🚀 Starting deployment..."
gcloud run deploy browserbase-mcp-server \
  --source . \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars BROWSERBASE_API_KEY=bb_live_4in4Dta1-2QFnkgnD_dZMQxvo0M,BROWSERBASE_PROJECT_ID=f5f5588f-ce05-4b2d-8e07-f3531b1417a5 \
  --port 8080 \
  --memory 1Gi \
  --cpu 1 \
  --timeout 3600 \
  --max-instances 10 \
  --project hundredx-mcp

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    
    # Get service URL
    SERVICE_URL=$(gcloud run services describe browserbase-mcp-server --region=us-central1 --project=hundredx-mcp --format="value(status.url)")
    
    echo ""
    echo "🎉 Browserbase MCP Server is now running!"
    echo "🌐 Service URL: $SERVICE_URL"
    echo "🔗 SSE Endpoint: $SERVICE_URL/sse"
    echo "❤️  Health Check: $SERVICE_URL/health"
    echo ""
    echo "🎯 MCP Configuration:"
    echo "{"
    echo "  \"mcpServers\": {"
    echo "    \"browserbase\": {"
    echo "      \"url\": \"$SERVICE_URL/sse\","
    echo "      \"env\": {"
    echo "        \"BROWSERBASE_API_KEY\": \"bb_live_4in4Dta1-2QFnkgnD_dZMQxvo0M\","
    echo "        \"BROWSERBASE_PROJECT_ID\": \"f5f5588f-ce05-4b2d-8e07-f3531b1417a5\""
    echo "      }"
    echo "    }"
    echo "  }"
    echo "}"
    echo ""
    echo "🧪 Test the deployment:"
    echo "curl $SERVICE_URL/health"
    echo ""
else
    echo "❌ Deployment failed"
    echo "Check the logs above for details"
    exit 1
fi
