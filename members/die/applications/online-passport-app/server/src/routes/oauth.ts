import { Router, Request, Response } from 'express';
import axios from 'axios';
import * as https from 'node:https';
import * as dotenv from 'dotenv';

dotenv.config();

const router = Router();

// The national SSO (IdP) token endpoint. The browser never talks to this
// directly; it posts to /api/auth/token and we forward here, injecting the
// confidential client's secret server-side.
const SSO_TOKEN_URL = process.env.SSO_TOKEN_URL || '';

// Trust self-signed certs only when explicitly enabled (self-hosted dev IdPs).
const httpsAgent =
  process.env.SSO_TLS_INSECURE === 'true'
    ? new https.Agent({ rejectUnauthorized: false })
    : undefined;

// Shorten a sensitive value for logging: keep enough to correlate, hide the rest.
const redact = (value?: string): string => {
  if (!value) return '(none)';
  return value.length <= 12 ? '***' : `${value.slice(0, 6)}…${value.slice(-4)}`;
};

/**
 * Backend-for-frontend token exchange.
 *
 * The SPA (oidc-client-ts / react-oidc-context) runs the authorization-code +
 * PKCE flow and would normally POST the code straight to the IdP's /token
 * endpoint. A confidential ("web application") client requires a client_secret
 * there, which must not ship in the browser bundle. So the SPA points its
 * token_endpoint at this route instead; we inject the secret server-side and
 * relay the IdP's response back unchanged (id_token, access_token, ...).
 * Handles both the initial authorization_code grant and refresh_token grants.
 */
router.post('/token', async (req: Request, res: Response) => {
  const grantType = req.body?.grant_type || 'unknown';
  const startedAt = Date.now();
  console.log(
    `[oauth] token exchange requested → grant_type=${grantType}` +
      ` code=${redact(req.body?.code)} refresh_token=${redact(req.body?.refresh_token)}` +
      ` redirect_uri=${req.body?.redirect_uri || '(none)'} client_id=${redact(req.body?.client_id)}`,
  );

  try {
    const params = new URLSearchParams();

    // Forward every field the client sent (grant_type, code, redirect_uri,
    // code_verifier, refresh_token, client_id, ...).
    for (const [key, value] of Object.entries(req.body ?? {})) {
      if (typeof value === 'string') {
        params.set(key, value);
      }
    }

    // Inject the confidential-client credentials server-side.
    const clientId = process.env.SSO_CLIENT_ID || (req.body?.client_id ?? '');
    params.set('client_id', clientId);
    params.set('client_secret', process.env.SSO_CLIENT_SECRET || '');

    if (!clientId || !process.env.SSO_CLIENT_SECRET) {
      console.warn(
        `[oauth] missing credentials → client_id set=${Boolean(clientId)}` +
          ` client_secret set=${Boolean(process.env.SSO_CLIENT_SECRET)}`,
      );
    }

    console.log(`[oauth] forwarding to SSO token endpoint: ${SSO_TOKEN_URL}`);
    const response = await axios.post(SSO_TOKEN_URL, params.toString(), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      httpsAgent,
    });

    const data = response.data ?? {};
    console.log(
      `[oauth] token exchange OK (${Date.now() - startedAt}ms) →` +
        ` status=${response.status} token_type=${data.token_type || '(none)'}` +
        ` expires_in=${data.expires_in ?? '(none)'} scope="${data.scope || ''}"` +
        ` id_token=${data.id_token ? 'present' : 'absent'}` +
        ` access_token=${data.access_token ? 'present' : 'absent'}` +
        ` refresh_token=${data.refresh_token ? 'present' : 'absent'}`,
    );

    res.json(response.data);
  } catch (error: any) {
    const status = error.response?.status || 500;
    console.error(
      `[oauth] token exchange FAILED (${Date.now() - startedAt}ms) → status=${status}`,
      error.response?.data || error.message,
    );
    res.status(status).json(error.response?.data || { error: 'token_exchange_failed' });
  }
});

export default router;