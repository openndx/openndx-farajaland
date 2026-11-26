import ballerina/http;
import ballerina/io;
import ballerina/log;

// --- Enum Definitions ---
// These enums match the schema used in the main GraphQL service.
public enum SEX {
    MALE,
    FEMALE
}

public enum CardStatus {
    ACTIVE,
    EXPIRED,
    LOST,
    CANCELLED
}

public enum CivilStatus {
    MARRIED,
    SINGLE,
    WIDOWED,
    DIVORCED
}

public enum CitizenshipType {
    DESCENT,
    REGISTRATION,
    NATURALIZATION
}

// --- Record Type Definitions ---
// These records define the structure of the data served by this mock API.
type CardInfo record {|
    readonly string cardNumber;
    string issueDate;
    string expiryDate;
    CardStatus cardStatus;
|};

type LostCardReplacementInfo record {|
    string policeStation;
    string complaintDate;
    string complaintNumber;
|};

type CitizenshipInfo record {|
    CitizenshipType citizenshipType;
    string certificateNumber;
    string issueDate;
|};

type ParentInfo record {|
    string fatherName;
    string motherName;
    string fatherNic;
    string motherNic;
|};

public type PersonInfo record {|
    readonly string nic;
    string fullName;
    string otherNames;
    SEX sex;
    string dateOfBirth;
    string permanentAddress;
    string profession;
    string photo;
|};

// The full data structure that this mock API will return.
type PersonData record {|
    *PersonInfo;
|};

// --- Mock Data Store ---
// The data lives in an external `mock_data.json` file so it can be edited
// without touching the code. The path is configurable to support different
// deployment layouts. The file is read fresh on every request (rather than
// cached in memory) so edits to the JSON take effect without a restart.
configurable string MOCK_DATA_PATH = "mock_data.json";

// Reads the mock person records from the JSON file and builds a keyed table.
isolated function loadMockPersonData() returns table<PersonData> key(nic)|error {
    json data = check io:fileReadJson(MOCK_DATA_PATH);
    PersonData[] persons = check data.cloneWithType();
    return table key(nic) from PersonData person in persons
        select person;
}

// --- Mock HTTP Service ---
// This service simulates the Identity Registry's backend REST API.
configurable int PORT = ?;
configurable string MOCK_API_KEY = ?;

// The Identity Registry Adapter (../identity-registry-adapter) calls this service.
isolated service / on new http:Listener(PORT) {

    isolated resource function get person/[string nic](http:Request request) returns PersonData|http:NotFound|http:Unauthorized|error {
        string? apiKey = check request.getHeader("X-API-KEY");
        if apiKey is () || apiKey != MOCK_API_KEY {
            return http:UNAUTHORIZED;
        }
        log:printInfo("Mock Identity Registry API: Request received for person", nic = nic);

        // Read the data fresh from disk on every request so edits to
        // mock_data.json are picked up without restarting the service.
        table<PersonData> key(nic) mockPersonDataTable = check loadMockPersonData();

        // check whether person exists
        if (!mockPersonDataTable.hasKey(nic)) {
            log:printWarn("Mock Identity Registry API: Person not found", nic = nic);
            return http:NOT_FOUND;
        }

        PersonData person = mockPersonDataTable.get(nic);
        log:printInfo("Mock Identity Registry API: Found person, returning data.", nic = nic);
        return person;
    }
}
