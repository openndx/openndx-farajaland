/**
 * Utility to map NDX PersonInfo API response to passport application form structure
 */

export interface PersonInfoData {
  fullName: string;
  name: string;
  otherNames: string;
  address: string;
  profession: string;
  dateOfBirth: string; // ISO format: "2020-04-03"
  sex: string; // "Male" or "Female"
  birthInfo: {
    birthRegistrationNumber: string;
    birthPlace: string;
    district: string;
  };
}

export interface PersonalFormData {
  nicNumber: string;
  surname: string;
  otherNames: string;
  permanentAddress: string;
  district: string;
  birthDay: string;
  birthMonth: string;
  birthYear: string;
  birthCertificateNumber: string;
  birthCertificateDistrict: string;
  placeOfBirth: string;
  sex: string;
  profession: string;
}

/**
 * Maps NDX PersonInfo data to the passport application form structure.
 * Handles all necessary type conversions and field transformations.
 *
 * @param personInfo - Data from NDX GraphQL API
 * @param currentNic - Current NIC entered by user (preserved)
 * @returns Partial form data object ready to update form state
 */
export function mapPersonInfoToFormData(
  personInfo: PersonInfoData,
  currentNic: string
): Partial<PersonalFormData> {
  // Parse date of birth from ISO format (e.g., "2020-04-03" -> year, month, day)
  const dobParts = personInfo.dateOfBirth.split('-');
  const year = dobParts[0];
  const month = dobParts[1]; // Already zero-padded (e.g., "04")
  const day = dobParts[2];

  // Extract surname from fullName
  // Assumption: Last word in fullName is the surname
  const nameParts = personInfo.fullName.trim().split(' ');
  const surname = nameParts[nameParts.length - 1];

  // If otherNames is not provided, derive from fullName by taking all parts except surname
  const otherNames =
    personInfo.otherNames ||
    (nameParts.length > 1 ? nameParts.slice(0, -1).join(' ') : '');

  // Map sex to lowercase for radio button values ("Male" -> "male")
  const sex = personInfo.sex.toLowerCase();

  // Map district to lowercase for select dropdown values
  const district = personInfo.birthInfo.district.toLowerCase();
  const birthCertificateDistrict = personInfo.birthInfo.district.toLowerCase();

  return {
    nicNumber: currentNic,
    surname,
    otherNames,
    permanentAddress: personInfo.address,
    district,
    birthDay: day,
    birthMonth: month,
    birthYear: year,
    birthCertificateNumber: personInfo.birthInfo.birthRegistrationNumber,
    birthCertificateDistrict,
    placeOfBirth: personInfo.birthInfo.birthPlace,
    sex,
    profession: personInfo.profession,
  };
}
