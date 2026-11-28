# Quick Start Guide

## One-Command Setup & Run

### Development Mode (Recommended for testing)

1. **Navigate to the project directory:**
   ```bash
   cd online-passport-app
   ```

2. **Run the app:**
   ```bash
   npm run dev
   ```

That's it! The application will start on:
- Frontend: http://localhost:5173
- Backend: http://localhost:3000

### Production Mode

1. **Build the application:**
   ```bash
   npm run build
   ```

2. **Start the production server:**
   ```bash
   npm start
   ```

The complete app will run on: http://localhost:3000

## Testing the Application

### Demo Login Credentials
- **FUDI Number:** `3434 3434 3434` (pre-filled)
- **OTP:** Any 6-digit number (e.g., `123456`)

### Demo Status Tracking
Search with:
- Application Number: `PA2024001234`
- OR NIC: `FL-4829105736`

## Common Issues

### Port Already in Use
If port 3000 or 5173 is already in use:
1. Stop the process using that port
2. Or change the port in:
   - Server: `server/.env` (PORT=3000)
   - Client: `client/vite.config.ts` (port: 5173)

### Module Not Found Errors
Run:
```bash
cd client && npm install --cache /tmp/.npm && cd ..
cd server && npm install --cache /tmp/.npm && cd ..
```

### Build Fails
Ensure you have:
- Node.js 18 or higher
- All dependencies installed
- TypeScript compiled without errors

## Architecture Overview

```
User Browser (localhost:5173 in dev, localhost:3000 in prod)
        ↓
React App (Vite dev server)
        ↓
Express Backend (localhost:3000)
        ↓
        ├─ Serves Built React App (in production)
        ├─ /api/graphql → NDX GraphQL API (with OAuth2 token)
        └─ /api/health → Health check
```

## Next Steps

- Read the full [README.md](./README.md) for detailed documentation
- Review [Application Flow](./README.md#application-flow)
- Check [Environment Variables](./README.md#environment-variables)
