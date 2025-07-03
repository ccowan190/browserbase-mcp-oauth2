#!/bin/bash

# Ultimate debugging script to find the exact issue

echo "=== DEBUGGING BROWSERBASE DEPLOYMENT ==="
echo "Time: $(date)"
echo "Directory: $(pwd)"
echo "User: $(whoami)"
echo ""

# Test 1: Basic environment
echo "=== TEST 1: Basic Environment ==="
echo "Node version: $(node --version)"
echo "npm version: $(npm --version)"
echo "Docker version: $(docker --version)"
echo "gcloud version: $(gcloud --version | head -1)"
echo ""

# Test 2: gcloud configuration
echo "=== TEST 2: gcloud Configuration ==="
echo "Project: $(gcloud config get-value project)"
echo "Account: $(gcloud config get-value account)"
echo "Region: $(gcloud config get-value run/region)"
echo ""

# Test 3: File structure
echo "=== TEST 3: File Structure ==="
echo "Files in current directory:"
ls -la
echo ""
echo "Files in dist directory:"
ls -la dist/ | head -10
echo ""

# Test 4: Node.js app test
echo "=== TEST 4: Node.js App Test ==="
echo "Testing CLI help:"
node cli.js --help 2>&1 | head -5
echo ""

# Test 5: Docker build test
echo "=== TEST 5: Docker Build Test ==="
echo "Building Docker image..."
docker build -f Dockerfile.simple -t browserbase-test . 2>&1 | head -20
echo ""

# Test 6: Basic gcloud run command
echo "=== TEST 6: Basic gcloud run command ==="
echo "Testing gcloud run services list:"
gcloud run services list --region=us-central1 2>&1
echo ""

# Test 7: Actual deployment with verbose output
echo "=== TEST 7: Deployment Attempt ==="
echo "Attempting deployment with verbose output..."
gcloud run deploy browserbase-mcp-server \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --port 8080 \
  --memory 1Gi \
  --set-env-vars BROWSERBASE_API_KEY=bb_live_4in4Dta1-2QFnkgnD_dZMQxvo0M,BROWSERBASE_PROJECT_ID=f5f5588f-ce05-4b2d-8e07-f3531b1417a5 \
  --verbosity=debug 2>&1 | head -50

echo ""
echo "=== END OF DEBUGGING ==="
