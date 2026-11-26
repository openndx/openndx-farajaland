"use client"

import type React from "react"

import { Card, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { CheckCircle, Clock, AlertCircle, Package, FileText, CreditCard, Eye, Truck } from "lucide-react"
import { cn } from "@/lib/utils"

interface StatusStep {
  id: string
  title: string
  description: string
  status: "completed" | "current" | "pending" | "error"
  date?: string
  estimatedDate?: string
  icon: React.ReactNode
}

interface StatusTimelineProps {
  applicationData: {
    applicationNumber: string
    currentStatus: string
    submissionDate: string
    estimatedCompletion: string
    serviceType: string
  }
}

export function StatusTimeline({ applicationData }: StatusTimelineProps) {
  const getStatusSteps = (): StatusStep[] => {
    const baseSteps: StatusStep[] = [
      {
        id: "submitted",
        title: "Application Submitted",
        description: "Your application has been successfully submitted",
        status: "completed",
        date: applicationData.submissionDate,
        icon: <FileText className="h-5 w-5" />,
      },
      {
        id: "payment",
        title: "Payment Confirmed",
        description: "Payment has been processed successfully",
        status: "completed",
        date: applicationData.submissionDate,
        icon: <CreditCard className="h-5 w-5" />,
      },
      {
        id: "review",
        title: "Document Review",
        description: "Documents are being reviewed by immigration officers",
        status:
          applicationData.currentStatus === "review"
            ? "current"
            : ["submitted", "payment"].includes(applicationData.currentStatus)
              ? "pending"
              : "completed",
        date: applicationData.currentStatus === "review" ? undefined : "2024-01-16",
        estimatedDate: "2024-01-18",
        icon: <Eye className="h-5 w-5" />,
      },
      {
        id: "processing",
        title: "Application Processing",
        description: "Your passport application is being processed",
        status:
          applicationData.currentStatus === "processing"
            ? "current"
            : ["submitted", "payment", "review"].includes(applicationData.currentStatus)
              ? "pending"
              : "completed",
        estimatedDate: "2024-01-22",
        icon: <Clock className="h-5 w-5" />,
      },
      {
        id: "printing",
        title: "Passport Printing",
        description: "Your passport is being printed and prepared",
        status:
          applicationData.currentStatus === "printing"
            ? "current"
            : ["submitted", "payment", "review", "processing"].includes(applicationData.currentStatus)
              ? "pending"
              : "completed",
        estimatedDate: "2024-01-25",
        icon: <Package className="h-5 w-5" />,
      },
      {
        id: "ready",
        title: "Ready for Collection",
        description: "Your passport is ready for collection",
        status:
          applicationData.currentStatus === "ready"
            ? "current"
            : applicationData.currentStatus === "completed"
              ? "completed"
              : "pending",
        estimatedDate: applicationData.estimatedCompletion,
        icon: <Truck className="h-5 w-5" />,
      },
    ]

    return baseSteps
  }

  const steps = getStatusSteps()

  const getStatusIcon = (status: string) => {
    switch (status) {
      case "completed":
        return <CheckCircle className="h-5 w-5 text-green-600" />
      case "current":
        return <Clock className="h-5 w-5 text-blue-600" />
      case "error":
        return <AlertCircle className="h-5 w-5 text-red-600" />
      default:
        return <Clock className="h-5 w-5 text-gray-400" />
    }
  }

  return (
    <div className="space-y-6">
      {steps.map((step, index) => (
        <div key={step.id} className="relative">
          {/* Timeline Line */}
          {index < steps.length - 1 && <div className="absolute left-6 top-12 w-0.5 h-16 bg-border" />}

          <div className="flex items-start space-x-4">
            {/* Status Icon */}
            <div
              className={cn(
                "flex items-center justify-center w-12 h-12 rounded-full border-2",
                step.status === "completed"
                  ? "border-green-200 bg-green-50"
                  : step.status === "current"
                    ? "border-blue-200 bg-blue-50"
                    : step.status === "error"
                      ? "border-red-200 bg-red-50"
                      : "border-gray-200 bg-gray-50",
              )}
            >
              {getStatusIcon(step.status)}
            </div>

            {/* Status Content */}
            <div className="flex-1 min-w-0">
              <Card
                className={cn(
                  "border-l-4",
                  step.status === "completed"
                    ? "border-l-green-500"
                    : step.status === "current"
                      ? "border-l-blue-500"
                      : step.status === "error"
                        ? "border-l-red-500"
                        : "border-l-gray-300",
                )}
              >
                <CardContent className="p-4">
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="font-semibold text-foreground">{step.title}</h3>
                    <Badge
                      variant={
                        step.status === "completed" ? "default" : step.status === "current" ? "secondary" : "outline"
                      }
                    >
                      {step.status === "completed"
                        ? "Completed"
                        : step.status === "current"
                          ? "In Progress"
                          : step.status === "error"
                            ? "Issue"
                            : "Pending"}
                    </Badge>
                  </div>

                  <p className="text-sm text-muted-foreground mb-3">{step.description}</p>

                  <div className="flex items-center justify-between text-xs text-muted-foreground">
                    {step.date ? (
                      <span>Completed: {new Date(step.date).toLocaleDateString()}</span>
                    ) : step.estimatedDate ? (
                      <span>Expected: {new Date(step.estimatedDate).toLocaleDateString()}</span>
                    ) : (
                      <span>Pending</span>
                    )}

                    {step.status === "current" && <span className="text-blue-600 font-medium">Current Step</span>}
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}
