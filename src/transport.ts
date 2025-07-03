import http from 'node:http';
import assert from 'node:assert';
import crypto from 'node:crypto';

import { ServerList } from './server.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { SSEServerTransport } from '@modelcontextprotocol/sdk/server/sse.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { OAuth2Handler } from './oauth2/index.js';

export async function startStdioTransport(serverList: ServerList) {
  const server = await serverList.create();
  await server.connect(new StdioServerTransport());
}

async function handleSSE(req: http.IncomingMessage, res: http.ServerResponse, url: URL, serverList: ServerList, sessions: Map<string, SSEServerTransport>) {
  if (req.method === 'POST') {
    const sessionId = url.searchParams.get('sessionId');
    if (!sessionId) {
      res.statusCode = 400;
      return res.end('Missing sessionId');
    }

    const transport = sessions.get(sessionId);
    if (!transport) {
      res.statusCode = 404;
      return res.end('Session not found');
    }

    return await transport.handlePostMessage(req, res);
  } else if (req.method === 'GET') {
    const transport = new SSEServerTransport('/sse', res);
    sessions.set(transport.sessionId, transport);
    const server = await serverList.create();
    res.on('close', () => {
      sessions.delete(transport.sessionId);
      serverList.close(server).catch(e => {
        // eslint-disable-next-line no-console
        // console.error(e);
      });
    });
    return await server.connect(transport);
  }

  res.statusCode = 405;
  res.end('Method not allowed');
}

async function handleStreamable(req: http.IncomingMessage, res: http.ServerResponse, serverList: ServerList, sessions: Map<string, StreamableHTTPServerTransport>) {
  const sessionId = req.headers['mcp-session-id'] as string | undefined;
  if (sessionId) {
    const transport = sessions.get(sessionId);
    if (!transport) {
      res.statusCode = 404;
      res.end('Session not found');
      return;
    }
    return await transport.handleRequest(req, res);
  }

  if (req.method === 'POST') {
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: () => crypto.randomUUID(),
      onsessioninitialized: sessionId => {
        sessions.set(sessionId, transport);
      }
    });
    transport.onclose = () => {
      if (transport.sessionId)
        sessions.delete(transport.sessionId);
    };
    const server = await serverList.create();
    await server.connect(transport);
    return await transport.handleRequest(req, res);
  }

  res.statusCode = 400;
  res.end('Invalid request');
}

function handleHealthCheck(req: http.IncomingMessage, res: http.ServerResponse) {
  if (req.method === 'GET') {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'application/json');
    
    // Check if OAuth2 is configured
    const authType = process.env.OAUTH2_CLIENT_ID && process.env.OAUTH2_CLIENT_SECRET ? 'oauth2' : 'iam';
    
    res.end(JSON.stringify({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'browserbase-mcp-server',
      auth: authType
    }));
  } else {
    res.statusCode = 405;
    res.end('Method not allowed');
  }
}

function handleAuthStatus(req: http.IncomingMessage, res: http.ServerResponse) {
  if (req.method === 'GET') {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'application/json');
    
    const isOAuth2Enabled = process.env.OAUTH2_CLIENT_ID && process.env.OAUTH2_CLIENT_SECRET;
    
    res.end(JSON.stringify({
      auth_type: isOAuth2Enabled ? 'oauth2' : 'iam',
      auth_enabled: true,
      login_url: isOAuth2Enabled ? '/oauth/login' : null
    }));
  } else {
    res.statusCode = 405;
    res.end('Method not allowed');
  }
}

export function startHttpTransport(port: number, hostname: string | undefined, serverList: ServerList) {
  const sseSessions = new Map<string, SSEServerTransport>();
  const streamableSessions = new Map<string, StreamableHTTPServerTransport>();
  
  // Initialize OAuth2 handler if credentials are available
  let oauth2Handler: OAuth2Handler | null = null;
  try {
    oauth2Handler = new OAuth2Handler();
    console.log('[OAuth2] OAuth2 authentication enabled');
  } catch (error) {
    console.log('[OAuth2] OAuth2 not configured - using IAM authentication fallback');
  }

  const httpServer = http.createServer(async (req, res) => {
    const url = new URL(`http://localhost${req.url}`);
    
    // Handle health check endpoint (always public)
    if (url.pathname === '/health') {
      return handleHealthCheck(req, res);
    }
    
    // Handle auth status endpoint (always public)
    if (url.pathname === '/auth/status') {
      return handleAuthStatus(req, res);
    }
    
    // Handle OAuth2 endpoints if OAuth2 is enabled
    if (oauth2Handler) {
      if (url.pathname === '/oauth/login') {
        return await oauth2Handler.handleAuth(req, res);
      }
      
      if (url.pathname === '/oauth/callback') {
        return await oauth2Handler.handleCallback(req, res);
      }
    }
    
    // Create wrapped handlers for authentication
    const handleWithAuth = async (handler: () => Promise<void>) => {
      if (oauth2Handler) {
        await oauth2Handler.authMiddleware(req, res, handler);
      } else {
        await handler();
      }
    };
    
    // Handle MCP endpoints with authentication
    if (url.pathname.startsWith('/mcp')) {
      await handleWithAuth(async () => {
        await handleStreamable(req, res, serverList, streamableSessions);
      });
    } else {
      // Handle SSE endpoints with authentication  
      await handleWithAuth(async () => {
        await handleSSE(req, res, url, serverList, sseSessions);
      });
    }
  });
  
  httpServer.listen(port, hostname, () => {
    const address = httpServer.address();
    assert(address, 'Could not bind server socket');
    let url: string;
    if (typeof address === 'string') {
      url = address;
    } else {
      const resolvedPort = address.port;
      let resolvedHost = address.family === 'IPv4' ? address.address : `[${address.address}]`;
      if (resolvedHost === '0.0.0.0' || resolvedHost === '[::]')
        resolvedHost = 'localhost';
      url = `http://${resolvedHost}:${resolvedPort}`;
    }
    
    const authType = oauth2Handler ? 'OAuth2' : 'IAM';
    
    const message = [
      `Listening on ${url}`,
      `Authentication: ${authType}`,
      oauth2Handler ? `OAuth2 login: ${url}/oauth/login` : '',
      'Put this in your client config:',
      JSON.stringify({
        'mcpServers': {
          'browserbase': {
            'url': `${url}/sse`
          }
        }
      }, undefined, 2),
      'If your client supports streamable HTTP, you can use the /mcp endpoint instead.',
      `Health check available at: ${url}/health`,
      `Auth status available at: ${url}/auth/status`
    ].filter(Boolean).join('\n');
    
    // eslint-disable-next-line no-console
    console.log(message);
  });
}
