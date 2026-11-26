import { ApolloClient, InMemoryCache, HttpLink } from "@apollo/client";

// Use relative /api path by default (same server)
// Can override with VITE_API_URL environment variable if needed
const apiUrl = import.meta.env.VITE_API_URL || "/api";

const client = new ApolloClient({
  link: new HttpLink({
    uri: `${apiUrl}/graphql`
  }),
  cache: new InMemoryCache(),
});

export default client;