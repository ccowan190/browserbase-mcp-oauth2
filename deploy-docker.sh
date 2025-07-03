#!/bin/bash

# Alternative deployment using Docker build first
set -e

echo "🐳 Building Docker image locally first..."

# Build image locally
docker build -t browserbase-mcp-server .

# Tag for GCR
docker tag browserbase-mcp-server gcr.io/hundredx-mcp/browserbase-mcp-server

# Push to GCR
echo "📤 Pushing to Google Container Registry..."
docker push gcr.io/hundredx-mcp/browserbase-mcp-server

# Deploy from the pushed image
echo "🚀 Deploying to Cloud Run..."
gcloud run deploy browserbase-mcp-server \
  --image gcr.io/hundredx-mcp/browserbase-mcp-server \
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

echo "✅ Deployment complete!"

# Get service URL
SERVICE_URL=$(gcloud run services describe browserbase-mcp-server --region=us-central1 --format="value(status.url)")

echo ""
echo "🌐 Service URL: $SERVICE_URL"
echo "🔗 SSE Endpoint: $SERVICE_URL/sse"
echo "❤️  Health Check: $SERVICE_URL/health"
echo ""
echo "🧪 Test: curl $SERVICE_URL/health"
