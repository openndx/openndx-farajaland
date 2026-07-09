import { Router, Request, Response } from 'express';
import axios from 'axios';
import * as https from 'node:https';
import * as crypto from 'node:crypto';

const router = Router();

const googleClientId = process.env.GOOGLE_CLIENT_ID || '';
const googleClientSecret = process.env.GOOGLE_CLIENT_SECRET || '';
const thunderidTokenUrl = process.env.TOKEN_URL || 'https://localhost:8090/oauth2/token';
const passportClientId = process.env.CLIENT_ID || '';
const passportClientSecret = process.env.CLIENT_SECRET || '';
const mockUserEmail = process.env.MOCK_USER_EMAIL || 'nuwan@opensource.lk';

const isMockMode = !googleClientId || googleClientId.includes('placeholder');

// Google Auth Redirect Initiation
router.get('/google', (req: Request, res: Response) => {
  const host = req.get('host') || 'localhost:3000';
  const redirectUri = `${req.protocol}://${host}/login`;

  if (isMockMode) {
    console.log('[Auth] Mock mode active. Redirecting client back with mock-code.');
    return res.redirect(`${redirectUri}?code=mock-code`);
  }

  const state = crypto.randomBytes(16).toString('hex');
  res.cookie('oauth_state', state, { httpOnly: true, sameSite: 'lax', maxAge: 300000 });

  const googleAuthUrl = `https://accounts.google.com/o/oauth2/v2/auth?` +
    `client_id=${encodeURIComponent(googleClientId)}` +
    `&redirect_uri=${encodeURIComponent(redirectUri)}` +
    `&response_type=code` +
    `&scope=openid%20profile%20email` +
    `&state=${encodeURIComponent(state)}`;

  console.log(`[Auth] Redirecting to Google OIDC: ${googleAuthUrl}`);
  res.redirect(googleAuthUrl);
});

// Token Exchange Endpoint
router.post('/exchange', async (req: Request, res: Response) => {
  const { code } = req.body;

  if (!code) {
    return res.status(400).json({ error: 'Authorization code is required' });
  }

  // Fallback / Mock login flow in development
  if (isMockMode || code === 'mock-code') {
    console.log('[Auth] Processing token exchange in mock mode.');
    const mockClaims = {
      "opendif-uid": mockUserEmail,
      "email": mockUserEmail,
      "name": "Nuwan Fernando"
    };
    const mockIdToken = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64') + '.' +
      Buffer.from(JSON.stringify(mockClaims)).toString('base64') + '.' +
      Buffer.from('mock-signature').toString('base64');

    return res.json({
      name: 'Nuwan Fernando',
      nic: mockUserEmail,
      sludiNumber: '3434 3434 3434',
      mobileNumber: '94712345678',
      email: mockUserEmail,
      authenticated: true,
      loginTime: new Date().toISOString(),
      token: 'mock-session-token',
      idToken: mockIdToken
    });
  }

  try {
    const host = req.get('host') || 'localhost:3000';
    const redirectUri = `${req.protocol}://${host}/login`;

    console.log(`[Auth] Exchanging code with Google for tokens. redirect_uri=${redirectUri}`);

    // Exchange authorization code for Google tokens
    const googleTokenRes = await axios.post(
      'https://oauth2.googleapis.com/token',
      new URLSearchParams({
        code,
        client_id: googleClientId,
        client_secret: googleClientSecret,
        redirect_uri: redirectUri,
        grant_type: 'authorization_code'
      }).toString(),
      {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
      }
    );

    const googleIdToken = googleTokenRes.data.id_token;
    if (!googleIdToken) {
      throw new Error('Google did not return an id_token');
    }

    console.log('[Auth] Successfully obtained Google ID Token. Performing token exchange with ThunderID...');

    // Exchange Google ID Token with ThunderID via RFC 8693 Token Exchange
    const credentials = Buffer.from(`${passportClientId}:${passportClientSecret}`).toString('base64');
    const rejectUnauthorized = process.env.NODE_ENV === 'production' ? true : (process.env.REJECT_UNAUTHORIZED !== 'false');
    const httpsAgent = new https.Agent({
      rejectUnauthorized
    });

    const thunderidRes = await axios.post(
      thunderidTokenUrl,
      new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:token-exchange',
        subject_token: googleIdToken,
        subject_token_type: 'urn:ietf:params:oauth:token-type:jwt',
        scope: 'openid profile email'
      }).toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': `Basic ${credentials}`
        },
        httpsAgent
      }
    );

    const accessToken = thunderidRes.data.access_token;
    console.log('[Auth] ThunderID Token Exchange successful.');

    // Retrieve user info to build user session
    // We parse the payload from Google's ID token or request user info
    const parts = googleIdToken.split('.');
    if (parts.length < 2) {
      throw new Error('Malformed Google ID token');
    }
    const tokenPayloadBase64 = parts[1];
    const userProfile = JSON.parse(Buffer.from(tokenPayloadBase64, 'base64').toString('utf8'));

    return res.json({
      name: userProfile.name || `${userProfile.given_name || ''} ${userProfile.family_name || ''}`.trim() || 'Google User',
      nic: userProfile.email,
      sludiNumber: '3434 3434 3434',
      mobileNumber: '94712345678',
      email: userProfile.email,
      authenticated: true,
      loginTime: new Date().toISOString(),
      token: accessToken,
      idToken: thunderidRes.data.id_token || googleIdToken
    });

  } catch (error: any) {
    console.error('[Auth] Token exchange error:', error.response?.data || error.message);
    res.status(500).json({
      error: 'Failed to authenticate user via Google and ThunderID OIDC'
    });
  }
});

// Mock Google OIDC Authorization Endpoint (for Consent Portal direct redirection)
router.get('/google-mock-auth', (req: Request, res: Response) => {
  const { redirect_uri, state } = req.query;
  if (!redirect_uri) {
    return res.status(400).send('redirect_uri is required');
  }
  console.log(`[Google Mock IDP] Redirecting client back to ThunderID callback with state=${state}`);
  res.redirect(`${redirect_uri}?code=mock-google-code&state=${state}`);
});

// Mock Google OIDC Token Endpoint (for ThunderID server-to-server exchange)
router.post('/google-mock-token', (req: Request, res: Response) => {
  console.log('[Google Mock IDP] Handling token exchange request.');
  const mockClaims = {
    iss: "https://accounts.google.com",
    sub: "mock-google-user",
    email: mockUserEmail,
    email_verified: true,
    name: "Nuwan Fernando",
    given_name: "Nuwan",
    family_name: "Fernando"
  };
  const mockIdToken = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64') + '.' +
    Buffer.from(JSON.stringify(mockClaims)).toString('base64') + '.' +
    Buffer.from('mock-signature').toString('base64');

  res.json({
    access_token: "mock-google-access-token",
    token_type: "Bearer",
    expires_in: 3600,
    id_token: mockIdToken
  });
});

export default router;
