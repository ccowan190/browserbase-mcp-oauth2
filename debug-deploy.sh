#!/bin/bash

# Debug script to capture the exact error

set -x  # Enable debug mode to see all commands

echo "=== Starting debug deployment ==="
echo "Current directory: $(pwd)"
echo "Current user: $(whoami)"
echo "Current time: $(date)"
echo ""

echo "=== Testing basic gcloud ==="
gcloud --version
echo ""

echo "=== Testing gcloud auth ==="
gcloud auth list
echo ""

echo "=== Testing gcloud config ==="
gcloud config list
echo ""

echo "=== Testing API enablement ==="
gcloud services list --enabled --filter="name:run.googleapis.com" --format="value(name)"
echo ""

echo "=== Testing Cloud Run permissions ==="
gcloud run services list --region=us-central1 --limit=1
echo ""

echo "=== Attempting deployment (this is where it usually fails) ==="
gcloud run deploy browserbase-mcp-server \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --port 8080 \
  --memory 1Gi \
  --set-env-vars BROWSERBASE_API_KEY=bb_live_4in4Dta1-2QFnkgnD_dZMQxvo0M,BROWSERBASE_PROJECT_ID=f5f5588f-ce05-4b2d-8e07-f3531b1417a5 \
  --verbosity=debug

echo "=== End of debug script ==="
