# Online Passport Application System

A modern passport application system built with **React + Vite** for the frontend and **Express.js** for the backend. This is a rewrite of the `sri-lanka-passport` Next.js application with the same feature set.

## Features

✅ **Authentication with SLUDI** (Sri Lanka Unique Digital Identity)
✅ **8-Step Application Form** with validation
✅ **GraphQL Integration** for government data (NDX)
✅ **Payment Gateway** (GovPay) integration
✅ **Document Upload** functionality
✅ **Application Status Tracking**
✅ **Verifiable Credentials** (W3C standard)
✅ **Multi-language Support** structure (English, Sinhala, Tamil)
✅ **Responsive Design** with Tailwind CSS

## Tech Stack

### Frontend
- **React 18** - UI library
- **Vite** - Build tool and dev server
- **TypeScript** - Type safety
- **React Router** - Client-side routing
- **Tailwind CSS** - Styling
- **shadcn/ui** - UI components (built on Radix UI)
- **Apollo Client** - GraphQL client
- **Asgardeo** - Authentication (OAuth2/OIDC)
- **React Hook Form + Zod** - Form validation

### Backend
- **Express.js** - Web server
- **TypeScript** - Type safety
- **Axios** - HTTP client
- **GraphQL** - API integration
- **OAuth2** - Token management

## Project Structure

```
online-passport-app/
├── client/                 # React + Vite frontend
│   ├── src/
│   │   ├── components/     # Reusable components
│   │   │   ├── ui/        # shadcn/ui components
│   │   │   └── form-steps/ # Form step components
│   │   ├── pages/          # Page components (routes)
│   │   ├── lib/            # Utilities and configs
│   │   ├── hooks/          # Custom React hooks
│   │   ├── context/        # React contexts
│   │   └── types/          # TypeScript types
│   └── package.json
├── server/                 # Express.js backend
│   ├── src/
│   │   ├── routes/         # API route handlers
│   │   ├── middleware/     # Express middleware
│   │   └── index.ts        # Server entry point
│   └── package.json
├── package.json            # Root package (scripts)
└── README.md
```

## Getting Started

### Prerequisites

- Node.js 18+ and npm
- Git

### Installation

1. **Clone or navigate to the project:**
   ```bash
   cd online-passport-app
   ```

2. **Install dependencies for all packages:**
   ```bash
   # Install root dependencies
   npm install

   # Install client dependencies
   cd client && npm install --cache /tmp/.npm && cd ..

   # Install server dependencies
   cd server && npm install --cache /tmp/.npm && cd ..
   ```

### Development

Run both client and server with a single command:

```bash
npm run dev
```

This will start:
- **Frontend** on `http://localhost:5173` (Vite dev server)
- **Backend** on `http://localhost:3000` (Express server)

The frontend will proxy API requests to the backend, avoiding CORS issues.

### Production Build

1. **Build both client and server:**
   ```bash
   npm run build
   ```

2. **Start the production server:**
   ```bash
   npm start
   ```

The Express server will serve the built React app from `http://localhost:3000`.

### Individual Commands

- `npm run dev:client` - Run only the frontend dev server
- `npm run dev:server` - Run only the backend dev server
- `npm run build:client` - Build frontend for production
- `npm run build:server` - Build backend for production

## Environment Variables

### Client (`.env` in `client/`)
```env
VITE_API_URL=http://localhost:3000/api
VITE_ASGARDEO_BASE_URL=https://api.asgardeo.io/t/lankasoftwarefoundation
VITE_ASGARDEO_CLIENT_ID=Bt2BvJVTeJXSU5KAngNVe_mHnM0a
VITE_ASGARDEO_SCOPES=openid profile
```

### Server (`.env` in `server/`)
```env
PORT=3000
ASGARDEO_BASE_URL=https://api.asgardeo.io/t/lankasoftwarefoundation
ASGARDEO_CLIENT_ID=Bt2BvJVTeJXSU5KAngNVe_mHnM0a
TOKEN_URL=http://localhost:8090/oauth2/token
CLIENT_ID=passport-app
CLIENT_SECRET=1234
TOKEN_RESOURCE=http://api.openndx.local
TOKEN_SCOPE=getdata
ASGARDEO_SCOPES=openid profile
NDX_GRAPHQL_API_URL=http://localhost:9081/public/graphql
```

## Application Flow

1. **Home Page** - Landing page with hero section
2. **Login** - SLUDI authentication (NIC + OTP)
3. **Apply** - 8-step application form:
   - Service Selection
   - Photograph Upload
   - Personal Information (auto-filled from NDX)
   - Contact Information
   - Dual Citizenship Declaration
   - Document Upload
   - Declaration & Signature
   - Payment Summary
4. **GovPay** - Payment gateway (card, QR code, online banking)
5. **Success** - Application confirmation + Verifiable Credentials
6. **Status** - Track application progress

## API Endpoints

### Backend API Routes

- `GET /api/health` - Health check endpoint
- `POST /api/graphql` - GraphQL proxy (NDX data retrieval)

### GraphQL Queries

```graphql
query GetData {
  personInfo(nic: "199512345678") {
    name
    fullName
    otherNames
    profession
    address
    dateOfBirth
    sex
    birthInfo {
      birthRegistrationNumber
      district
      birthPlace
    }
  }
}
```

## Key Differences from Next.js Version

| Feature | Next.js Version | React + Vite Version |
|---------|----------------|----------------------|
| Routing | App Router | React Router v6 |
| Server | Next.js Server | Express.js |
| API Routes | `/app/api/` | `/server/src/routes/` |
| Auth Provider | Built-in | React Context |
| Build Tool | Next.js | Vite |
| Dev Server | `next dev` | `vite` + `nodemon` |
| CORS | Not needed | Handled by Express |

## Contributing

This application is part of the Farajaland OpenNDX initiative for digital government services.

## License

ISC
