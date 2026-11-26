import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { Download, Loader2 } from 'lucide-react';

interface LoadDetailsAlertProps {
  onLoadDetails: () => void;
  loading: boolean;
}

/**
 * Component that displays a descriptive alert and "Load My Details" button.
 * Allows users to auto-fill their personal information from the national database.
 *
 * @param onLoadDetails - Callback function when the button is clicked
 * @param loading - Loading state to show spinner and disable button
 */
export function LoadDetailsAlert({ onLoadDetails, loading }: LoadDetailsAlertProps) {
  return (
    <Alert className="mb-6 border-primary/50 bg-primary/5">
      <Download className="h-5 w-5 text-primary" />
      <AlertTitle className="text-base font-semibold">Auto-fill Your Information</AlertTitle>
      <AlertDescription className="mt-2">
        <p className="text-sm text-muted-foreground mb-3">
          We can automatically fill in your personal details from the National Data Exchange (NDX)
          system using your NIC number. This will save you time and ensure accuracy.
        </p>
        <Button
          onClick={onLoadDetails}
          disabled={loading}
          variant="default"
          size="sm"
          className="w-full sm:w-auto"
        >
          {loading ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Loading Details...
            </>
          ) : (
            <>
              <Download className="mr-2 h-4 w-4" />
              Load My Details
            </>
          )}
        </Button>
      </AlertDescription>
    </Alert>
  );
}
