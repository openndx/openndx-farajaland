"use client"

import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Plane, MapPin, ExternalLink } from "lucide-react"
import { Link } from "react-router-dom"

export function HeroSection() {
  return (
    <div className="relative min-h-[600px] bg-gradient-to-br from-cyan-50 to-blue-100">
      {/* Background Image */}
      <div
        className="fixed inset-0 bg-cover bg-center bg-no-repeat opacity-20 pointer-events-none"
        style={{
          backgroundImage: "url('/sri-lankan-cityscape-with-modern-buildings-and-pal.png')",
        }}
      />

      {/* Content */}
      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-bold text-foreground mb-6 font-sans mt-4">
            Apply for your Farajaland passport online from anywhere.
          </h2>
        </div>

        {/* Application Cards */}
        <div className="grid md:grid-cols-2 gap-8 max-w-4xl mx-auto mt-64">
          {/* Overseas Applicants */}
          <Card className="bg-white/95 backdrop-blur-sm border-border shadow-lg hover:shadow-xl transition-shadow">
            <CardContent className="p-8">
              <div className="flex items-center mb-6">
                <div className="bg-primary/10 p-3 rounded-full mr-4">
                  <Plane className="h-8 w-8 text-primary" />
                </div>
                <div>
                  <h3 className="text-xl font-semibold text-foreground font-sans">Applicants Residing Overseas</h3>
                  <p className="text-muted-foreground">Apply from overseas.</p>
                </div>
              </div>
              <div className="space-y-3">
                <Button variant="outline" className="w-full justify-start bg-transparent">
                  <ExternalLink className="h-4 w-4 mr-2" />
                  Instructions
                </Button>
                <Button asChild className="w-full bg-primary hover:bg-primary/90">
                  <Link to="/login">
                    Apply Passport
                    <ExternalLink className="h-4 w-4 ml-2" />
                  </Link>
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* Local Applicants */}
          <Card className="bg-white/95 backdrop-blur-sm border-border shadow-lg hover:shadow-xl transition-shadow">
            <CardContent className="p-8">
              <div className="flex items-center mb-6">
                <div className="bg-primary/10 p-3 rounded-full mr-4">
                  <MapPin className="h-8 w-8 text-primary" />
                </div>
                <div>
                  <h3 className="text-xl font-semibold text-foreground font-sans">Applicants residing in Farajaland</h3>
                  <p className="text-muted-foreground">Apply from Farajaland.</p>
                </div>
              </div>
              <div className="space-y-3">
                <Button variant="outline" className="w-full justify-start bg-transparent">
                  <ExternalLink className="h-4 w-4 mr-2" />
                  Instructions
                </Button>
                <Button asChild className="w-full bg-primary hover:bg-primary/90">
                  <Link to="/login">
                    Apply Passport
                    <ExternalLink className="h-4 w-4 ml-2" />
                  </Link>
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
