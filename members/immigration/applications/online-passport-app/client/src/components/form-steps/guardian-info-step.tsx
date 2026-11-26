"use client"

import { useState } from "react"
import { FormFieldWrapper } from "@/components/form-field-wrapper"
import { Input } from "@/components/ui/input"
import { useMultiStepForm } from "@/components/multi-step-form"

export function GuardianInfoStep() {
  const { updateFormData, formData } = useMultiStepForm()
  const [guardianData, setGuardianData] = useState({
    fatherNIC: "",
    fatherPassport: "",
    motherNIC: "",
    motherPassport: "",
    ...formData["guardian-info"],
  })

  const handleInputChange = (field: string, value: string) => {
    const newData = { ...guardianData, [field]: value }
    setGuardianData(newData)
    updateFormData("guardian-info", newData)
  }

  return (
    <div className="space-y-8">
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <h3 className="text-lg font-semibold text-blue-900 mb-2">Guardian Information Required</h3>
        <p className="text-blue-800 text-sm">
          Since this application is for a child below 16 years of age, guardian information must be provided.
        </p>
      </div>

      <div className="grid md:grid-cols-2 gap-8">
        {/* Father/Guardian Information */}
        <div className="space-y-4">
          <h4 className="text-md font-semibold text-foreground border-b pb-2">Father / Guardian</h4>

          <FormFieldWrapper
            label="National Identity Card Number"
            required
            description="Father's or Guardian's NIC number"
          >
            <Input
              placeholder="Enter NIC number"
              value={guardianData.fatherNIC}
              onChange={(e) => handleInputChange("fatherNIC", e.target.value.toUpperCase())}
              className="uppercase"
            />
          </FormFieldWrapper>

          <FormFieldWrapper
            label="Present Travel Document Number"
            description="Father's or Guardian's passport number (if available)"
          >
            <Input
              placeholder="Enter passport number (if any)"
              value={guardianData.fatherPassport}
              onChange={(e) => handleInputChange("fatherPassport", e.target.value)}
            />
          </FormFieldWrapper>
        </div>

        {/* Mother/Guardian Information */}
        <div className="space-y-4">
          <h4 className="text-md font-semibold text-foreground border-b pb-2">Mother / Guardian</h4>

          <FormFieldWrapper
            label="National Identity Card Number"
            required
            description="Mother's or Guardian's NIC number"
          >
            <Input
              placeholder="Enter NIC number"
              value={guardianData.motherNIC}
              onChange={(e) => handleInputChange("motherNIC", e.target.value.toUpperCase())}
              className="uppercase"
            />
          </FormFieldWrapper>

          <FormFieldWrapper
            label="Present Travel Document Number"
            description="Mother's or Guardian's passport number (if available)"
          >
            <Input
              placeholder="Enter passport number (if any)"
              value={guardianData.motherPassport}
              onChange={(e) => handleInputChange("motherPassport", e.target.value)}
            />
          </FormFieldWrapper>
        </div>
      </div>

      <div className="bg-amber-50 border border-amber-200 rounded-lg p-4">
        <p className="text-amber-800 text-sm">
          <strong>Note:</strong> Both parents' or guardians' consent and identification documents will be required for
          passport processing. Please ensure all information is accurate.
        </p>
      </div>
    </div>
  )
}
