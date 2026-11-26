"use client"

import { useState } from "react"
import { useMultiStepForm } from "@/components/multi-step-form"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"
import { Label } from "@/components/ui/label"
import { FormFieldWrapper } from "@/components/form-field-wrapper"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import { CreditCard, Building, Smartphone, Shield, CheckCircle } from "lucide-react"
import { CURRENCY } from "@/lib/utils"

interface PaymentData {
  paymentMethod: string
  cardNumber: string
  expiryMonth: string
  expiryYear: string
  cvv: string
  cardholderName: string
  bankName: string
  accountNumber: string
  mobileNumber: string
}

export function PaymentStep() {
  const { updateFormData, formData } = useMultiStepForm()
  const [paymentData, setPaymentData] = useState<PaymentData>({
    paymentMethod: "",
    cardNumber: "",
    expiryMonth: "",
    expiryYear: "",
    cvv: "",
    cardholderName: "",
    bankName: "",
    accountNumber: "",
    mobileNumber: "",
    ...formData["payment"],
  })

  const [isProcessing, setIsProcessing] = useState(false)
  const [paymentComplete, setPaymentComplete] = useState(false)

  // Calculate fees based on service type
  const calculateFees = () => {
    const serviceType = formData["service-type"]?.serviceType || "normal"
    const travelDocument = formData["service-type"]?.travelDocument || "all-countries"

    let baseFee = 0
    let processingFee = 0

    // Base fees by document type
    switch (travelDocument) {
      case "all-countries":
        baseFee = 3500
        break
      case "emergency":
        baseFee = 7500
        break
      case "identity":
        baseFee = 1500
        break
      default:
        baseFee = 3500
    }

    // Processing fees
    if (serviceType === "oneday") {
      processingFee = 5000
    }

    const serviceFee = 250 // Government service fee
    const total = baseFee + processingFee + serviceFee

    return { baseFee, processingFee, serviceFee, total }
  }

  const fees = calculateFees()

  const handleInputChange = (field: keyof PaymentData, value: string) => {
    const newData = { ...paymentData, [field]: value }
    setPaymentData(newData)
    updateFormData("payment", newData)
  }

  const formatCardNumber = (value: string) => {
    const v = value.replace(/\s+/g, "").replace(/[^0-9]/gi, "")
    const matches = v.match(/\d{4,16}/g)
    const match = (matches && matches[0]) || ""
    const parts = []
    for (let i = 0, len = match.length; i < len; i += 4) {
      parts.push(match.substring(i, i + 4))
    }
    if (parts.length) {
      return parts.join(" ")
    } else {
      return v
    }
  }

  const handleCardNumberChange = (value: string) => {
    const formatted = formatCardNumber(value)
    handleInputChange("cardNumber", formatted)
  }

  const processPayment = async () => {
    setIsProcessing(true)

    // Simulate payment processing
    await new Promise((resolve) => setTimeout(resolve, 3000))

    setIsProcessing(false)
    setPaymentComplete(true)

    // Update form data with payment confirmation
    updateFormData("payment", {
      ...paymentData,
      paymentStatus: "completed",
      transactionId: `TXN${Date.now()}`,
      paymentDate: new Date().toISOString(),
      amount: fees.total,
    })
  }

  const getCardType = (number: string) => {
    const num = number.replace(/\s/g, "")
    if (num.startsWith("4")) return "Visa"
    if (num.startsWith("5") || num.startsWith("2")) return "Mastercard"
    if (num.startsWith("3")) return "American Express"
    return "Card"
  }

  return (
    <div className="space-y-8">
      {/* Fee Breakdown */}
      <Card className="bg-blue-50 border-blue-200">
        <CardHeader>
          <CardTitle className="text-blue-900">Payment Summary</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-3">
            <div className="flex justify-between">
              <span className="text-blue-800">Passport Fee</span>
              <span className="font-medium">{CURRENCY} {fees.baseFee.toLocaleString()}</span>
            </div>
            {fees.processingFee > 0 && (
              <div className="flex justify-between">
                <span className="text-blue-800">Express Processing Fee</span>
                <span className="font-medium">{CURRENCY} {fees.processingFee.toLocaleString()}</span>
              </div>
            )}
            <div className="flex justify-between">
              <span className="text-blue-800">Service Fee</span>
              <span className="font-medium">{CURRENCY} {fees.serviceFee.toLocaleString()}</span>
            </div>
            <Separator />
            <div className="flex justify-between text-lg font-semibold">
              <span className="text-blue-900">Total Amount</span>
              <span className="text-blue-900">{CURRENCY} {fees.total.toLocaleString()}</span>
            </div>
          </div>
        </CardContent>
      </Card>

      {!paymentComplete ? (
        <>
          {/* Payment Method Selection */}
          <Card>
            <CardHeader>
              <CardTitle>Select Payment Method</CardTitle>
            </CardHeader>
            <CardContent>
              <RadioGroup
                value={paymentData.paymentMethod}
                onValueChange={(value) => handleInputChange("paymentMethod", value)}
                className="space-y-4"
              >
                <div className="flex items-center space-x-3 p-4 border rounded-lg hover:bg-gray-50">
                  <RadioGroupItem value="card" id="card" />
                  <CreditCard className="h-5 w-5 text-primary" />
                  <div>
                    <Label htmlFor="card" className="font-medium">
                      Credit/Debit Card
                    </Label>
                    <p className="text-xs text-muted-foreground">Visa, Mastercard, American Express</p>
                  </div>
                </div>
                <div className="flex items-center space-x-3 p-4 border rounded-lg hover:bg-gray-50">
                  <RadioGroupItem value="bank" id="bank" />
                  <Building className="h-5 w-5 text-primary" />
                  <div>
                    <Label htmlFor="bank" className="font-medium">
                      Online Banking
                    </Label>
                    <p className="text-xs text-muted-foreground">Direct bank transfer</p>
                  </div>
                </div>
                <div className="flex items-center space-x-3 p-4 border rounded-lg hover:bg-gray-50">
                  <RadioGroupItem value="mobile" id="mobile" />
                  <Smartphone className="h-5 w-5 text-primary" />
                  <div>
                    <Label htmlFor="mobile" className="font-medium">
                      Mobile Payment
                    </Label>
                    <p className="text-xs text-muted-foreground">eZ Cash, mCash, Dialog Pay</p>
                  </div>
                </div>
              </RadioGroup>
            </CardContent>
          </Card>

          {/* Payment Details */}
          {paymentData.paymentMethod === "card" && (
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center">
                  <Shield className="h-5 w-5 mr-2" />
                  Card Details
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <FormFieldWrapper label="Cardholder Name" required>
                  <Input
                    placeholder="Enter name as shown on card"
                    value={paymentData.cardholderName}
                    onChange={(e) => handleInputChange("cardholderName", e.target.value)}
                  />
                </FormFieldWrapper>

                <FormFieldWrapper label="Card Number" required>
                  <div className="relative">
                    <Input
                      placeholder="1234 5678 9012 3456"
                      value={paymentData.cardNumber}
                      onChange={(e) => handleCardNumberChange(e.target.value)}
                      maxLength={19}
                    />
                    {paymentData.cardNumber && (
                      <Badge variant="outline" className="absolute right-2 top-2 text-xs">
                        {getCardType(paymentData.cardNumber)}
                      </Badge>
                    )}
                  </div>
                </FormFieldWrapper>

                <div className="grid grid-cols-3 gap-4">
                  <FormFieldWrapper label="Expiry Month" required>
                    <Select
                      value={paymentData.expiryMonth}
                      onValueChange={(value) => handleInputChange("expiryMonth", value)}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="MM" />
                      </SelectTrigger>
                      <SelectContent>
                        {Array.from({ length: 12 }, (_, i) => (
                          <SelectItem key={i + 1} value={String(i + 1).padStart(2, "0")}>
                            {String(i + 1).padStart(2, "0")}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </FormFieldWrapper>

                  <FormFieldWrapper label="Expiry Year" required>
                    <Select
                      value={paymentData.expiryYear}
                      onValueChange={(value) => handleInputChange("expiryYear", value)}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="YYYY" />
                      </SelectTrigger>
                      <SelectContent>
                        {Array.from({ length: 10 }, (_, i) => {
                          const year = new Date().getFullYear() + i
                          return (
                            <SelectItem key={year} value={String(year)}>
                              {year}
                            </SelectItem>
                          )
                        })}
                      </SelectContent>
                    </Select>
                  </FormFieldWrapper>

                  <FormFieldWrapper label="CVV" required>
                    <Input
                      placeholder="123"
                      value={paymentData.cvv}
                      onChange={(e) => handleInputChange("cvv", e.target.value.replace(/\D/g, "").slice(0, 4))}
                      maxLength={4}
                    />
                  </FormFieldWrapper>
                </div>
              </CardContent>
            </Card>
          )}

          {paymentData.paymentMethod === "bank" && (
            <Card>
              <CardHeader>
                <CardTitle>Bank Transfer Details</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <FormFieldWrapper label="Bank Name" required>
                  <Select value={paymentData.bankName} onValueChange={(value) => handleInputChange("bankName", value)}>
                    <SelectTrigger>
                      <SelectValue placeholder="Select your bank" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="national">National Bank</SelectItem>
                      <SelectItem value="peoples-trust">People's Trust Bank</SelectItem>
                      <SelectItem value="commercial">Commercial Bank</SelectItem>
                      <SelectItem value="central">Central Bank</SelectItem>
                      <SelectItem value="citizen">Citizen Bank</SelectItem>
                    </SelectContent>
                  </Select>
                </FormFieldWrapper>

                <FormFieldWrapper label="Account Number" required>
                  <Input
                    placeholder="Enter your account number"
                    value={paymentData.accountNumber}
                    onChange={(e) => handleInputChange("accountNumber", e.target.value)}
                  />
                </FormFieldWrapper>
              </CardContent>
            </Card>
          )}

          {paymentData.paymentMethod === "mobile" && (
            <Card>
              <CardHeader>
                <CardTitle>Mobile Payment Details</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <FormFieldWrapper label="Mobile Number" required>
                  <Input
                    placeholder="+100 XX XXX XXXX"
                    value={paymentData.mobileNumber}
                    onChange={(e) => handleInputChange("mobileNumber", e.target.value)}
                  />
                </FormFieldWrapper>
              </CardContent>
            </Card>
          )}

          {/* Security Notice */}
          <Card className="bg-green-50 border-green-200">
            <CardContent className="p-4">
              <div className="flex items-start space-x-3">
                <Shield className="h-5 w-5 text-green-600 mt-0.5" />
                <div className="text-green-800 text-sm">
                  <p className="font-medium mb-1">Secure Payment</p>
                  <p>
                    Your payment information is encrypted and secure. This transaction is processed through the official
                    government payment gateway.
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Process Payment Button */}
          {paymentData.paymentMethod && (
            <div className="flex justify-center">
              <Button
                onClick={processPayment}
                disabled={isProcessing}
                className="bg-primary hover:bg-primary/90 px-8 py-3 text-lg"
              >
                {isProcessing ? (
                  <>
                    <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                    Processing Payment...
                  </>
                ) : (
                  `Pay ${CURRENCY} ${fees.total.toLocaleString()}`
                )}
              </Button>
            </div>
          )}
        </>
      ) : (
        /* Payment Confirmation */
        <Card className="bg-green-50 border-green-200">
          <CardHeader>
            <CardTitle className="text-green-900 flex items-center">
              <CheckCircle className="h-6 w-6 mr-2" />
              Payment Successful
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <p className="text-green-700 font-medium">Transaction ID</p>
                <p className="text-green-800 font-mono">{formData["payment"]?.transactionId}</p>
              </div>
              <div>
                <p className="text-green-700 font-medium">Amount Paid</p>
                <p className="text-green-800 font-semibold">{CURRENCY} {fees.total.toLocaleString()}</p>
              </div>
              <div>
                <p className="text-green-700 font-medium">Payment Method</p>
                <p className="text-green-800 capitalize">{paymentData.paymentMethod}</p>
              </div>
              <div>
                <p className="text-green-700 font-medium">Payment Date</p>
                <p className="text-green-800">{new Date().toLocaleDateString()}</p>
              </div>
            </div>

            <div className="bg-white p-4 rounded border">
              <p className="text-green-800 text-sm">
                <strong>Important:</strong> Please save your transaction ID for future reference. A payment receipt has
                been sent to your registered email address.
              </p>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}
