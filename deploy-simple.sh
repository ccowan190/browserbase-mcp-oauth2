#!/bin/bash

# Ultra-simple deployment script
# Just the essential gcloud run deploy command

cd /Users/chriscowan/Desktop/Claude/browserbase-mcp-clean

echo "🚀 Deploying Browserbase MCP Server..."
echo "📁 From: $(pwd)"
echo ""

gcloud run deploy browserbase-mcp-server \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --port 8080 \
  --memory 1Gi \
  --set-env-vars BROWSERBASE_API_KEY=bb_live_4in4Dta1-2QFnkgnD_dZMQxvo0M,BROWSERBASE_PROJECT_ID=f5f5588f-ce05-4b2d-8e07-f3531b1417a5

echo ""
echo "✅ If successful, get the URL with:"
echo "gcloud run services describe browserbase-mcp-server --region=us-central1 --format=\"value(status.url)\""
