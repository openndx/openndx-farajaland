import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Header } from "../components/header";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../components/ui/card";
import { CheckCircle, Download, FileText, QrCode, Calendar, Phone } from "lucide-react";

export default function Success() {
  const navigate = useNavigate();
  const [applicationData, setApplicationData] = useState<any>(null)
  const [downloadingCredentials, setDownloadingCredentials] = useState(false)

  useEffect(() => {
    // Get application data from URL params or localStorage
    const storedData = localStorage.getItem("submitted_application")

    if (storedData) {
      setApplicationData(JSON.parse(storedData))
    } else {
      // If no data found, redirect back to apply
      navigate("/apply");
    }
  }, [navigate]);

  const generateApplicationNumber = () => {
    const date = new Date()
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, "0")
    const day = String(date.getDate()).padStart(2, "0")
    const random = Math.floor(Math.random() * 10000)
      .toString()
      .padStart(4, "0")
    return `PP${year}${month}${day}${random}`
  }

  const applicationNumber = generateApplicationNumber()

  const downloadVerifiableCredentials = async () => {
    setDownloadingCredentials(true)

    // Simulate credential generation
    setTimeout(() => {
      // Create a mock verifiable credential document
      const credentialData = {
        "@context": ["https://www.w3.org/2018/credentials/v1"],
        type: ["VerifiableCredential", "PassportApplicationCredential"],
        issuer: "did:gov:lk:immigration",
        issuanceDate: new Date().toISOString(),
        credentialSubject: {
          id: `did:sludi:${applicationData?.nic}`,
          applicationNumber: applicationNumber,
          applicantName: applicationData?.fullName || "N/A",
          nic: applicationData?.nic || "N/A",
          serviceType: applicationData?.serviceType || "normal",
          documentType: applicationData?.documentType || "all-countries",
          applicationStatus: "submitted",
          submissionDate: new Date().toISOString(),
        },
        proof: {
          type: "Ed25519Signature2018",
          created: new Date().toISOString(),
          verificationMethod: "did:gov:lk:immigration#key-1",
          proofPurpose: "assertionMethod",
          jws: "demo-header..demo-signature",
        },
      }

      // Create and download the credential file
      const blob = new Blob([JSON.stringify(credentialData, null, 2)], { type: "application/json" })
      const url = URL.createObjectURL(blob)
      const a = document.createElement("a")
      a.href = url
      a.download = `passport-application-credential-${applicationNumber}.json`
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      URL.revokeObjectURL(url)

      setDownloadingCredentials(false)
    }, 2000)
  }

  const downloadApplicationReceipt = () => {
    // Create a simple text receipt
    const receiptContent = `
DEPARTMENT OF IMMIGRATION AND EMIGRATION
SRI LANKA

PASSPORT APPLICATION RECEIPT
============================

Application Number: ${applicationNumber}
Date: ${new Date().toLocaleDateString()}
Time: ${new Date().toLocaleTimeString()}

Applicant Details:
- Name: ${applicationData?.fullName || "N/A"}
- NIC: ${applicationData?.nic || "N/A"}
- Service Type: ${applicationData?.serviceType || "Normal"}
- Document Type: ${applicationData?.documentType || "All Countries"}

Contact Information:
- Mobile: ${applicationData?.mobileNumber || "N/A"}
- Email: ${applicationData?.email || "N/A"}

Status: SUBMITTED
Next Steps: Your application is being processed. You will receive SMS/email updates.

For inquiries, contact: +94 11 532 9300
Website: www.immigration.gov.lk

Thank you for using our online service.
    `

    const blob = new Blob([receiptContent], { type: "text/plain" })
    const url = URL.createObjectURL(blob)
    const a = document.createElement("a")
    a.href = url
    a.download = `passport-application-receipt-${applicationNumber}.txt`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }

  if (!applicationData) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading application details...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-background">
      <Header />

      <div className="container mx-auto px-4 py-8 max-w-4xl">
        {/* Success Header */}
        <div className="text-center mb-8">
          <div className="flex justify-center mb-4">
            <CheckCircle className="h-16 w-16 text-green-500" />
          </div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Application Submitted Successfully!</h1>
          <p className="text-lg text-gray-600">Your passport application has been received and is being processed.</p>
        </div>

        {/* Application Details */}
        <Card className="mb-6">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <FileText className="h-5 w-5 text-blue-600" />
              Application Details
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <h3 className="font-semibold text-gray-900 mb-3">Application Information</h3>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-600">Application Number:</span>
                    <span className="font-mono font-medium">{applicationNumber}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Submission Date:</span>
                    <span>{new Date().toLocaleDateString()}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Service Type:</span>
                    <span className="capitalize">{applicationData.serviceType || "Normal"}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Document Type:</span>
                    <span className="capitalize">
                      {applicationData.documentType?.replace("-", " ") || "All Countries"}
                    </span>
                  </div>
                </div>
              </div>

              <div>
                <h3 className="font-semibold text-gray-900 mb-3">Applicant Information</h3>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-600">Name:</span>
                    <span>{applicationData.fullName || "N/A"}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">NIC:</span>
                    <span className="font-mono">{applicationData.nic || "N/A"}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Mobile:</span>
                    <span>{applicationData.mobileNumber || "N/A"}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Email:</span>
                    <span>{applicationData.email || "N/A"}</span>
                  </div>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Verifiable Credentials Section */}
        <Card className="mb-6">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <QrCode className="h-5 w-5 text-blue-600" />
              Verifiable Credentials
            </CardTitle>
            <CardDescription>Download your digital credentials for verification purposes</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
              <h4 className="font-medium text-blue-900 mb-2">What are Verifiable Credentials?</h4>
              <p className="text-sm text-blue-700">
                Verifiable credentials are cryptographically secure digital documents that prove your passport
                application has been submitted. They can be independently verified by any authorized party using
                blockchain technology.
              </p>
            </div>

            <div className="flex flex-col sm:flex-row gap-4">
              <Button onClick={downloadVerifiableCredentials} disabled={downloadingCredentials} className="flex-1">
                {downloadingCredentials ? (
                  <>
                    <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                    Generating Credentials...
                  </>
                ) : (
                  <>
                    <Download className="h-4 w-4 mr-2" />
                    Download Verifiable Credential
                  </>
                )}
              </Button>

              <Button variant="outline" onClick={downloadApplicationReceipt} className="flex-1 bg-transparent">
                <FileText className="h-4 w-4 mr-2" />
                Download Receipt
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Next Steps */}
        <Card className="mb-6">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Calendar className="h-5 w-5 text-blue-600" />
              Next Steps
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex items-start gap-3">
                <div className="w-6 h-6 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-sm font-medium">
                  1
                </div>
                <div>
                  <h4 className="font-medium">Document Verification</h4>
                  <p className="text-sm text-gray-600">Your documents will be verified within 2-3 business days.</p>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <div className="w-6 h-6 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-sm font-medium">
                  2
                </div>
                <div>
                  <h4 className="font-medium">Processing</h4>
                  <p className="text-sm text-gray-600">
                    {applicationData.serviceType === "oneday"
                      ? "Express processing will be completed within 1 business day."
                      : "Standard processing takes 7-10 business days."}
                  </p>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <div className="w-6 h-6 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-sm font-medium">
                  3
                </div>
                <div>
                  <h4 className="font-medium">Collection</h4>
                  <p className="text-sm text-gray-600">
                    You'll receive an SMS/email when your passport is ready for collection.
                  </p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Contact Information */}
        <Card className="mb-8">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Phone className="h-5 w-5 text-blue-600" />
              Need Help?
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
              <div>
                <h4 className="font-medium mb-2">Contact Information</h4>
                <p className="text-gray-600">Phone: +94 11 532 9300</p>
                <p className="text-gray-600">Email: info@immigration.gov.lk</p>
              </div>
              <div>
                <h4 className="font-medium mb-2">Office Hours</h4>
                <p className="text-gray-600">Monday - Friday: 8:30 AM - 4:15 PM</p>
                <p className="text-gray-600">Saturday: 8:30 AM - 12:30 PM</p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Action Buttons */}
        <div className="flex flex-col sm:flex-row gap-4 justify-center">
          <Button variant="outline" onClick={() => navigate("/status")} className="flex items-center gap-2">
            <FileText className="h-4 w-4" />
            Track Application Status
          </Button>

          <Button onClick={() => navigate("/")} className="flex items-center gap-2">
            Return to Home
          </Button>
        </div>
      </div>
    </div>
  )
}
