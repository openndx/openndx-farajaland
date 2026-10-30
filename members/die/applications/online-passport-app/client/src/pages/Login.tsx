import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "../components/ui/button";
import { Input } from "../components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../components/ui/card";
import { Label } from "../components/ui/label";
import { Alert, AlertDescription } from "../components/ui/alert";
import { Loader2, Shield } from "lucide-react";

export default function Login() {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({
    sludiNumber: "3434 3434 3434",
    otp: "232323",
  });
  const [step, setStep] = useState<"sludiNumber" | "otp">("sludiNumber");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleNICSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.sludiNumber || formData.sludiNumber.length < 9) {
      setError("Please enter a valid NIC number");
      return;
    }

    setLoading(true);
    setError("");

    setTimeout(() => {
      setLoading(false);
      setStep("otp");
    }, 2000);
  };

  const handleOTPSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.otp || formData.otp.length !== 6) {
      setError("Please enter a valid 6-digit OTP");
      return;
    }

    setLoading(true);
    setError("");

    setTimeout(() => {
      // Store user session
      localStorage.setItem(
        "sludi_user",
        JSON.stringify({
          name: "Suresh Fernando",
          nic: "suresh@ndx.fl",
          sludiNumber: formData.sludiNumber,
          mobileNumber: "94712345678",
          email: "suresh@ndx.fl",
          authenticated: true,
          loginTime: new Date().toISOString(),
        }),
      );

      setLoading(false);
      navigate("/apply");
    }, 1500);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-cyan-50 to-blue-50 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <Card className="shadow-lg">
          <div className="">
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
              {step === "sludiNumber" && "Login with SLUDI"}
              {step === "otp" && "Verify OTP"}
            </CardTitle>
            <CardDescription>
              {step === "sludiNumber" && "Enter your SLUDI Number"}
              {step === "otp" && `OTP sent to mobile number registered with SLUDI ${formData.sludiNumber}`}
            </CardDescription>
          </CardHeader>

          <CardContent className="space-y-4">
            {error && (
              <Alert variant="destructive">
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            )}

            {step === "sludiNumber" && (
              <form onSubmit={handleNICSubmit} className="space-y-4">
                <div>
                  <Label htmlFor="sludiNumber">SLUDI Number</Label>
                  <Input
                    id="sludiNumber"
                    type="text"
                    placeholder="xxxx xxxx xxxx"
                    value={formData.sludiNumber}
                    onChange={(e) => setFormData({ ...formData, sludiNumber: e.target.value })}
                    className="mt-1"
                    maxLength={12}
                  />
                </div>
                <Button type="submit" className="w-full" disabled={loading}>
                  {loading ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      Verifying SLUDI...
                    </>
                  ) : (
                    "Continue"
                  )}
                </Button>
              </form>
            )}

            {step === "otp" && (
              <form onSubmit={handleOTPSubmit} className="space-y-4">
                <div>
                  <Label htmlFor="otp">Enter OTP</Label>
                  <Input
                    id="otp"
                    type="text"
                    placeholder="Enter 6-digit OTP"
                    value={formData.otp}
                    onChange={(e) => setFormData({ ...formData, otp: e.target.value.replace(/\D/g, "") })}
                    className="mt-1 text-center text-lg tracking-widest"
                    maxLength={6}
                  />
                  <p className="text-xs text-gray-500 mt-1">Check your registered mobile number for OTP</p>
                </div>
                <Button type="submit" className="w-full" disabled={loading}>
                  {loading ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      Completing Authentication...
                    </>
                  ) : (
                    "Complete Login"
                  )}
                </Button>
                <Button
                  type="button"
                  variant="outline"
                  className="w-full bg-transparent"
                  onClick={() => setStep("sludiNumber")}
                >
                  Back to SLUDI Entry
                </Button>
              </form>
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
