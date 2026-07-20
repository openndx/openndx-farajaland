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
const tokenExchangeAudience = process.env.TOKEN_EXCHANGE_AUDIENCE || 'ndx-api-gateway';

if (!googleClientId || !googleClientSecret || !passportClientId || !passportClientSecret) {
  console.warn('[Auth] Missing required OAuth environment variables. Authentication flows may fail.');
}

// Google Auth Redirect Initiation
router.get('/google', (req: Request, res: Response) => {
  const appBaseUrl = process.env.APP_BASE_URL || `${req.protocol}://${req.get('host') || 'localhost:3000'}`;
  const redirectUri = `${appBaseUrl}/login`;

  const state = crypto.randomBytes(16).toString('hex');
  res.cookie('oauth_state', state, {
    httpOnly: true,
    sameSite: 'lax',
    maxAge: 300000,
    secure: process.env.NODE_ENV === 'production' || req.secure
  });

  const googleAuthUrl = `https://accounts.google.com/o/oauth2/v2/auth?` +
    `client_id=${encodeURIComponent(googleClientId)}` +
    `&redirect_uri=${encodeURIComponent(redirectUri)}` +
    `&response_type=code` +
    `&scope=openid%20profile%20email` +
    `&state=${encodeURIComponent(state)}`;

  res.redirect(googleAuthUrl);
});

// Token Exchange Endpoint — exchanges a Google authorization code for a
// ThunderID access token via RFC 8693 token exchange.
router.post('/exchange', async (req: Request, res: Response) => {
  const { code, state } = req.body;
  const cookieState = req.cookies?.oauth_state;

  if (!state || !cookieState || state !== cookieState) {
    return res.status(400).json({ error: 'State mismatch. Possible CSRF attack.' });
  }

  res.clearCookie('oauth_state', {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production' || req.secure
  });

  if (!code) {
    return res.status(400).json({ error: 'Authorization code is required' });
  }

  try {
    const appBaseUrl = process.env.APP_BASE_URL || `${req.protocol}://${req.get('host') || 'localhost:3000'}`;
    const redirectUri = `${appBaseUrl}/login`;

    // Step 1: Exchange authorization code for Google tokens
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

    // Step 2: Exchange Google ID Token with ThunderID via RFC 8693 Token Exchange
    const credentials = Buffer.from(`${passportClientId}:${passportClientSecret}`).toString('base64');
    let isLocal = false;
    try {
      const hostname = new URL(thunderidTokenUrl).hostname;
      isLocal = hostname === 'localhost' || hostname === '127.0.0.1' || hostname === 'thunderid';
    } catch {
      // Fallback if URL parsing fails
    }
    const rejectUnauthorized = process.env.REJECT_UNAUTHORIZED === 'false' ? false : !isLocal;
    const httpsAgent = new https.Agent({ rejectUnauthorized });

    const thunderidRes = await axios.post(
      thunderidTokenUrl,
      new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:token-exchange',
        subject_token: googleIdToken,
        subject_token_type: 'urn:ietf:params:oauth:token-type:id_token',
        client_id: passportClientId,
        audience: tokenExchangeAudience
      }).toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': `Basic ${credentials}`
        },
        httpsAgent
      }
    );

    const accessToken = thunderidRes.data?.access_token;
    if (!accessToken) {
      throw new Error('ThunderID did not return an access_token');
    }

    // Step 3: Parse user profile from the Google ID token claims
    const parts = googleIdToken.split('.');
    if (parts.length < 2) {
      throw new Error('Malformed Google ID token');
    }
    const userProfile = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));

    if (!userProfile?.email) {
      throw new Error('Google ID token is missing the required email claim');
    }

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
    console.error('[Auth] Token exchange failed:', error.response?.data || error.message);
    res.status(500).json({
      error: 'Failed to authenticate user via Google and ThunderID OIDC'
    });
  }
});

export default router;
