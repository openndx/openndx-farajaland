import { useState } from "react";
import { Header } from "../components/header";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Button } from "../components/ui/button";
import { Input } from "../components/ui/input";
import { FormFieldWrapper } from "../components/form-field-wrapper";
import { StatusTimeline } from "../components/status-timeline";
import { Badge } from "../components/ui/badge";
import { Separator } from "../components/ui/separator";
import { Search, FileText, Phone, Mail, MapPin, Clock, AlertCircle } from "lucide-react";

export default function Status() {
  const [searchQuery, setSearchQuery] = useState("")
  const [applicationData, setApplicationData] = useState<any>(null)
  const [isSearching, setIsSearching] = useState(false)
  const [error, setError] = useState("")

  const handleSearch = async () => {
    if (!searchQuery.trim()) {
      setError("Please enter a search query")
      return
    }

    setIsSearching(true)
    setError("")

    // Simulate API call
    await new Promise((resolve) => setTimeout(resolve, 1500))

    // Mock application data
    const mockData = {
      applicationNumber: "PA2024001234",
      nicNumber: "123456789V",
      applicantName: "Suresh Fernando",
      serviceType: "Normal Processing",
      travelDocument: "All Countries Passport",
      currentStatus: "processing",
      submissionDate: "2024-01-15",
      estimatedCompletion: "2024-01-28",
      paymentStatus: "Completed",
      paymentAmount: "FL 3,750",
      collectionCenter: "Department of Immigration and Emigration - Central City",
      contactNumber: "+100 11 532 9000",
    }

    if (searchQuery === "PA2024001234" || searchQuery === "123456789V") {
      setApplicationData(mockData)
    } else {
      setError("Application not found. Please check your application number or NIC.")
    }

    setIsSearching(false)
  }

  const getStatusBadge = (status: string) => {
    const statusConfig = {
      submitted: { label: "Submitted", variant: "secondary" as const },
      payment: { label: "Payment Confirmed", variant: "default" as const },
      review: { label: "Under Review", variant: "secondary" as const },
      processing: { label: "Processing", variant: "default" as const },
      printing: { label: "Printing", variant: "secondary" as const },
      ready: { label: "Ready for Collection", variant: "default" as const },
      completed: { label: "Completed", variant: "default" as const },
    }

    const config = statusConfig[status as keyof typeof statusConfig] || statusConfig.submitted
    return <Badge variant={config.variant}>{config.label}</Badge>
  }

  return (
    <div className="min-h-screen bg-background">
      <Header />

      <div className="max-w-4xl mx-auto p-6 py-8">
        {/* Page Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-foreground mb-2">Track Your Application</h1>
          <p className="text-muted-foreground">
            Enter your application number or NIC to check the status of your passport application.
          </p>
        </div>

        {/* Search Section */}
        <Card className="mb-8">
          <CardHeader>
            <CardTitle className="flex items-center">
              <Search className="h-5 w-5 mr-2" />
              Search Application
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="md:col-span-2">
                <FormFieldWrapper label="Application Number or NIC" required>
                  <Input
                    placeholder="Enter application number (e.g., PA2024001234) or NIC"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    onKeyPress={(e) => e.key === "Enter" && handleSearch()}
                  />
                </FormFieldWrapper>
              </div>
              <div className="flex items-end">
                <Button onClick={handleSearch} disabled={isSearching} className="w-full bg-primary hover:bg-primary/90">
                  {isSearching ? (
                    <>
                      <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                      Searching...
                    </>
                  ) : (
                    <>
                      <Search className="h-4 w-4 mr-2" />
                      Search
                    </>
                  )}
                </Button>
              </div>
            </div>

            {error && (
              <div className="flex items-center space-x-2 text-destructive text-sm">
                <AlertCircle className="h-4 w-4" />
                <span>{error}</span>
              </div>
            )}

            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <p className="text-blue-800 text-sm">
                <strong>Demo:</strong> Try searching with "PA2024001234" or "123456789V" to see a sample application
                status.
              </p>
            </div>
          </CardContent>
        </Card>

        {/* Application Details */}
        {applicationData && (
          <div className="space-y-6">
            {/* Application Summary */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center justify-between">
                  <span className="flex items-center">
                    <FileText className="h-5 w-5 mr-2" />
                    Application Details
                  </span>
                  {getStatusBadge(applicationData.currentStatus)}
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 text-sm">
                  <div>
                    <p className="font-medium text-muted-foreground">Application Number</p>
                    <p className="text-foreground font-mono">{applicationData.applicationNumber}</p>
                  </div>
                  <div>
                    <p className="font-medium text-muted-foreground">Applicant Name</p>
                    <p className="text-foreground">{applicationData.applicantName}</p>
                  </div>
                  <div>
                    <p className="font-medium text-muted-foreground">NIC Number</p>
                    <p className="text-foreground font-mono">{applicationData.nicNumber}</p>
                  </div>
                  <div>
                    <p className="font-medium text-muted-foreground">Service Type</p>
                    <p className="text-foreground">{applicationData.serviceType}</p>
                  </div>
                  <div>
                    <p className="font-medium text-muted-foreground">Travel Document</p>
                    <p className="text-foreground">{applicationData.travelDocument}</p>
                  </div>
                  <div>
                    <p className="font-medium text-muted-foreground">Submission Date</p>
                    <p className="text-foreground">{new Date(applicationData.submissionDate).toLocaleDateString()}</p>
                  </div>
                  <div>
                    <p className="font-medium text-muted-foreground">Payment Status</p>
                    <p className="text-green-600 font-medium">{applicationData.paymentStatus}</p>
                  </div>
                  <div>
                    <p className="font-medium text-muted-foreground">Amount Paid</p>
                    <p className="text-foreground font-semibold">{applicationData.paymentAmount}</p>
                  </div>
                  <div>
                    <p className="font-medium text-muted-foreground">Expected Completion</p>
                    <p className="text-foreground flex items-center">
                      <Clock className="h-4 w-4 mr-1" />
                      {new Date(applicationData.estimatedCompletion).toLocaleDateString()}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Status Timeline */}
            <Card>
              <CardHeader>
                <CardTitle>Application Progress</CardTitle>
              </CardHeader>
              <CardContent>
                <StatusTimeline applicationData={applicationData} />
              </CardContent>
            </Card>

            {/* Collection Information */}
            <Card className="bg-amber-50 border-amber-200">
              <CardHeader>
                <CardTitle className="text-amber-900">Collection Information</CardTitle>
              </CardHeader>
              <CardContent className="text-amber-800 space-y-3">
                <div className="flex items-start space-x-3">
                  <MapPin className="h-5 w-5 mt-0.5" />
                  <div>
                    <p className="font-medium">Collection Center</p>
                    <p className="text-sm">{applicationData.collectionCenter}</p>
                  </div>
                </div>
                <div className="flex items-start space-x-3">
                  <Phone className="h-5 w-5 mt-0.5" />
                  <div>
                    <p className="font-medium">Contact Number</p>
                    <p className="text-sm">{applicationData.contactNumber}</p>
                  </div>
                </div>
                <Separator className="bg-amber-200" />
                <p className="text-sm">
                  <strong>Important:</strong> Please bring your original NIC and payment receipt when collecting your
                  passport. Collection hours: Monday to Friday, 8:30 AM - 4:30 PM.
                </p>
              </CardContent>
            </Card>

            {/* Contact Support */}
            <Card>
              <CardHeader>
                <CardTitle>Need Help?</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <p className="text-muted-foreground text-sm">
                  If you have any questions about your application or need assistance, please contact us:
                </p>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                  <div className="flex items-center space-x-3">
                    <Phone className="h-4 w-4 text-primary" />
                    <div>
                      <p className="font-medium">Hotline</p>
                      <p className="text-muted-foreground">+100 11 532 9000</p>
                    </div>
                  </div>
                  <div className="flex items-center space-x-3">
                    <Mail className="h-4 w-4 text-primary" />
                    <div>
                      <p className="font-medium">Email</p>
                      <p className="text-muted-foreground">info@immigration.ndx.fl</p>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        )}
      </div>
    </div>
  )
}
