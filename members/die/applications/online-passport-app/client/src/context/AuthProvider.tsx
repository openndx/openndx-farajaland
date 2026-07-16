import { AuthProvider as OidcAuthProvider } from 'react-oidc-context';
import type { AuthProviderProps as OidcAuthProviderProps } from 'react-oidc-context';
import { WebStorageStateStore } from 'oidc-client-ts';
import React, { useEffect, useState } from 'react';

const authority = import.meta.env.VITE_OIDC_AUTHORITY || '';
const clientId = import.meta.env.VITE_OIDC_CLIENT_ID || '';
const scope = import.meta.env.VITE_OIDC_SCOPE || 'openid profile email';
// Backend token-proxy endpoint. We're a confidential client, so the
// authorization-code exchange is routed through the passport backend (which
// injects the client_secret) instead of hitting the provider's /token directly.
const tokenEndpoint = import.meta.env.VITE_OIDC_TOKEN_ENDPOINT || '';

// Strip the ?code=…&state=… (and error) params after the redirect callback so
// they don't linger in the address bar or get replayed on refresh.
const onSigninCallback: OidcAuthProviderProps['onSigninCallback'] = () => {
  window.history.replaceState({}, document.title, window.location.pathname);
};

interface AuthProviderProps {
  children: React.ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  // authorize/jwks are discovered normally from the provider; only the
  // token_endpoint is overridden to point at our backend proxy. oidc-client-ts
  // lets fetched discovery win over `metadataSeed`, so we fetch the discovery
  // document ourselves and hand back full `metadata` with the token endpoint
  // swapped out.
  const [config, setConfig] = useState<OidcAuthProviderProps | null>(null);

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      let metadata: Record<string, unknown> | undefined;

      if (tokenEndpoint) {
        try {
          const res = await fetch(
            `${authority.replace(/\/$/, '')}/.well-known/openid-configuration`,
          );
          if (res.ok) {
            metadata = { ...(await res.json()), token_endpoint: tokenEndpoint };
          } else {
            console.error('Failed to load OIDC discovery document:', res.status);
          }
        } catch (error) {
          console.error('Failed to load OIDC discovery document:', error);
        }
      }

      if (cancelled) return;

      setConfig({
        authority,
        client_id: clientId,
        redirect_uri: window.location.origin,
        post_logout_redirect_uri: window.location.origin,
        scope,
        response_type: 'code',
        // Keep sessions across reloads instead of the default in-memory store.
        userStore: new WebStorageStateStore({ store: window.localStorage }),
        automaticSilentRenew: true,
        ...(metadata ? { metadata } : {}),
        onSigninCallback,
      });
    };

    void load();

    return () => {
      cancelled = true;
    };
  }, []);

  if (!config) return null;

  return <OidcAuthProvider {...config}>{children}</OidcAuthProvider>;
};