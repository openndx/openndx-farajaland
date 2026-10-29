import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";
import { RadioGroup, RadioGroupItem } from "../components/ui/radio-group";
import { ArrowLeft, Shield, CreditCard, Building, QrCode } from "lucide-react";

export default function GovPay() {
  const navigate = useNavigate();
  const [applicationData, setApplicationData] = useState<any>(null);
  const [paymentMethod, setPaymentMethod] = useState("card");
  const [processing, setProcessing] = useState(false);

  useEffect(() => {
    const pendingApp = localStorage.getItem("pending_application");
    if (pendingApp) {
      setApplicationData(JSON.parse(pendingApp));
    } else {
      navigate("/apply");
    }
  }, [navigate]);

  const handlePayment = async () => {
    setProcessing(true)

    // Simulate payment processing
    setTimeout(() => {
      // Mark payment as completed
      const completedApplication = {
        ...applicationData,
        paymentStatus: "completed",
        paymentMethod: paymentMethod,
        transactionId: `TXN${Date.now()}`,
        paymentDate: new Date().toISOString(),
      }

      localStorage.setItem("submitted_application", JSON.stringify(completedApplication))
      localStorage.removeItem("pending_application")

      navigate("/success");
    }, 3000)
  }

  if (!applicationData) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading payment details...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-blue-100">
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <div className="flex items-center gap-4">
            <Button
              variant="outline"
              size="sm"
              onClick={() => navigate("/apply")}
              className="flex items-center gap-2"
            >
              <ArrowLeft className="h-4 w-4" />
              Back to Application
            </Button>
            <div className="ml-8">
              <div className="flex flex-col">
                <h2 className="text-2xl font-bold">GovPay</h2>
                <span className="text-sm text-gray-600">Secure & Convenient Payments for Government Services</span>
              </div>
            </div>
          </div>
          <div className="flex items-center gap-2 text-green-600">
            <Shield className="h-5 w-5" />
            <span className="text-sm font-medium">Secure Payment</span>
          </div>
        </div>

        <div className="max-w-2xl mx-auto space-y-6">
          {/* Payment Summary */}
          <Card>
            <CardHeader>
              <CardTitle>Payment Summary</CardTitle>
              <CardDescription>Sri Lankan Passport Application</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span>Applicant:</span>
                  <span className="font-medium">{applicationData.fullName}</span>
                </div>
                <div className="flex justify-between">
                  <span>Service Type:</span>
                  <span className="font-medium">
                    {applicationData.serviceType === "oneday" ? "One Day Service" : "Normal Processing"}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span>Document Type:</span>
                  <span className="font-medium">
                    {applicationData.documentType === "all-countries" ? "All Countries" : "Middle East Countries"}
                  </span>
                </div>
                <div className="border-t pt-3 flex justify-between text-lg font-bold">
                  <span>Total Amount:</span>
                  <span className="text-blue-600">LKR {applicationData.totalAmount}</span>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Payment Methods */}
          <Card>
            <CardHeader>
              <CardTitle>Select Payment Method</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <RadioGroup value={paymentMethod} onValueChange={setPaymentMethod}>
                <div className="flex items-center space-x-2 p-4 border rounded-lg hover:bg-gray-50">
                  <RadioGroupItem value="card" id="card-method" />
                  <CreditCard className="h-5 w-5 text-blue-600" />
                  <div>
                    <Label htmlFor="card-method" className="font-medium">
                      Credit/Debit Card
                    </Label>
                    <p className="text-sm text-muted-foreground">Visa, MasterCard, American Express</p>
                  </div>
                </div>

                <div className="flex items-center space-x-2 p-4 border rounded-lg hover:bg-gray-50">
                  <RadioGroupItem value="qr" id="qr-method" />
                  <QrCode className="h-5 w-5 text-green-600" />
                  <div>
                    <Label htmlFor="qr-method" className="font-medium">
                      QR Code Payment
                    </Label>
                    <p className="text-sm text-muted-foreground">Scan and pay with mobile banking apps</p>
                  </div>
                </div>

                <div className="flex items-center space-x-2 p-4 border rounded-lg hover:bg-gray-50">
                  <RadioGroupItem value="bank" id="bank-method" />
                  <Building className="h-5 w-5 text-purple-600" />
                  <div>
                    <Label htmlFor="bank-method" className="font-medium">
                      Online Banking
                    </Label>
                    <p className="text-sm text-muted-foreground">Direct bank transfer</p>
                  </div>
                </div>
              </RadioGroup>

              {/* Payment Forms */}
              {paymentMethod === "card" && (
                <div className="space-y-4 p-4 bg-gray-50 rounded-lg">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <Label htmlFor="card-number">Card Number</Label>
                      <Input id="card-number" placeholder="1234 5678 9012 3456" />
                    </div>
                    <div>
                      <Label htmlFor="card-name">Cardholder Name</Label>
                      <Input id="card-name" />
                    </div>
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <Label htmlFor="expiry">Expiry Date</Label>
                      <Input id="expiry" placeholder="MM/YY" />
                    </div>
                    <div>
                      <Label htmlFor="cvv">CVV</Label>
                      <Input id="cvv" placeholder="123" />
                    </div>
                  </div>
                </div>
              )}

              {paymentMethod === "qr" && (
                <div className="text-center p-6 bg-gray-50 rounded-lg">
                  <div className="w-48 h-48 bg-white border-2 border-gray-300 rounded-lg mx-auto mb-4 flex items-center justify-center">
                    <img src="/qr-code-payment.png" alt="QR Code for Payment" className="w-40 h-40" />
                  </div>
                  <p className="text-sm text-gray-600 mb-2">Scan this QR code with your mobile banking app</p>
                  <p className="text-xs text-gray-500">Amount: LKR {applicationData.totalAmount}</p>
                </div>
              )}

              {paymentMethod === "bank" && (
                <div className="space-y-4 p-4 bg-gray-50 rounded-lg">
                  <div>
                    <Label htmlFor="bank-select">Select Your Bank</Label>
                    <select className="w-full p-2 border rounded-md">
                      <option>National Bank</option>
                      <option>People's Trust Bank</option>
                      <option>Commercial Bank</option>
                      <option>Central Bank</option>
                      <option>Citizen Bank</option>
                    </select>
                  </div>
                </div>
              )}

              <Button
                onClick={handlePayment}
                disabled={processing}
                className="w-full bg-green-600 hover:bg-green-700 text-white py-3"
                size="lg"
              >
                {processing ? (
                  <div className="flex items-center gap-2">
                    <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                    Processing Payment...
                  </div>
                ) : (
                  `Pay LKR ${applicationData.totalAmount}`
                )}
              </Button>
            </CardContent>
          </Card>

          {/* Security Notice */}
          <div className="text-center text-sm text-gray-600">
            <div className="flex items-center justify-center gap-2 mb-2">
              <Shield className="h-4 w-4" />
              <span>Your payment is secured by 256-bit SSL encryption</span>
            </div>
            <p>This is a secure government payment gateway operated by the ministry of digital economy (Powered By ICTA)</p>
          </div>
        </div>
      </div>
    </div>
  )
}
