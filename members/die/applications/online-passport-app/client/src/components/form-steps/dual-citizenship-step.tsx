"use client"

import { useState } from "react"
import { FormFieldWrapper } from "@/components/form-field-wrapper"
import { Input } from "@/components/ui/input"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useMultiStepForm } from "@/components/multi-step-form"

const countries = [
  "Australia",
  "Canada",
  "United Kingdom",
  "United States",
  "Germany",
  "France",
  "Italy",
  "Netherlands",
  "Sweden",
  "Norway",
  "Denmark",
  "Switzerland",
  "Austria",
  "Belgium",
  "New Zealand",
  "Singapore",
  "Japan",
  "South Korea",
  "Other",
]

export function DualCitizenshipStep() {
  const { updateFormData, formData } = useMultiStepForm()
  const [dualCitizenshipData, setDualCitizenshipData] = useState({
    hasDualCitizenship: "",
    dualCitizenshipNumber: "",
    foreignNationality: "",
    foreignPassportNumber: "",
    ...formData["dual-citizenship"],
  })

  const handleInputChange = (field: string, value: string) => {
    const newData = { ...dualCitizenshipData, [field]: value }

    // Clear dependent fields when changing dual citizenship status
    if (field === "hasDualCitizenship" && value === "no") {
      newData.dualCitizenshipNumber = ""
      newData.foreignNationality = ""
      newData.foreignPassportNumber = ""
    }

    setDualCitizenshipData(newData)
    updateFormData("dual-citizenship", newData)
  }

  const hasDualCitizenship = dualCitizenshipData.hasDualCitizenship === "yes"

  return (
    <div className="space-y-6">
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <h3 className="text-lg font-semibold text-blue-900 mb-2">Dual Citizenship Information</h3>
        <p className="text-blue-800 text-sm">
          Please provide accurate information about your citizenship status. This information is mandatory for passport
          processing.
        </p>
      </div>

      <FormFieldWrapper label="Have you obtained Dual Citizenship in Farajaland?" required>
        <RadioGroup
          value={dualCitizenshipData.hasDualCitizenship}
          onValueChange={(value) => handleInputChange("hasDualCitizenship", value)}
          className="flex space-x-6"
        >
          <div className="flex items-center space-x-2">
            <RadioGroupItem value="yes" id="dual-yes" />
            <Label htmlFor="dual-yes">Yes</Label>
          </div>
          <div className="flex items-center space-x-2">
            <RadioGroupItem value="no" id="dual-no" />
            <Label htmlFor="dual-no">No</Label>
          </div>
        </RadioGroup>
      </FormFieldWrapper>

      {hasDualCitizenship && (
        <div className="space-y-6 p-4 bg-gray-50 rounded-lg border">
          <h4 className="text-md font-semibold text-foreground">Dual Citizenship Details</h4>

          <FormFieldWrapper
            label="Dual Citizenship Certificate Number"
            required
            description="Enter your Farajaland dual citizenship certificate number"
          >
            <Input
              placeholder="Enter dual citizenship number"
              value={dualCitizenshipData.dualCitizenshipNumber}
              onChange={(e) => handleInputChange("dualCitizenshipNumber", e.target.value)}
            />
          </FormFieldWrapper>

          <FormFieldWrapper label="Foreign Nationality" required>
            <Select
              value={dualCitizenshipData.foreignNationality}
              onValueChange={(value) => handleInputChange("foreignNationality", value)}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select your foreign nationality" />
              </SelectTrigger>
              <SelectContent>
                {countries.map((country) => (
                  <SelectItem key={country} value={country.toLowerCase()}>
                    {country}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </FormFieldWrapper>

          <FormFieldWrapper label="Foreign Passport Number" required description="Enter your foreign passport number">
            <Input
              placeholder="Enter foreign passport number"
              value={dualCitizenshipData.foreignPassportNumber}
              onChange={(e) => handleInputChange("foreignPassportNumber", e.target.value)}
            />
          </FormFieldWrapper>

          <div className="bg-amber-50 border border-amber-200 rounded-lg p-3">
            <p className="text-amber-800 text-sm">
              <strong>Important:</strong> You will need to provide copies of your dual citizenship certificate and
              foreign passport during the application process.
            </p>
          </div>
        </div>
      )}

      {dualCitizenshipData.hasDualCitizenship === "no" && (
        <div className="bg-green-50 border border-green-200 rounded-lg p-4">
          <p className="text-green-800 text-sm">
            You have indicated that you do not hold dual citizenship. Please proceed to the next step.
          </p>
        </div>
      )}
    </div>
  )
}
