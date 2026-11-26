import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Header } from "../components/header";
import { MultiStepForm } from "../components/multi-step-form";
import { PersonalInfoStep } from "../components/form-steps/personal-info-step";
import { ReviewDeclarationStep } from "../components/form-steps/review-declaration-step";

interface User {
  name: string;
  nic: string;
  fudiNumber?: string;
  mobileNumber: string;
  email: string;
  authenticated: boolean;
  loginTime: string;
}

export default function Apply() {
  const navigate = useNavigate();
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    // Check if user is authenticated
    const storedUser = localStorage.getItem("fudi_user");
    if (storedUser) {
      setUser(JSON.parse(storedUser));
    } else {
      // Redirect to login if not authenticated
      navigate("/login");
    }
  }, [navigate]);

  const handleSubmit = (data: Record<string, any>) => {
    // Store the application data in localStorage for the success page
    const submissionData = {
      ...user,
      ...data["personal-info"],
      ...data["review-declaration"],
      submittedAt: new Date().toISOString(),
    };

    localStorage.setItem("submitted_application", JSON.stringify(submissionData));

    // Redirect to success page
    navigate("/success", { replace: true });
  };

  if (!user) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p>Loading...</p>
      </div>
    );
  }

  const steps = [
    {
      id: "personal-info",
      title: "Personal Information",
      description: "Enter your personal details",
      component: <PersonalInfoStep />,
    },
    {
      id: "review-declaration",
      title: "Review & Declaration",
      description: "Review your application and sign",
      component: <ReviewDeclarationStep />,
    },
  ];

  return (
    <div className="min-h-screen bg-background">
      <Header />
      <MultiStepForm steps={steps} onSubmit={handleSubmit} />
    </div>
  );
}
