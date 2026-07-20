import { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../components/ui/card";
import { Alert, AlertDescription } from "../components/ui/alert";
import { Loader2, Shield } from "lucide-react";

export default function Login() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const exchangeStarted = useRef(false);

  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const code = urlParams.get("code");
    const state = urlParams.get("state");

    if (code && !exchangeStarted.current) {
      exchangeStarted.current = true;
      setLoading(true);
      setError("");

      console.log("[Auth] Detected OIDC callback code. Triggering token exchange...");
      fetch("/api/auth/exchange", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ code, state }),
      })
        .then(async (res) => {
          if (!res.ok) {
            const errData = await res.json().catch(() => ({}));
            throw new Error(errData.error || "Authentication exchange failed");
          }
          return res.json();
        })
        .then((data) => {
          console.log("[Auth] Token exchange successful. Decoding ID token...");
          try {
            const tokenToDecode = data?.idToken || data?.token;
            const parts = tokenToDecode ? tokenToDecode.split(".") : [];
            if (parts.length >= 2) {
              const payloadBase64 = parts[1];
              const base64 = payloadBase64.replace(/-/g, "+").replace(/_/g, "/");
              const padded = base64.padEnd(base64.length + (4 - base64.length % 4) % 4, "=");
              const binaryString = atob(padded);
              const bytes = new Uint8Array(binaryString.length);
              for (let i = 0; i < binaryString.length; i++) {
                bytes[i] = binaryString.charCodeAt(i);
              }
              const decodedPayload = new TextDecoder().decode(bytes);
              const parsedToken = JSON.parse(decodedPayload);
              const openndxUserId = parsedToken["openndx-uid"] || parsedToken["openndx/userid"] || parsedToken.email || data.nic;

              const sessionData = {
                ...data,
                nic: openndxUserId
              };

              localStorage.setItem("sludi_user", JSON.stringify(sessionData));
            } else {
              localStorage.setItem("sludi_user", JSON.stringify(data));
            }
          } catch (decodeErr) {
            console.error("[Auth] Error parsing ID token claims:", decodeErr);
            localStorage.setItem("sludi_user", JSON.stringify(data));
          }
          window.dispatchEvent(new Event("auth-change"));
          setLoading(false);
          navigate("/apply");
        })
        .catch((err) => {
          console.error("[Auth] OIDC callback error:", err);
          setError(err.message || "Failed to exchange authorization token");
          setLoading(false);
        });
    }
  }, [navigate]);

  const handleGoogleLogin = () => {
    setLoading(true);
    window.location.href = "/api/auth/google";
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-cyan-50 to-blue-50 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <Card className="shadow-lg">
          <div className="pt-6 px-6">
            <div className="flex items-center justify-center mb-4">
              <Shield className="h-12 w-12 text-cyan-600 mr-3" />
              <div>
                <h1 className="text-2xl font-bold text-gray-900">SLUDI</h1>
                <p className="text-sm text-gray-600">Sri Lanka Unique Digital Identity</p>
              </div>
            </div>
          </div>
          <hr />

          <CardHeader className="text-center">
            <CardTitle className="text-xl">
              Citizen Authentication
            </CardTitle>
            <CardDescription>
              Log in to the Sri Lanka Digital Identity Platform
            </CardDescription>
          </CardHeader>

          <CardContent className="space-y-4">
            {error && (
              <Alert variant="destructive">
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            )}

            {loading ? (
              <div className="flex flex-col items-center justify-center py-6 space-y-3">
                <Loader2 className="h-8 w-8 animate-spin text-cyan-600" />
                <p className="text-sm text-gray-500 font-medium">Completing Authentication...</p>
              </div>
            ) : (
              <div className="py-4">
                <Button
                  onClick={handleGoogleLogin}
                  className="w-full flex items-center justify-center py-6 bg-white hover:bg-gray-50 text-gray-700 border border-gray-300 font-semibold shadow-sm transition duration-150 rounded-md"
                >
                  <svg className="h-5 w-5 mr-3" viewBox="0 0 24 24">
                    <path
                      fill="#EA4335"
                      d="M12 5.04c1.66 0 3.2.57 4.38 1.69l3.27-3.27C17.67 1.48 14.98 1 12 1 7.35 1 3.37 3.65 1.43 7.52l3.85 2.99C6.22 7.07 8.87 5.04 12 5.04z"
                    />
                    <path
                      fill="#4285F4"
                      d="M23.49 12.27c0-.81-.07-1.59-.2-2.34H12v4.44h6.45c-.28 1.47-1.11 2.71-2.36 3.55l3.65 2.83c2.14-1.97 3.38-4.88 3.38-8.48z"
                    />
                    <path
                      fill="#FBBC05"
                      d="M5.28 14.51c-.24-.72-.38-1.49-.38-2.27s.14-1.55.38-2.27L1.43 6.98C.6 8.64.1 10.51.1 12.5s.5 3.86 1.33 5.52l3.85-2.99z"
                    />
                    <path
                      fill="#34A853"
                      d="M12 23c3.24 0 5.97-1.07 7.96-2.91l-3.65-2.83c-1.1.74-2.5 1.18-4.31 1.18-3.13 0-5.78-2.03-6.72-4.97L1.43 16.48C3.37 20.35 7.35 23 12 23z"
                    />
                  </svg>
                  <span>Sign In with Google</span>
                </Button>
              </div>
            )}
          </CardContent>
        </Card>

        <div className="text-center mt-6 text-xs text-gray-500">
          <p>Powered by Department of Registrar of Persons</p>
          <p>Secured by SLUDI - Sri Lanka's Digital Identity Platform</p>
        </div>
      </div>
    </div>
  );
}
