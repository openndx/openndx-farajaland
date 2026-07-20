# Local Development Guide — Google Federation

This guide explains how to set up and test the **Google Direct Federation** flow locally for both the **Online Passport App** and the **Consent Portal**.

## Prerequisites

- Docker and Docker Compose
- `jq` CLI tool (`brew install jq` on macOS)
- A Google Cloud project with OAuth 2.0 credentials

---

## 1. Create Google OAuth Credentials

1. Go to [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials)
2. Click **Create Credentials** → **OAuth Client ID**
3. Application type: **Web application**
4. Add the following **Authorized redirect URIs**:
   - `http://localhost:3000/login` (Passport App redirect URI)
   - `https://localhost:8090/commonauth` (ThunderID OIDC Callback URI)
5. Copy the **Client ID** and **Client Secret**

---

## 2. Configure Environment Variables

Edit `ndx/.env` and set the following values:

### Required — Google OAuth Credentials

```env
GOOGLE_CLIENT_ID=your-actual-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-your-actual-secret
```

### Required — Federated User Account Linking & Database Population

To test the full NDX flow (including querying birth records via GraphQL), you must link your Google account with a local user. Uncomment and fill in the `FED_USER_*` variables in `ndx/.env`:

```env
FED_USER_USERNAME=your-google-username
FED_USER_EMAIL=your-google-email@gmail.com
FED_USER_GIVEN_NAME=YourFirstName
FED_USER_FAMILY_NAME=YourLastName
```

> [!IMPORTANT]
> - **Email Matching:** The `FED_USER_EMAIL` must match the exact email of the Google account you will use to log in. This allows ThunderID to link the federated identity.
> - **Database Population:** The initialization scripts will automatically use this email address to register a user in ThunderID and populate the mock Birth Registry (`rgd-api`) database. This ensures that once logged in, you can successfully fetch citizen birth records using GraphQL under your account.

---

## 3. Run the Stack

```bash
./init.sh
```

This will:
1. Start all NDX infrastructure (ThunderID, PostgreSQL, API Gateway, etc.)
2. Configure the Google Identity Provider in ThunderID
3. Create the federated user (if `FED_USER_*` variables are set)
4. Start member services (Passport App, DRP, RGD, etc.)

### What init.sh Prints

At the end, you'll see a summary like:

```
[SUCCESS] Google Federation: Enabled ✓
[INFO]   Click 'Sign in with Google' on the Passport App to test
```

If you see `Google Federation: Not configured`, double-check your `GOOGLE_CLIENT_ID` in `ndx/.env`.

---

## 4. Test the Flow

### Passport App (http://localhost:3000)

1. Open http://localhost:3000
2. Click **Sign in with Google**
3. Authenticate with your Google account
4. The app exchanges your Google token with ThunderID for an NDX access token
5. You should see the passport application form

### Consent Portal (http://localhost:5173)

1. Open http://localhost:5173
2. Log in using the standard citizen credentials:
   - **Username:** `nayana`
   - **Password:** `Abc12#45`
3. Review and approve/reject consent requests initiated by the Passport App.

---

## Architecture Overview

```
┌─────────────┐     ┌──────────────┐     ┌────────────┐
│  Browser     │────▶│ Passport App │────▶│  Google    │
│             │◀────│ :3000        │◀────│  OAuth     │
└─────────────┘     └──────┬───────┘     └────────────┘
                           │ RFC 8693
                           │ Token Exchange
                           ▼
                    ┌──────────────┐
                    │  ThunderID   │
                    │  :8090       │
                    └──────────────┘
                           ▲
                           │ OIDC (Password Grant)
┌─────────────┐     ┌──────┴───────┐
│  Browser     │────▶│ Consent      │
│             │◀────│ Portal :5173 │
└─────────────┘     └──────────────┘
```

**Passport App flow:** The app handles Google OAuth directly, then exchanges the Google `id_token` with ThunderID via [RFC 8693 Token Exchange](https://datatracker.ietf.org/doc/html/rfc8693).

**Consent Portal flow:** The portal uses ThunderID's standard authentication with citizen username/password (nayana/Abc12#45).

---

## Key Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `GOOGLE_CLIENT_ID` | _(must set)_ | Google OAuth Client ID |
| `GOOGLE_CLIENT_SECRET` | _(must set)_ | Google OAuth Client Secret |
| `FED_USER_USERNAME` | _(optional)_ | Username for the federated test user |
| `FED_USER_EMAIL` | _(optional)_ | Email for the federated test user (must match Google account) |
| `FED_USER_GIVEN_NAME` | _(optional)_ | First name for the federated test user |
| `FED_USER_FAMILY_NAME` | _(optional)_ | Last name for the federated test user |
| `IDP_BROWSER_URL` | `https://localhost:8090` | Browser-accessible ThunderID URL |
| `IDP_BASE_URL` | `https://thunderid:8090` | Internal Docker ThunderID URL |
| `PASSPORT_CLIENT_SECRET` | `1234` | Shared secret between Passport App and ThunderID |
| `APP_BASE_URL` | `http://localhost:3000` | Passport App base URL for OAuth redirects |
| `CLEAN_START` | `true` | Set to `false` to preserve data between runs |

---

## Troubleshooting

### "Failed to authenticate user via Google and ThunderID OIDC" (500 error)

- Check that `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are set correctly in `ndx/.env`
- Verify the redirect URI `http://localhost:3000/login` is listed in Google Cloud Console
- Check container logs: `docker logs online-passport-app`

### Google redirects to wrong URL

- Ensure `IDP_BROWSER_URL=https://localhost:8090` in `ndx/.env` (not `thunderid:8090`)
- Ensure `https://localhost:8090/commonauth` is listed in Google's authorized redirect URIs

### Federated user not created

- Ensure `FED_USER_USERNAME` and `FED_USER_EMAIL` are uncommented in `ndx/.env`
- Check that values are not the default placeholders
- Run with `CLEAN_START=true` (default) to recreate from scratch

### Consent Portal can't reach ThunderID

- ThunderID must be accessible at `https://localhost:8090` from the browser
- Accept the self-signed certificate by visiting https://localhost:8090 directly
