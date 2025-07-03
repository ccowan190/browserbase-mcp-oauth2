# Browserbase MCP Server with OAuth2 Authentication

![Browserbase MCP](https://browserbase.com/images/mcp-logo.png)

A powerful browser automation MCP (Model Context Protocol) server built on Browserbase with OAuth2 authentication support for seamless Claude.ai integration.

## 🚀 Features

- **Browser Automation**: Full Playwright browser automation capabilities
- **OAuth2 Authentication**: Google OAuth2 integration for Claude.ai
- **Dual Authentication**: OAuth2 with Cloud Run IAM fallback
- **HundredX Integration**: Domain validation for @hundredxinc.com accounts
- **Claude.ai Ready**: Direct integration with Claude.ai remote MCP servers
- **Browserbase Cloud**: Serverless browser automation via Browserbase
- **Session Management**: Secure session handling with token expiration

## 🏗️ Architecture

```
Claude.ai → OAuth2 Flow → Browserbase MCP Server → Browserbase Cloud → Browser Automation
                ↓
        Google Authentication
                ↓
        HundredX Domain Validation
```

## 📦 Installation

### Prerequisites
- Node.js 18+ 
- Browserbase account and API key
- Docker (for deployment)
- Google Cloud SDK (`gcloud`)

### Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ccowan190/browserbase-mcp-oauth2.git
   cd browserbase-mcp-oauth2
   ```

2. **Install dependencies**:
   ```bash
   npm install && npm run build
   ```

3. **Configure environment variables**:
   ```bash
   export BROWSERBASE_API_KEY="your-browserbase-api-key"
   export BROWSERBASE_PROJECT_ID="your-browserbase-project-id"
   export OAUTH2_CLIENT_ID="your-google-client-id"
   export OAUTH2_CLIENT_SECRET="your-google-client-secret"
   ```

4. **Deploy to Google Cloud Run**:
   ```bash
   ./deploy-browserbase-oauth2.sh
   ```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `BROWSERBASE_API_KEY` | Browserbase API key | Yes |
| `BROWSERBASE_PROJECT_ID` | Browserbase project ID | Yes |
| `OAUTH2_CLIENT_ID` | Google OAuth2 Client ID | Optional* |
| `OAUTH2_CLIENT_SECRET` | Google OAuth2 Client Secret | Optional* |
| `OAUTH2_REDIRECT_URL` | OAuth2 callback URL | Optional |

*If not provided, server falls back to Cloud Run IAM authentication

### Browserbase Setup

1. **Create Browserbase Account**: Sign up at [browserbase.com](https://browserbase.com)
2. **Get API Credentials**: 
   - API Key from your dashboard
   - Project ID from your project settings

### OAuth2 Setup

1. **Create OAuth2 Credentials** in [Google Cloud Console](https://console.cloud.google.com/apis/credentials):
   - Application type: Web application
   - Name: Browserbase MCP Server for Claude.ai
   - Authorized origins: `https://claude.ai`, `https://api.anthropic.com`
   - Redirect URIs: `https://claude.ai/oauth/callback`, `https://api.anthropic.com/oauth/callback`

## 🌐 Browser Automation Capabilities

### Available Tools

- **Page Navigation**: Navigate to URLs, go back/forward
- **Element Interaction**: Click, type, hover on elements
- **Form Handling**: Fill forms, submit data
- **Screenshot Capture**: Take full page or element screenshots
- **Content Extraction**: Get text, HTML, or structured data
- **Wait Operations**: Wait for elements, network, or timeouts
- **JavaScript Execution**: Run custom JavaScript in browser context

### Example Usage

```javascript
// Navigate to a website
await browserbase.navigate('https://example.com');

// Take a screenshot
const screenshot = await browserbase.screenshot();

// Click an element
await browserbase.click('button[type="submit"]');

// Extract text content
const text = await browserbase.getText('.content');
```

## 🌐 API Endpoints

### Health Check
```http
GET /health
```
Response:
```json
{
  "status": "ok",
  "service": "browserbase-mcp-server",
  "auth": "oauth2|iam",
  "browserbase": "connected"
}
```

### Authentication Status
```http
GET /auth/status
```
Response:
```json
{
  "auth_type": "oauth2|iam",
  "auth_enabled": true,
  "login_url": "/oauth/login"
}
```

### OAuth2 Authentication (when enabled)
```http
GET /oauth/login          # Initiates OAuth2 flow
GET /oauth/callback       # Handles OAuth2 callback
```

### MCP Protocol
```http
POST /mcp                 # Browser automation operations (requires auth)
```

## 🔐 Claude.ai Integration

### Option 1: OAuth2 Authentication (Recommended)
1. Deploy with OAuth2 credentials configured
2. In Claude.ai integration settings:
   - **Service URL**: `https://your-service-url/mcp`
   - **OAuth Client ID**: Your Google OAuth2 Client ID

### Option 2: NPM Package (Local Development)
```json
{
  "mcpServers": {
    "browserbase": {
      "command": "npx",
      "args": ["@browserbasehq/mcp"],
      "env": {
        "BROWSERBASE_API_KEY": "your-api-key",
        "BROWSERBASE_PROJECT_ID": "your-project-id"
      }
    }
  }
}
```

### Option 3: Proxy Method (Development)
```bash
# Start authenticated proxy
gcloud run services proxy browserbase-mcp-server --region=us-central1 --project=your-project --port=8080

# Configure Claude Desktop
# URL: http://localhost:8080/mcp
```

## 🧪 Testing

Run the comprehensive test suite:
```bash
./test-browserbase-oauth2.sh
```

Tests include:
- Health check endpoint
- Authentication status
- MCP endpoint protection
- OAuth2 flow (when enabled)
- Browser automation functionality

## 🛡️ Security Features

- **Domain Validation**: Only @hundredxinc.com email addresses allowed
- **Token Expiration**: Session tokens expire after 1 hour
- **Secure Sessions**: Browser sessions isolated per user
- **HTTPS Only**: All OAuth2 flows use secure connections
- **IAM Fallback**: Cloud Run IAM security when OAuth2 not configured

## 📁 Project Structure

```
├── src/
│   ├── oauth2/                   # OAuth2 authentication
│   │   ├── oauth2.ts            # OAuth2 handler implementation
│   │   └── index.ts             # OAuth2 exports
│   ├── tools/                   # Browser automation tools
│   ├── server.ts                # Main MCP server
│   ├── sessionManager.ts       # Session management
│   └── transport.ts             # HTTP transport with OAuth2
├── deploy-browserbase-oauth2.sh # Deployment script
├── test-browserbase-oauth2.sh   # Testing script
├── Dockerfile                   # Container configuration
└── README.md                    # This file
```

## 🚀 Deployment

### Google Cloud Run
```bash
# Build and deploy
./deploy-browserbase-oauth2.sh

# Or manually:
docker build -t gcr.io/your-project/browserbase-mcp:oauth2 .
docker push gcr.io/your-project/browserbase-mcp:oauth2
gcloud run deploy browserbase-mcp-server \
  --image=gcr.io/your-project/browserbase-mcp:oauth2 \
  --set-env-vars="OAUTH2_CLIENT_ID=your-id,OAUTH2_CLIENT_SECRET=your-secret,BROWSERBASE_API_KEY=your-key"
```

### Local Development
```bash
# Run locally with OAuth2
npm run build
BROWSERBASE_API_KEY=your-key \
OAUTH2_CLIENT_ID=your-id \
OAUTH2_CLIENT_SECRET=your-secret \
node cli.js
```

## 🔄 Authentication Modes

### OAuth2 Mode
- **Enabled**: When `OAUTH2_CLIENT_ID` and `OAUTH2_CLIENT_SECRET` are set
- **Flow**: Google OAuth2 → Domain validation → Session token
- **Claude.ai**: Direct integration with OAuth Client ID

### IAM Mode (Fallback)
- **Enabled**: When OAuth2 credentials are not configured
- **Flow**: Google Cloud IAM authentication
- **Claude.ai**: Requires proxy or service account

## 📊 Monitoring

Monitor your deployment:
```bash
# Check health
curl https://your-service-url/health

# Check auth status
curl https://your-service-url/auth/status

# View logs
gcloud run services logs read browserbase-mcp-server --region=us-central1
```

## 🎯 Use Cases

- **Web Scraping**: Extract data from dynamic websites
- **Form Automation**: Fill and submit forms automatically
- **Testing**: Automated UI testing and validation
- **Screenshots**: Capture website screenshots for documentation
- **Data Collection**: Gather information from multiple sources
- **Monitoring**: Website uptime and content monitoring

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is based on Browserbase's MCP server with OAuth2 enhancements.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/ccowan190/browserbase-mcp-oauth2/issues)
- **Browserbase Docs**: [browserbase.com/docs](https://browserbase.com/docs)
- **MCP Protocol**: [modelcontextprotocol.io](https://modelcontextprotocol.io)

## 🎯 Roadmap

- [ ] JWT token signing for enhanced security
- [ ] Multiple OAuth2 provider support
- [ ] Advanced session management
- [ ] Browser session recording
- [ ] Custom browser configurations
- [ ] Parallel browser operations

---

Built with ❤️ for browser automation and Claude.ai integration.
