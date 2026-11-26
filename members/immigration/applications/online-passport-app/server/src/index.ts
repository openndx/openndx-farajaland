import express, { Application, Request, Response } from 'express';
import cors from 'cors';
import path from 'path';
import * as dotenv from 'dotenv';
import graphqlRouter from './routes/graphql';

dotenv.config();

const app: Application = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// API Routes
app.use('/api', graphqlRouter);

// Health check endpoint
app.get('/api/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Serve static files from React build
const clientBuildPath = path.join(__dirname, '../../client/dist');
app.use(express.static(clientBuildPath));

// Handle React routing - send all non-API requests to index.html
app.use((req: Request, res: Response) => {
  res.sendFile(path.join(clientBuildPath, 'index.html'));
});

// Start server
app.listen(Number(PORT), '0.0.0.0', () => {
  console.log(`🚀 Server is running on http://localhost:${PORT}`);
  console.log(`📦 Serving React app from ${clientBuildPath}`);
  console.log(`🔌 API endpoints available at http://localhost:${PORT}/api`);
});

export default app;
