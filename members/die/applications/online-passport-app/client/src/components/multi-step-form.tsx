import { createContext, useContext, useState, type ReactNode } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Progress } from "@/components/ui/progress"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { ChevronLeft, ChevronRight, Check, AlertCircle } from "lucide-react"
import { cn } from "@/lib/utils"

interface FormStep {
  id: string
  title: string
  description?: string
  component: ReactNode
  isValid?: boolean
}

interface MultiStepFormContextType {
  currentStep: number
  totalSteps: number
  formData: Record<string, any>
  updateFormData: (stepId: string, data: any) => void
  nextStep: () => void
  prevStep: () => void
  goToStep: (step: number) => void
  isStepValid: (stepIndex: number) => boolean
  setStepValid: (stepIndex: number, isValid: boolean) => void
}

const MultiStepFormContext = createContext<MultiStepFormContextType | undefined>(undefined)

export function useMultiStepForm() {
  const context = useContext(MultiStepFormContext)
  if (!context) {
    throw new Error("useMultiStepForm must be used within a MultiStepFormProvider")
  }
  return context
}

interface MultiStepFormProps {
  steps: FormStep[]
  onSubmit: (data: Record<string, any>) => void
  children?: ReactNode
}

export function MultiStepForm({ steps, onSubmit, children }: MultiStepFormProps) {
  const [currentStep, setCurrentStep] = useState(0)
  const [formData, setFormData] = useState<Record<string, any>>({})
  const [stepValidation, setStepValidation] = useState<Record<number, boolean>>({})
  const [validationError, setValidationError] = useState<string | null>(null)

  const updateFormData = (stepId: string, data: any) => {
    setFormData((prev) => ({
      ...prev,
      [stepId]: { ...prev[stepId], ...data },
    }))
  }

  const nextStep = () => {
    // Check if current step is valid before allowing navigation
    if (!isStepValid(currentStep)) {
      setValidationError("Please fill in all required fields before proceeding to the next step.")
      return
    }

    if (currentStep < steps.length - 1) {
      setCurrentStep((prev) => prev + 1)
      setValidationError(null)
    }
  }

  const prevStep = () => {
    if (currentStep > 0) {
      setCurrentStep((prev) => prev - 1)
    }
  }

  const goToStep = (step: number) => {
    if (step >= 0 && step < steps.length) {
      setCurrentStep(step)
    }
  }

  const isStepValid = (stepIndex: number) => {
    return stepValidation[stepIndex] || false
  }

  const setStepValid = (stepIndex: number, isValid: boolean) => {
    setStepValidation((prev) => ({
      ...prev,
      [stepIndex]: isValid,
    }))
  }

  const handleSubmit = () => {
    onSubmit(formData)
  }

  const contextValue: MultiStepFormContextType = {
    currentStep,
    totalSteps: steps.length,
    formData,
    updateFormData,
    nextStep,
    prevStep,
    goToStep,
    isStepValid,
    setStepValid,
  }

  const progress = ((currentStep + 1) / steps.length) * 100

  return (
    <MultiStepFormContext.Provider value={contextValue}>
      <div className="max-w-4xl mx-auto p-6">
        {/* Progress Header */}
        <div className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <h1 className="text-2xl font-bold text-foreground font-sans">Farajaland Passport Application</h1>
            <div className="text-sm text-muted-foreground">
              Step {currentStep + 1} of {steps.length}
            </div>
          </div>
          <Progress value={progress} className="h-2 mb-6" />

          {/* Step Navigation */}
          <div className="flex items-center space-x-2 overflow-x-auto pb-2">
            {steps.map((step, index) => (
              <div
                key={step.id}
                className={cn(
                  "flex items-center space-x-2 px-3 py-2 rounded-lg text-sm whitespace-nowrap cursor-pointer transition-colors",
                  index === currentStep
                    ? "bg-primary text-primary-foreground"
                    : index < currentStep
                      ? "bg-green-100 text-green-800 hover:bg-green-200"
                      : "bg-muted text-muted-foreground hover:bg-muted/80",
                )}
                onClick={() => goToStep(index)}
              >
                {index < currentStep ? (
                  <Check className="h-4 w-4" />
                ) : (
                  <span className="w-4 h-4 rounded-full bg-current opacity-20" />
                )}
                <span>{step.title}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Current Step Content */}
        <Card className="mb-6">
          <CardHeader>
            <CardTitle className="font-sans">{steps[currentStep].title}</CardTitle>
            {steps[currentStep].description && (
              <p className="text-muted-foreground">{steps[currentStep].description}</p>
            )}
          </CardHeader>
          <CardContent>{steps[currentStep].component}</CardContent>
        </Card>

        {/* Validation Error Alert */}
        {validationError && (
          <Alert variant="destructive" className="mb-6">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>{validationError}</AlertDescription>
          </Alert>
        )}

        {/* Navigation Buttons */}
        <div className="flex justify-between">
          <Button
            variant="outline"
            onClick={prevStep}
            disabled={currentStep === 0}
            className="flex items-center space-x-2 bg-transparent"
          >
            <ChevronLeft className="h-4 w-4" />
            <span>Previous</span>
          </Button>

          {currentStep === steps.length - 1 ? (
            <Button onClick={handleSubmit} className="bg-primary hover:bg-primary/90 flex items-center space-x-2">
              <span>Submit Application</span>
            </Button>
          ) : (
            <Button
              onClick={nextStep}
              disabled={!isStepValid(currentStep)}
              className="bg-primary hover:bg-primary/90 flex items-center space-x-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <span>Next</span>
              <ChevronRight className="h-4 w-4" />
            </Button>
          )}
        </div>

        {children}
      </div>
    </MultiStepFormContext.Provider>
  )
}
