"use client"

import { useState } from "react"
import { DocumentUpload } from "@/components/document-upload"
import { useMultiStepForm } from "@/components/multi-step-form"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { AlertCircle, CheckCircle } from "lucide-react"

interface UploadedFile {
  id: string
  file: File
  preview?: string
  status: "uploading" | "completed" | "error"
  progress: number
  error?: string
}

export function DocumentUploadStep() {
  const { updateFormData, formData } = useMultiStepForm()
  const [documents, setDocuments] = useState({
    photograph: [],
    nicCopy: [],
    birthCertificate: [],
    previousPassport: [],
    dualCitizenshipCert: [],
    guardianDocuments: [],
    ...formData["documents"],
  })

  const handleDocumentChange = (category: string, files: UploadedFile[]) => {
    const updatedDocuments = { ...documents, [category]: files }
    setDocuments(updatedDocuments)
    updateFormData("documents", updatedDocuments)
  }

  const getCompletedCount = () => {
    const requiredDocs = ["photograph", "nicCopy", "birthCertificate"]
    return requiredDocs.filter((doc) => documents[doc]?.length > 0).length
  }

  const getTotalRequired = () => {
    // Base required documents
    let total = 3 // photograph, NIC, birth certificate

    // Add conditional requirements based on form data
    if (formData["service-type"]?.presentTravelDocument) total += 1
    if (formData["dual-citizenship"]?.hasDualCitizenship === "yes") total += 1
    if (formData["personal-info"]?.age < 16) total += 1

    return total
  }

  return (
    <div className="space-y-8">
      {/* Progress Overview */}
      <Card className="bg-blue-50 border-blue-200">
        <CardHeader>
          <CardTitle className="flex items-center justify-between text-blue-900">
            <span>Document Upload Progress</span>
            <Badge variant="outline" className="bg-white">
              {getCompletedCount()} / {getTotalRequired()} Required
            </Badge>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-blue-800 text-sm">
            Please upload all required documents. Ensure all documents are clear, legible, and in the accepted formats.
          </p>
        </CardContent>
      </Card>

      {/* Required Documents */}
      <div className="space-y-6">
        <h3 className="text-lg font-semibold text-foreground border-b pb-2">Required Documents</h3>

        {/* Passport Photograph */}
        <DocumentUpload
          title="Passport Photograph"
          description="Recent passport-sized photograph (35mm x 45mm) with white background"
          acceptedTypes={["image/jpeg", "image/jpg", "image/png"]}
          maxSize={5}
          required
          onFilesChange={(files) => handleDocumentChange("photograph", files)}
          existingFiles={documents.photograph}
        />

        {/* National Identity Card */}
        <DocumentUpload
          title="National Identity Card (Copy)"
          description="Clear copy of both sides of your National Identity Card"
          acceptedTypes={["image/jpeg", "image/jpg", "image/png", "application/pdf"]}
          maxSize={10}
          required
          multiple
          onFilesChange={(files) => handleDocumentChange("nicCopy", files)}
          existingFiles={documents.nicCopy}
        />

        {/* Birth Certificate */}
        <DocumentUpload
          title="Birth Certificate (Copy)"
          description="Certified copy of your birth certificate"
          acceptedTypes={["image/jpeg", "image/jpg", "image/png", "application/pdf"]}
          maxSize={10}
          required
          onFilesChange={(files) => handleDocumentChange("birthCertificate", files)}
          existingFiles={documents.birthCertificate}
        />
      </div>

      {/* Conditional Documents */}
      <div className="space-y-6">
        <h3 className="text-lg font-semibold text-foreground border-b pb-2">Additional Documents (If Applicable)</h3>

        {/* Previous Passport */}
        <DocumentUpload
          title="Previous Passport (Copy)"
          description="Copy of your previous passport if you have one"
          acceptedTypes={["image/jpeg", "image/jpg", "image/png", "application/pdf"]}
          maxSize={10}
          onFilesChange={(files) => handleDocumentChange("previousPassport", files)}
          existingFiles={documents.previousPassport}
        />

        {/* Dual Citizenship Certificate */}
        {formData["dual-citizenship"]?.hasDualCitizenship === "yes" && (
          <DocumentUpload
            title="Dual Citizenship Certificate"
            description="Copy of your Farajaland dual citizenship certificate"
            acceptedTypes={["image/jpeg", "image/jpg", "image/png", "application/pdf"]}
            maxSize={10}
            required
            onFilesChange={(files) => handleDocumentChange("dualCitizenshipCert", files)}
            existingFiles={documents.dualCitizenshipCert}
          />
        )}

        {/* Guardian Documents */}
        {formData["personal-info"]?.age < 16 && (
          <DocumentUpload
            title="Guardian Documents"
            description="Copies of parents'/guardians' NIC and consent letters"
            acceptedTypes={["image/jpeg", "image/jpg", "image/png", "application/pdf"]}
            maxSize={10}
            required
            multiple
            onFilesChange={(files) => handleDocumentChange("guardianDocuments", files)}
            existingFiles={documents.guardianDocuments}
          />
        )}
      </div>

      {/* Document Requirements */}
      <Card className="bg-amber-50 border-amber-200">
        <CardHeader>
          <CardTitle className="text-amber-900 flex items-center">
            <AlertCircle className="h-5 w-5 mr-2" />
            Document Requirements
          </CardTitle>
        </CardHeader>
        <CardContent className="text-amber-800 text-sm space-y-2">
          <ul className="list-disc list-inside space-y-1">
            <li>All documents must be clear and legible</li>
            <li>Photographs must have a white background and show full face</li>
            <li>Document copies should be certified or attested</li>
            <li>File sizes should not exceed the specified limits</li>
            <li>Only upload documents in the accepted formats</li>
          </ul>
        </CardContent>
      </Card>

      {/* Upload Status */}
      {getCompletedCount() === getTotalRequired() && (
        <Card className="bg-green-50 border-green-200">
          <CardContent className="p-4">
            <div className="flex items-center text-green-800">
              <CheckCircle className="h-5 w-5 mr-2" />
              <span className="font-medium">All required documents uploaded successfully!</span>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}
