import ballerina/graphql;
// import ballerina/graphql.subgraph;
import ballerina/http;
import ballerina/log;
import ballerina/os;

// --- IdentityRegistryClient (client for the Identity Registry API) ---
configurable int port = 9091;

// Read environment variables
configurable string? serviceURL = ();
configurable string? choreoApiKey = ();

// Use the configurable variable if it exists, otherwise fall back to the environment variable
final string SERVICE_URL = serviceURL ?: os:getEnv("CHOREO_MOCK_DRP_CONNECTION_SERVICEURL");
final string CHOREO_API_KEY = choreoApiKey ?: os:getEnv("CHOREO_MOCK_DRP_CONNECTION_APIKEY");

isolated service class IdentityRegistryClient {
    private final http:Client apiClient;
    function init() returns http:ClientError? {
        log:printInfo("IdentityRegistryClient: Initializing", apiKey = CHOREO_API_KEY);
        self.apiClient = check new (SERVICE_URL);
    }
    isolated function getPersonByNic(string nic) returns PersonData|error {
        log:printInfo("IdentityRegistryClient: Fetching person from external API", nic = nic);
        string path = string `/person/${nic}`;
        PersonData| error response = self.apiClient->get(path, {"X-API-KEY": CHOREO_API_KEY});
        if response is error {
            log:printError("IdentityRegistryClient: Error fetching person", nic = nic, err = response.toString());
            return response;
        }
        return response;
    }
}

// This function initializes the IdentityRegistryClient and is used in the main GraphQL service.
public function initializeIdentityRegistryClient() returns IdentityRegistryClient|error {
    return new ();
}

// Shared instance of the IdentityRegistryClient to be used across the service.
// This is initialized once and used for all requests to avoid creating multiple clients.
final IdentityRegistryClient sharedIdentityRegistryClient = check initializeIdentityRegistryClient();

// --- GraphQL Subgraph Service ---
@graphql:ServiceConfig {
    cors: {
        allowOrigins: ["http://localhost:5173"],
        allowCredentials: false,
        allowMethods: ["GET", "POST", "OPTIONS"],
        // allowHeaders: ["CORELATION_ID"],
        // exposeHeaders: ["X-CUSTOM-HEADER"],
        maxAge: 84900
    }
    // graphiql: {
    //     enabled: true,
    //     printUrl: true
    // }
}
isolated service / on new graphql:Listener(
    port,
    host = "0.0.0.0"
) {
    // Fetches the full person data for a given NIC.
    resource function get person(@graphql:ID string|int nic) returns PersonData? {
        PersonData|error personData = sharedIdentityRegistryClient.getPersonByNic(nic.toString());
        if personData is error {
            log:printWarn("Identity Registry adapter: Person not found or error fetching person", nic = nic, err = personData.toString());
            return ();
        }
        // log personData
        log:printInfo("Identity Registry adapter: Fetched person data", nic = nic, personData = personData.toString());
        return personData;
    }
}
