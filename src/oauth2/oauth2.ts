import crypto from 'node:crypto';
import { IncomingMessage, ServerResponse } from 'node:http';
import { URL } from 'node:url';

export interface OAuth2Config {
  clientId: string;
  clientSecret: string;
  redirectUrl: string;
  scopes: string[];
  authUrl: string;
  tokenUrl: string;
}

export interface UserInfo {
  email: string;
  name: string;
  picture?: string;
  verified?: boolean;
}

export interface SessionToken {
  email: string;
  name: string;
  iat: number;
  exp: number;
}

export class OAuth2Handler {
  private config: OAuth2Config;

  constructor() {
    const clientId = process.env.OAUTH2_CLIENT_ID;
    const clientSecret = process.env.OAUTH2_CLIENT_SECRET;
    const redirectUrl = process.env.OAUTH2_REDIRECT_URL;

    if (!clientId || !clientSecret) {
      throw new Error('OAuth2 credentials not configured. Set OAUTH2_CLIENT_ID and OAUTH2_CLIENT_SECRET environment variables');
    }

    this.config = {
      clientId,
      clientSecret,
      redirectUrl: redirectUrl || 'https://browserbase-mcp-server-7c3uq2gnva-uc.a.run.app/oauth/callback',
      scopes: ['openid', 'email', 'profile'],
      authUrl: 'https://accounts.google.com/o/oauth2/auth',
      tokenUrl: 'https://oauth2.googleapis.com/token'
    };
  }

  private generateState(): string {
    return crypto.randomBytes(32).toString('base64url');
  }

  private generateAuthUrl(state: string): string {
    const params = new URLSearchParams({
      response_type: 'code',
      client_id: this.config.clientId,
      redirect_uri: this.config.redirectUrl,
      scope: this.config.scopes.join(' '),
      state: state,
      access_type: 'offline'
    });

    return `${this.config.authUrl}?${params.toString()}`;
  }

  async handleAuth(req: IncomingMessage, res: ServerResponse): Promise<void> {
    const state = this.generateState();
    const authUrl = this.generateAuthUrl(state);

    console.log(`[OAuth2] Redirecting to: ${authUrl}`);
    
    res.statusCode = 302;
    res.setHeader('Location', authUrl);
    res.end();
  }

  async handleCallback(req: IncomingMessage, res: ServerResponse): Promise<void> {
    const url = new URL(`http://localhost${req.url}`);
    const code = url.searchParams.get('code');
    const state = url.searchParams.get('state');

    if (!code) {
      res.statusCode = 400;
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ error: 'No code provided' }));
      return;
    }

    if (!state) {
      res.statusCode = 400;
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ error: 'No state provided' }));
      return;
    }

    try {
      // Exchange code for token
      const tokenResponse = await this.exchangeCodeForToken(code);
      
      // Get user info
      const userInfo = await this.getUserInfo(tokenResponse.access_token);
      
      // Validate user domain (HundredX only)
      if (!userInfo.email.endsWith('@hundredxinc.com')) {
        console.error(`[OAuth2] Unauthorized domain: ${userInfo.email}`);
        res.statusCode = 403;
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({ error: 'Unauthorized domain' }));
        return;
      }

      // Create session token
      const sessionToken = this.createSessionToken(userInfo);

      res.statusCode = 200;
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({
        access_token: sessionToken,
        token_type: 'Bearer',
        expires_in: 3600,
        user: userInfo
      }));

    } catch (error) {
      console.error('[OAuth2] Callback error:', error);
      res.statusCode = 500;
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ error: 'Authentication failed' }));
    }
  }

  private async exchangeCodeForToken(code: string): Promise<any> {
    const params = new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: this.config.clientId,
      client_secret: this.config.clientSecret,
      redirect_uri: this.config.redirectUrl,
      code: code
    });

    const response = await fetch(this.config.tokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: params.toString()
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Token exchange failed: ${response.status} ${errorText}`);
    }

    return await response.json();
  }

  private async getUserInfo(accessToken: string): Promise<UserInfo> {
    const response = await fetch('https://www.googleapis.com/oauth2/v2/userinfo', {
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    });

    if (!response.ok) {
      throw new Error(`Failed to get user info: ${response.status}`);
    }

    const userInfo = await response.json();
    return {
      email: userInfo.email,
      name: userInfo.name,
      picture: userInfo.picture,
      verified: userInfo.verified_email
    };
  }

  private createSessionToken(userInfo: UserInfo): string {
    const tokenData: SessionToken = {
      email: userInfo.email,
      name: userInfo.name,
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 3600 // 1 hour
    };

    // Simple base64 encoding (in production, use proper JWT signing)
    return Buffer.from(JSON.stringify(tokenData)).toString('base64');
  }

  validateToken(token: string): UserInfo | null {
    try {
      const tokenData: SessionToken = JSON.parse(Buffer.from(token, 'base64').toString());
      
      // Check expiration
      if (Date.now() / 1000 > tokenData.exp) {
        return null;
      }

      return {
        email: tokenData.email,
        name: tokenData.name
      };
    } catch (error) {
      return null;
    }
  }

  authMiddleware = async (req: IncomingMessage, res: ServerResponse, next: () => Promise<void>): Promise<void> => {
    const url = new URL(`http://localhost${req.url}`);
    
    // Skip authentication for OAuth2 endpoints and health check
    if (url.pathname.startsWith('/oauth/') || url.pathname === '/health') {
      return await next();
    }

    // Check for Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader) {
      return this.sendAuthChallenge(req, res);
    }

    // Extract token from "Bearer <token>" format
    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
      return this.sendAuthChallenge(req, res);
    }

    const token = parts[1];
    const userInfo = this.validateToken(token);
    
    if (!userInfo) {
      return this.sendAuthChallenge(req, res);
    }

    // Add user info to request (extend the request object)
    (req as any).user = userInfo;
    console.log(`[OAuth2] Authenticated user: ${userInfo.email}`);
    
    await next();
  };

  private sendAuthChallenge(req: IncomingMessage, res: ServerResponse): void {
    const acceptHeader = req.headers.accept || '';
    
    // For web browsers, redirect to OAuth2 authorization
    if (acceptHeader.includes('text/html')) {
      this.handleAuth(req, res);
      return;
    }

    // For API clients, return JSON with authorization URL
    const state = this.generateState();
    const authUrl = this.generateAuthUrl(state);

    res.statusCode = 401;
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({
      error: 'authentication_required',
      authorization_url: authUrl,
      message: 'Please authenticate using the provided authorization URL'
    }));
  }
}
