import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "react-oidc-context";
import { Header } from "../components/header";
import { MultiStepForm } from "../components/multi-step-form";
import { PersonalInfoStep } from "../components/form-steps/personal-info-step";
import { ReviewDeclarationStep } from "../components/form-steps/review-declaration-step";

export default function Apply() {
  const navigate = useNavigate();
  const auth = useAuth();

  useEffect(() => {
    // Send unauthenticated visitors through the OIDC login, returning here after.
    if (!auth.isLoading && !auth.isAuthenticated) {
      void auth.signinRedirect({ state: { returnTo: "/apply" } });
    }
  }, [auth.isLoading, auth.isAuthenticated, auth]);

  const handleSubmit = (data: Record<string, any>) => {
    // Store the application data in localStorage for the success page
    const submissionData = {
      name: auth.user?.profile.name,
      email: auth.user?.profile.email,
      ...data["personal-info"],
      ...data["review-declaration"],
      submittedAt: new Date().toISOString(),
    };

    localStorage.setItem("submitted_application", JSON.stringify(submissionData));

    // Redirect to success page
    navigate("/success", { replace: true });
  };

  if (auth.isLoading || !auth.isAuthenticated) {
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
