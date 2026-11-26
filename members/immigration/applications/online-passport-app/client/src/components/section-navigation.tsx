"use client"

import { Button } from "@/components/ui/button"
import { CheckCircle2, Circle } from "lucide-react"

interface Section {
  id: string
  title: string
  completed?: boolean
}

interface SectionNavigationProps {
  sections: Section[]
  currentSection: string
  onSectionChange: (sectionId: string) => void
}

export function SectionNavigation({ sections, currentSection, onSectionChange }: SectionNavigationProps) {
  const scrollToSection = (sectionId: string) => {
    const element = document.getElementById(sectionId)
    if (element) {
      element.scrollIntoView({ behavior: "smooth", block: "start" })
      onSectionChange(sectionId)
    }
  }

  return (
    <div className="sticky top-4 bg-white border rounded-lg p-4 shadow-sm">
      <h3 className="font-semibold text-sm text-gray-900 mb-3">Application Sections</h3>
      <nav className="space-y-2">
        {sections.map((section) => (
          <Button
            key={section.id}
            variant={currentSection === section.id ? "default" : "ghost"}
            size="sm"
            className="w-full justify-start text-left h-auto p-2"
            onClick={() => scrollToSection(section.id)}
          >
            <div className="flex items-center gap-2">
              {section.completed ? <CheckCircle2 className="h-4 w-4 text-green-600" /> : <Circle className="h-4 w-4" />}
              <span className="text-xs">{section.title}</span>
            </div>
          </Button>
        ))}
      </nav>
    </div>
  )
}
