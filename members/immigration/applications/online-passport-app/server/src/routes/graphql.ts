import { Router, Request, Response } from 'express';
import axios from 'axios';
import { tokenManager } from '../middleware/auth';

const router = Router();

router.post('/graphql', async (req: Request, res: Response) => {
  try {
    const { query, variables } = req.body;

    // Get OAuth2 token
    const token = await tokenManager.getToken();

    // Forward GraphQL request to the backend API
    const response = await axios.post(
      process.env.NDX_GRAPHQL_API_URL || '',
      {
        query,
        variables
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
      }
    );

    res.json(response.data);
  } catch (error: any) {
    console.error('GraphQL proxy error:', error.response?.data || error.message);

    res.status(error.response?.status || 500).json({
      errors: [{
        message: error.response?.data?.errors?.[0]?.message || 'GraphQL request failed',
        extensions: {
          code: error.response?.data?.errors?.[0]?.extensions?.code || 'INTERNAL_SERVER_ERROR'
        }
      }]
    });
  }
});

export default router;
