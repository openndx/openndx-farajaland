import axios from 'axios';
import * as dotenv from 'dotenv';

dotenv.config();

interface TokenResponse {
  access_token: string;
  expires_in: number;
  token_type: string;
}

class TokenManager {
  private token: string | null = null;
  private tokenExpiry: number = 0;
  private readonly tokenUrl: string;
  private readonly clientId: string;
  private readonly clientSecret: string;
  private readonly tokenResource: string;
  private readonly tokenScope: string;
  private readonly refreshBuffer = 30000; // 30 seconds before expiry

  constructor() {
    this.tokenUrl = process.env.TOKEN_URL || '';
    this.clientId = process.env.CLIENT_ID || '';
    this.clientSecret = process.env.CLIENT_SECRET || '';
    this.tokenResource = process.env.TOKEN_RESOURCE || 'http://api.openndx.local';
    this.tokenScope = process.env.TOKEN_SCOPE || 'getdata';
  }

  async getToken(): Promise<string> {
    const now = Date.now();

    // Return cached token if still valid
    if (this.token && now < this.tokenExpiry - this.refreshBuffer) {
      return this.token;
    }

    // Fetch new token
    try {
      const credentials = Buffer.from(`${this.clientId}:${this.clientSecret}`).toString('base64');

      const response = await axios.post<TokenResponse>(
        this.tokenUrl,
        new URLSearchParams({
          grant_type: 'client_credentials',
          resource: this.tokenResource,
          scope: this.tokenScope,
        }).toString(),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': `Basic ${credentials}`
          }
        },
      );

      this.token = response.data.access_token;
      this.tokenExpiry = now + (response.data.expires_in * 1000);

      return this.token;
    } catch (error) {
      console.error('Error fetching token:', error);
      throw new Error('Failed to authenticate with OAuth2 provider');
    }
  }

  clearToken(): void {
    this.token = null;
    this.tokenExpiry = 0;
  }
}

export const tokenManager = new TokenManager();
