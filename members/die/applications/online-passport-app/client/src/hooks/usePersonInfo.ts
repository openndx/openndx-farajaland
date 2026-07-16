import {CombinedGraphQLErrors, gql} from '@apollo/client';
import { useAuth } from 'react-oidc-context';
import { useToast } from './use-toast';
import {useLazyQuery} from "@apollo/client/react";

/**
 * GraphQL query to fetch person information from NDX
 */
const GET_PERSON_INFO = gql`
  query GetPersonInfo($nic: String!) {
    personInfo(nic: $nic) {
      fullName
      name
      otherNames
      address
      profession
      dateOfBirth
      sex
      birthInfo {
        birthRegistrationNumber
        birthPlace
        district
      }
    }
  }
`;

export interface PersonInfoData {
  fullName: string;
  name: string;
  otherNames: string;
  address: string;
  profession: string;
  dateOfBirth: string;
  sex: string;
  birthInfo: {
    birthRegistrationNumber: string;
    birthPlace: string;
    district: string;
  };
}

export interface UsePersonInfoResult {
  loadPersonInfo: () => Promise<PersonInfoData | null>;
  loading: boolean;
}

/**
 * Waits for the "consent_granted" message from the consent portal window
 */
function waitForConsentGranted(): Promise<void> {
  return new Promise((resolve) => {
    const handleMessage = (event: MessageEvent) => {
      if (event.data === 'consentGranted') {
        window.removeEventListener('message', handleMessage);
        resolve();
      }
    };

    window.addEventListener('message', handleMessage);
  });
}

/**
 * Custom hook to fetch person information from NDX GraphQL API.
 * Handles loading states, error messages via toast notifications,
 * and graceful degradation if data fetch fails.
 *
 * @returns Object with loadPersonInfo function and loading state
 */
export function usePersonInfo(): UsePersonInfoResult {
  const { toast } = useToast();
  const auth = useAuth();
  const [getPersonInfo, { loading }] = useLazyQuery<{
    personInfo: PersonInfoData;
  }>(GET_PERSON_INFO, {
    fetchPolicy: 'network-only', // Always fetch fresh data, don't use cache
    errorPolicy: 'all',
  });

  const loadPersonInfo = async (): Promise<PersonInfoData | null> => {
      // The logged-in user's identity comes from the OIDC session. The email is
      // used as the person's identifier / NIC (see client .env VITE_OIDC_SCOPE).
      const profile = auth.user?.profile;
      if (!profile) {
        toast({
          title: 'Error',
          description: 'User information not found. Please log in again.',
          variant: 'destructive',
        });
        return null;
      }

      const nic = profile.email || profile.sub;

      if (!nic) {
        toast({
          title: 'Error',
          description: 'NIC number not found in user data.',
          variant: 'destructive',
        });
        return null;
      }

      // Execute GraphQL query with NIC parameter
      const { data, error } = await getPersonInfo({
        variables: { nic },
      });

      // Handle GraphQL errors
      if (error && CombinedGraphQLErrors.is(error)) {
        console.log('GraphQL error:', error?.errors);

        // Check if this is a consent approval error
        const graphQLError = error.errors?.[0];
        if (graphQLError?.extensions?.code === 'CE_NOT_APPROVED') {
          const consentPortalUrl = graphQLError.extensions.consentPortalUrl as string;
          if (consentPortalUrl) {
              // Open consent portal in a new window
            window.open(consentPortalUrl, '_blank');

            // Wait for the "consent_granted" message from the consent portal window
            await waitForConsentGranted();


            // Small delay to ensure server has processed the consent
            await new Promise(resolve => setTimeout(resolve, 500));

            // Retry the query
            return await loadPersonInfo();
          }
        }

        toast({
          title: 'Failed to load details',
          description:
            error.message ||
            'Could not retrieve your information from the national database.',
          variant: 'destructive',
        });
        return null;
      }

      // Handle no data returned
      if (!data?.personInfo) {
        toast({
          title: 'No data found',
          description:
            'No information found for your NIC number in the national database.',
          variant: 'destructive',
        });
        return null;
      }

      return data.personInfo;
  };

  return {
    loadPersonInfo,
    loading,
  };
}
