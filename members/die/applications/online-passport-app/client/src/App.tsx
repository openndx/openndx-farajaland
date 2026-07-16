import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import apolloClient from './lib/apollo-client';
import { AuthProvider } from './context/AuthProvider';
import { Toaster } from './components/ui/toaster';
import Home from './pages/Home';
import Apply from './pages/Apply';
import Status from './pages/Status';
import Success from './pages/Success';
import GovPay from './pages/GovPay';
import {ApolloProvider} from "@apollo/client/react";

function App() {
  return (
    <ApolloProvider client={apolloClient}>
      <AuthProvider>
        <Router>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/apply" element={<Apply />} />
            <Route path="/status" element={<Status />} />
            <Route path="/success" element={<Success />} />
            <Route path="/govpay" element={<GovPay />} />
          </Routes>
          <Toaster />
        </Router>
      </AuthProvider>
    </ApolloProvider>
  );
}

export default App;
