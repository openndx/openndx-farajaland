import ballerina/test;
import ballerina/http;

// --- Mock Function for Client Initialization ---
// This annotation tells the test runner to replace the real 'initializeIdentityRegistryClient'
// function from 'main.bal' with this mock version during the test run.
@test:Mock {
    moduleName: "tmp/identity_registry_adapter",
    functionName: "initializeIdentityRegistryClient"
}
public function mockInitializeIdentityRegistryClient() returns IdentityRegistryClient|error {
    // Create a mock object of the IdentityRegistryClient.
    IdentityRegistryClient mockClient = test:mock(IdentityRegistryClient);

    // Prepare the mock client to respond to the 'getPersonByNic' call for the SUCCESS case.
    test:prepare(mockClient).when("getPersonByNic").withArguments("suresh@ndx.fl").thenReturn(getMockPersonData());

    // Prepare the mock client to respond with an error for the NOT FOUND case.
    test:prepare(mockClient).when("getPersonByNic").withArguments("unknown@ndx.fl").thenReturn(error("Person not found in mock"));
    return mockClient;
}

// Helper function to return the mock data record. This uses the 'PersonData' type from 'types.bal'
// and matches the suresh@ndx.fl record in ../identity-registry-api/mock_data.json.
function getMockPersonData() returns PersonData {
    return {
        nic: "suresh@ndx.fl", fullName: "Suresh Fernando", otherNames: "Suresh", permanentAddress: "105 Main Street, Central City 10000", profession: "Software Engineer", photo: "https://example.com/photo.jpg"
    };
}

// --- Test Suite ---
// The test runner starts the service from 'main.bal' on port 9091. Its schema has a single root
// field, person(nic), which the Orchestration Engine queries as person.<field>.
http:Client testClient = check new ("http://localhost:9091");

@test:Config {}
public function testPersonFound() returns error? {
    string query = "{ person(nic: \"suresh@ndx.fl\") { nic fullName otherNames permanentAddress profession } }";
    json payload = { "query": query };
    json response = check testClient->post("/", payload);
    json expected = { "data": { "person": { "nic": "suresh@ndx.fl", "fullName": "Suresh Fernando", "otherNames": "Suresh", "permanentAddress": "105 Main Street, Central City 10000", "profession": "Software Engineer" } } };
    test:assertEquals(response, expected, "Response mismatch for found person");
}

@test:Config {}
public function testPersonNotFound() returns error? {
    string query = "{ person(nic: \"unknown@ndx.fl\") { fullName } }";
    json payload = { "query": query };
    json response = check testClient->post("/", payload);
    json expected = { "data": { "person": null } };
    test:assertEquals(response, expected, "Response mismatch for not found person");
}
