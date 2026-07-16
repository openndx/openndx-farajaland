"use client"

import {useState, useEffect, useCallback, useRef} from "react"
import { useAuth } from "react-oidc-context"
import { FormFieldWrapper } from "@/components/form-field-wrapper"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { useMultiStepForm } from "@/components/multi-step-form"
import { usePersonInfo } from "@/hooks/usePersonInfo"
import { mapPersonInfoToFormData } from "@/lib/map-person-info"
import { LoadDetailsAlert } from "@/components/load-details-alert"
import { useToast } from "@/hooks/use-toast"

const sriLankanDistricts = [
  "Ampara",
  "Anuradhapura",
  "Badulla",
  "Batticaloa",
  "Colombo",
  "Galle",
  "Gampaha",
  "Hambantota",
  "Jaffna",
  "Kalutara",
  "Kandy",
  "Kegalle",
  "Kilinochchi",
  "Kurunegala",
  "Mannar",
  "Matale",
  "Matara",
  "Monaragala",
  "Mullaitivu",
  "Nuwara Eliya",
  "Polonnaruwa",
  "Puttalam",
  "Ratnapura",
  "Trincomalee",
  "Vavuniya",
]

export function PersonalInfoStep() {
  const { updateFormData, formData, setStepValid, currentStep } = useMultiStepForm()
  const { toast } = useToast()
  const { loadPersonInfo, loading: loadingPersonInfo } = usePersonInfo()
  const auth = useAuth()
  const lastValidationRef = useRef<boolean | null>(null)

  // Get NIC from the logged-in OIDC user (email is used as the identifier / NIC).
  const getUserNic = () => auth.user?.profile.email || ""

  const [personalData, setPersonalData] = useState({
    nic: getUserNic(),
    surname: "",
    otherNames: "",
    permanentAddress: "",
    district: "",
    birthDay: "",
    birthMonth: "",
    birthYear: "",
    birthCertificateNumber: "",
    birthCertificateDistrict: "",
    placeOfBirth: "",
    sex: "",
    profession: "",
    ...formData["personal-info"],
  })

  const [errors, setErrors] = useState<Record<string, string>>({})
  // Consider form as interacted since NIC is pre-populated from user account
  const [hasInteracted, setHasInteracted] = useState(true)

  // Validate all required fields in personal information
  const validateForm = useCallback(() => {
    const requiredFields = [
      "nic",
      "surname",
      "otherNames",
      "permanentAddress",
      "district",
      "birthDay",
      "birthMonth",
      "birthYear",
      "birthCertificateNumber",
      "birthCertificateDistrict",
      "placeOfBirth",
      "sex",
      "profession",
    ]

    const allFieldsFilled = requiredFields.every((field) => {
      const value = personalData[field as keyof typeof personalData]
      return value && String(value).trim() !== ""
    })

    // NIC is pre-filled from user account, so we trust it's valid
    // Only validate format if user has manually edited it (if there's an error)
    const nicValid = personalData.nic && !errors.nic

    return allFieldsFilled && nicValid
  }, [personalData, errors])

  // Update step validity when form data changes (only if actually different)
  useEffect(() => {
    if (hasInteracted) {
      const isValid = validateForm()
      // Only call setStepValid if the validation state actually changed
      if (lastValidationRef.current !== isValid) {
        lastValidationRef.current = isValid
        setStepValid(currentStep, isValid)
      }
    }
  }, [personalData, errors, hasInteracted, currentStep, validateForm, setStepValid])

  // Calculate age to determine if guardian info is needed
  const calculateAge = () => {
    if (personalData.birthDay && personalData.birthMonth && personalData.birthYear) {
      const birthDate = new Date(
        Number.parseInt(personalData.birthYear),
        Number.parseInt(personalData.birthMonth) - 1,
        Number.parseInt(personalData.birthDay),
      )
      const today = new Date()
      const age = today.getFullYear() - birthDate.getFullYear()
      const monthDiff = today.getMonth() - birthDate.getMonth()

      if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
        return age - 1
      }
      return age
    }
    return null
  }

  const age = calculateAge()
  const isMinor = age !== null && age < 16

  const validateNIC = (nic: string) => {
    // Basic NIC validation for Sri Lankan format
    const oldFormat = /^[0-9]{9}[vVxX]$/
    const newFormat = /^[0-9]{12}$/
    return oldFormat.test(nic) || newFormat.test(nic)
  }

  const handleInputChange = (field: string, value: string) => {
    const newData = { ...personalData, [field]: value }
    setPersonalData(newData)
    updateFormData("personal-info", newData)
    setHasInteracted(true)

    // Clear error when user starts typing
    if (errors[field]) {
      setErrors((prev) => ({ ...prev, [field]: "" }))
    }

    // Validate NIC format
    if (field === "nic" && value && !validateNIC(value)) {
      setErrors((prev) => ({ ...prev, nic: "Invalid NIC format" }))
    }
  }

  const handleLoadDetails = async () => {
    const personInfo = await loadPersonInfo()

    if (!personInfo) {
      // Error already handled by usePersonInfo hook via toast
      return
    }

    // Map NDX data to form structure
    const mappedData = mapPersonInfoToFormData(personInfo, personalData.nic)

    // Update form state with loaded data
    const newData = { ...personalData, ...mappedData }
    setPersonalData(newData)
    updateFormData("personal-info", newData)
    setHasInteracted(true)

    // Show success message
    toast({
      title: "Details loaded successfully",
      description: "Your information has been loaded from the National Data Exchange. Please review and update if needed.",
    })
  }

  return (
    <div className="space-y-8">
      {/* Load Details Alert */}
      <LoadDetailsAlert onLoadDetails={handleLoadDetails} loading={loadingPersonInfo} />

      {/* Basic Personal Information */}
      <div className="space-y-6">
        <h3 className="text-lg font-semibold text-foreground border-b pb-2">Basic Information</h3>

        <FormFieldWrapper
          label="National Identity Card Number"
          required
          error={errors.nic}
          description="Your NIC from your registered account"
        >
          <Input
            placeholder="Your NIC"
            value={personalData.nic}
            readOnly
            disabled
            className="uppercase bg-muted cursor-not-allowed"
          />
        </FormFieldWrapper>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <FormFieldWrapper label="Surname" required>
            <Input
              placeholder="Enter your surname"
              value={personalData.surname}
              onChange={(e) => handleInputChange("surname", e.target.value)}
            />
          </FormFieldWrapper>
          <FormFieldWrapper label="Other Names" required>
            <Input
              placeholder="Enter your other names"
              value={personalData.otherNames}
              onChange={(e) => handleInputChange("otherNames", e.target.value)}
            />
          </FormFieldWrapper>
        </div>

        <FormFieldWrapper label="Permanent Address" required>
          <Textarea
            placeholder="Enter your complete permanent address"
            value={personalData.permanentAddress}
            onChange={(e) => handleInputChange("permanentAddress", e.target.value)}
            rows={3}
          />
        </FormFieldWrapper>

        <FormFieldWrapper label="District" required>
          <Select value={personalData.district} onValueChange={(value) => handleInputChange("district", value)}>
            <SelectTrigger>
              <SelectValue placeholder="Select your district" />
            </SelectTrigger>
            <SelectContent>
              {sriLankanDistricts.map((district) => (
                <SelectItem key={district} value={district.toLowerCase()}>
                  {district}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </FormFieldWrapper>
      </div>

      {/* Birth Information */}
      <div className="space-y-6">
        <h3 className="text-lg font-semibold text-foreground border-b pb-2">Birth Information</h3>

        <div className="grid grid-cols-3 gap-4">
          <FormFieldWrapper label="Date of Birth - Day" required>
            <Select value={personalData.birthDay} onValueChange={(value) => handleInputChange("birthDay", value)}>
              <SelectTrigger>
                <SelectValue placeholder="Day" />
              </SelectTrigger>
              <SelectContent>
                {Array.from({ length: 31 }, (_, i) => (
                  <SelectItem key={i + 1} value={String(i + 1)}>
                    {i + 1}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </FormFieldWrapper>
          <FormFieldWrapper label="Month" required>
            <Select value={personalData.birthMonth} onValueChange={(value) => handleInputChange("birthMonth", value)}>
              <SelectTrigger>
                <SelectValue placeholder="Month" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="01">January</SelectItem>
                <SelectItem value="02">February</SelectItem>
                <SelectItem value="03">March</SelectItem>
                <SelectItem value="04">April</SelectItem>
                <SelectItem value="05">May</SelectItem>
                <SelectItem value="06">June</SelectItem>
                <SelectItem value="07">July</SelectItem>
                <SelectItem value="08">August</SelectItem>
                <SelectItem value="09">September</SelectItem>
                <SelectItem value="10">October</SelectItem>
                <SelectItem value="11">November</SelectItem>
                <SelectItem value="12">December</SelectItem>
              </SelectContent>
            </Select>
          </FormFieldWrapper>
          <FormFieldWrapper label="Year" required>
            <Select value={personalData.birthYear} onValueChange={(value) => handleInputChange("birthYear", value)}>
              <SelectTrigger>
                <SelectValue placeholder="Year" />
              </SelectTrigger>
              <SelectContent>
                {Array.from({ length: 100 }, (_, i) => {
                  const year = new Date().getFullYear() - i
                  return (
                    <SelectItem key={year} value={String(year)}>
                      {year}
                    </SelectItem>
                  )
                })}
              </SelectContent>
            </Select>
          </FormFieldWrapper>
        </div>

        {age !== null && (
          <div className="p-3 bg-muted rounded-lg">
            <p className="text-sm text-muted-foreground">
              Calculated age: {age} years {isMinor && "(Guardian information will be required)"}
            </p>
          </div>
        )}

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <FormFieldWrapper label="Birth Certificate Number" required>
            <Input
              placeholder="Enter birth certificate number"
              value={personalData.birthCertificateNumber}
              onChange={(e) => handleInputChange("birthCertificateNumber", e.target.value)}
            />
          </FormFieldWrapper>
          <FormFieldWrapper label="Birth Certificate District" required>
            <Select
              value={personalData.birthCertificateDistrict}
              onValueChange={(value) => handleInputChange("birthCertificateDistrict", value)}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select district" />
              </SelectTrigger>
              <SelectContent>
                {sriLankanDistricts.map((district) => (
                  <SelectItem key={district} value={district.toLowerCase()}>
                    {district}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </FormFieldWrapper>
        </div>

        <FormFieldWrapper label="Place of Birth" required>
          <Input
            placeholder="Enter your place of birth"
            value={personalData.placeOfBirth}
            onChange={(e) => handleInputChange("placeOfBirth", e.target.value)}
          />
        </FormFieldWrapper>
      </div>

      {/* Additional Information */}
      <div className="space-y-6">
        <h3 className="text-lg font-semibold text-foreground border-b pb-2">Additional Information</h3>

        <FormFieldWrapper label="Sex" required>
          <RadioGroup
            value={personalData.sex}
            onValueChange={(value) => handleInputChange("sex", value)}
            className="flex space-x-6"
          >
            <div className="flex items-center space-x-2">
              <RadioGroupItem value="male" id="male" />
              <Label htmlFor="male">Male</Label>
            </div>
            <div className="flex items-center space-x-2">
              <RadioGroupItem value="female" id="female" />
              <Label htmlFor="female">Female</Label>
            </div>
          </RadioGroup>
        </FormFieldWrapper>

        <FormFieldWrapper label="Profession/Occupation/Job" required>
          <Input
            placeholder="Enter your profession"
            value={personalData.profession}
            onChange={(e) => handleInputChange("profession", e.target.value)}
          />
        </FormFieldWrapper>
      </div>
    </div>
  )
}
