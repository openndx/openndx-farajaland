"use client"

import { useState } from "react"
import { useMultiStepForm } from "@/components/multi-step-form"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import { Badge } from "@/components/ui/badge"
import { SignaturePad } from "@/components/signature-pad"
import { Separator } from "@/components/ui/separator"
import { Edit, FileText, User, Phone, Upload, Shield, AlertTriangle } from "lucide-react"

export function ReviewDeclarationStep() {
  const { formData, goToStep } = useMultiStepForm()
  const [acceptedDeclaration, setAcceptedDeclaration] = useState(false)
  const [signature, setSignature] = useState<string | null>(null)

  const formatValue = (value: any) => {
    if (!value) return "Not provided"
    if (typeof value === "string") return value
    if (typeof value === "object") return JSON.stringify(value)
    return String(value)
  }

  const getStepData = (stepId: string) => {
    return formData[stepId] || {}
  }

  const isApplicationComplete = () => {
    return acceptedDeclaration && signature
  }

  return (
    <div className="space-y-8">
      {/* Application Summary Header */}
      <Card className="bg-blue-50 border-blue-200">
        <CardHeader>
          <CardTitle className="text-blue-900 flex items-center">
            <FileText className="h-5 w-5 mr-2" />
            Application Summary
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-blue-800 text-sm">
            Please carefully review all information below. You can edit any section by clicking the edit button.
          </p>
        </CardContent>
      </Card>

      {/* Service Type Review */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="text-lg">Service Selection</CardTitle>
          <Button variant="outline" size="sm" onClick={() => goToStep(0)}>
            <Edit className="h-4 w-4 mr-2" />
            Edit
          </Button>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <p className="text-sm font-medium text-muted-foreground">Service Type</p>
              <p className="text-foreground">{formatValue(getStepData("service-type").serviceType)}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Travel Document</p>
              <p className="text-foreground">{formatValue(getStepData("service-type").travelDocument)}</p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Personal Information Review */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="text-lg flex items-center">
            <User className="h-5 w-5 mr-2" />
            Personal Information
          </CardTitle>
          <Button variant="outline" size="sm" onClick={() => goToStep(1)}>
            <Edit className="h-4 w-4 mr-2" />
            Edit
          </Button>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <p className="text-sm font-medium text-muted-foreground">NIC Number</p>
              <p className="text-foreground font-mono">{formatValue(getStepData("personal-info").nicNumber)}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Full Name</p>
              <p className="text-foreground">
                {formatValue(getStepData("personal-info").surname)},{" "}
                {formatValue(getStepData("personal-info").otherNames)}
              </p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Date of Birth</p>
              <p className="text-foreground">
                {formatValue(getStepData("personal-info").birthDay)}/
                {formatValue(getStepData("personal-info").birthMonth)}/
                {formatValue(getStepData("personal-info").birthYear)}
              </p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Sex</p>
              <p className="text-foreground capitalize">{formatValue(getStepData("personal-info").sex)}</p>
            </div>
            <div className="md:col-span-2">
              <p className="text-sm font-medium text-muted-foreground">Permanent Address</p>
              <p className="text-foreground">{formatValue(getStepData("personal-info").permanentAddress)}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Profession</p>
              <p className="text-foreground">{formatValue(getStepData("personal-info").profession)}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Place of Birth</p>
              <p className="text-foreground">{formatValue(getStepData("personal-info").placeOfBirth)}</p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Contact Information Review */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="text-lg flex items-center">
            <Phone className="h-5 w-5 mr-2" />
            Contact Information
          </CardTitle>
          <Button variant="outline" size="sm" onClick={() => goToStep(3)}>
            <Edit className="h-4 w-4 mr-2" />
            Edit
          </Button>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <p className="text-sm font-medium text-muted-foreground">Mobile Number</p>
              <p className="text-foreground">{formatValue(getStepData("contact-info").mobile)}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Email Address</p>
              <p className="text-foreground">{formatValue(getStepData("contact-info").email)}</p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Dual Citizenship Review */}
      {getStepData("dual-citizenship").hasDualCitizenship === "yes" && (
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-lg flex items-center">
              <Shield className="h-5 w-5 mr-2" />
              Dual Citizenship
            </CardTitle>
            <Button variant="outline" size="sm" onClick={() => goToStep(4)}>
              <Edit className="h-4 w-4 mr-2" />
              Edit
            </Button>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <p className="text-sm font-medium text-muted-foreground">Foreign Nationality</p>
                <p className="text-foreground capitalize">
                  {formatValue(getStepData("dual-citizenship").foreignNationality)}
                </p>
              </div>
              <div>
                <p className="text-sm font-medium text-muted-foreground">Foreign Passport Number</p>
                <p className="text-foreground font-mono">
                  {formatValue(getStepData("dual-citizenship").foreignPassportNumber)}
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Documents Review */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="text-lg flex items-center">
            <Upload className="h-5 w-5 mr-2" />
            Uploaded Documents
          </CardTitle>
          <Button variant="outline" size="sm" onClick={() => goToStep(5)}>
            <Edit className="h-4 w-4 mr-2" />
            Edit
          </Button>
        </CardHeader>
        <CardContent>
          <div className="space-y-2">
            {Object.entries(getStepData("documents")).map(
              ([category, files]: [string, any]) =>
                files &&
                files.length > 0 && (
                  <div key={category} className="flex items-center justify-between p-2 bg-muted rounded">
                    <span className="text-sm capitalize">{category.replace(/([A-Z])/g, " $1").trim()}</span>
                    <Badge variant="secondary">{files.length} file(s)</Badge>
                  </div>
                ),
            )}
          </div>
        </CardContent>
      </Card>

      <Separator />

      {/* Declaration Section */}
      <Card className="border-amber-200 bg-amber-50">
        <CardHeader>
          <CardTitle className="text-amber-900 flex items-center">
            <AlertTriangle className="h-5 w-5 mr-2" />
            Declaration
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="bg-white p-4 rounded border text-sm space-y-3">
            <p className="font-medium text-foreground">I declare that:</p>
            <ul className="list-disc list-inside space-y-2 text-muted-foreground">
              <li>
                I am a citizen of Farajaland and the above information provided by me and the documents attached hereto
                are true and correct.
              </li>
              <li>
                I am aware of the fact that producing forged/falsified documents and information is a punishable
                offence.
              </li>
              <li>
                I understand that any false information provided may result in the rejection of my application or
                cancellation of my passport.
              </li>
              <li>
                I agree to comply with all passport regulations and requirements set by the Department of Immigration
                and Emigration.
              </li>
              <li>
                I understand that the passport remains the property of the Government of Farajaland and may be withdrawn
                at any time.
              </li>
            </ul>
          </div>

          {/* Declaration Acceptance */}
          <div className="flex items-start space-x-3">
            <Checkbox
              id="declaration"
              checked={acceptedDeclaration}
              onCheckedChange={(checked) => setAcceptedDeclaration(checked as boolean)}
            />
            <label htmlFor="declaration" className="text-sm text-foreground leading-relaxed">
              I have read and understood the above declaration and I accept all terms and conditions. I confirm that all
              information provided is accurate and complete.
            </label>
          </div>

          {/* Digital Signature */}
          {acceptedDeclaration && (
            <div className="space-y-4">
              <div>
                <h4 className="font-medium text-foreground mb-2">Digital Signature</h4>
                <p className="text-sm text-muted-foreground mb-4">
                  Please provide your digital signature below to complete your application.
                </p>
                <SignaturePad onSignatureChange={setSignature} />
              </div>
            </div>
          )}

          {/* Submission Status */}
          {isApplicationComplete() && (
            <Card className="bg-green-50 border-green-200">
              <CardContent className="p-4">
                <div className="flex items-center text-green-800">
                  <FileText className="h-5 w-5 mr-2" />
                  <span className="font-medium">Application ready for submission!</span>
                </div>
                <p className="text-green-700 text-sm mt-1">
                  All required information has been provided and your declaration has been signed.
                </p>
              </CardContent>
            </Card>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
