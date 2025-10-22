@isTest
private class CRMPHKLCreateRequestCaseControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create test Users
        List<User> testUsers = new List<User>();
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        for (Integer i = 1; i <= 3; i++) {
            testUsers.add(new User(
                FirstName = 'Test',
                LastName = 'User' + i,
                Email = 'testuser' + i + '@test.com',
                Username = 'testuser' + i + '@test.com.test',
                Alias = 'tuser' + i,
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = standardProfile.Id
            ));
        }
        insert testUsers;

        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;

        // Create test Case for Parent Case scenario
        Case parentCase = new Case(
            Subject = 'Parent Test Case',
            Status = 'New',
            Origin = 'Phone'
        );
        insert parentCase;

        // Create Request Record Type if it doesn't exist
        List<RecordType> existingRecordTypes = [
            SELECT Id 
            FROM RecordType 
            WHERE SObjectType = 'Case' 
            AND Name = 'Request' 
            AND IsActive = true
        ];
        
        if (existingRecordTypes.isEmpty()) {
            // Create a custom record type for testing
            // Note: This might require additional setup in a real org
        }
    }

    // Test getPicklistValues method
    @isTest
    static void testGetPicklistValues_Success() {
        List<String> fieldNames = new List<String>{'Case.Status'};
        
        Test.startTest();
        Map<String, List<Map<String, String>>> result = CRMPHKLCreateRequestCaseController.getPicklistValues(fieldNames);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('Case_Status'), 'Result should contain Case_Status key');
        System.assertNotEquals(0, result.get('Case_Status').size(), 'Status options should not be empty');
    }

    @isTest
    static void testGetPicklistValues_EmptyList() {
        List<String> fieldNames = new List<String>();
        
        Test.startTest();
        Map<String, List<Map<String, String>>> result = CRMPHKLCreateRequestCaseController.getPicklistValues(fieldNames);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Result should be empty for empty input');
    }

    @isTest
    static void testGetPicklistValues_MultipleFields() {
        List<String> fieldNames = new List<String>{'Case.Status', 'Case.Priority'};
        
        Test.startTest();
        Map<String, List<Map<String, String>>> result = CRMPHKLCreateRequestCaseController.getPicklistValues(fieldNames);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('Case_Status'), 'Result should contain Case_Status key');
        System.assert(result.containsKey('Case_Priority'), 'Result should contain Case_Priority key');
    }

    // Test searchUsers method
    @isTest
    static void testSearchUsers_Success() {
        Test.startTest();
        List<User> result = CRMPHKLCreateRequestCaseController.searchUsers('Test');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Should return at least one user');
        System.assertEquals(true, result[0].IsActive, 'Returned users should be active');
    }

    @isTest
    static void testSearchUsers_BlankSearchTerm() {
        Test.startTest();
        List<User> result = CRMPHKLCreateRequestCaseController.searchUsers('');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return empty list for blank search term');
    }

    @isTest
    static void testSearchUsers_NullSearchTerm() {
        Test.startTest();
        List<User> result = CRMPHKLCreateRequestCaseController.searchUsers(null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return empty list for null search term');
    }

    @isTest
    static void testSearchUsers_NoResults() {
        Test.startTest();
        List<User> result = CRMPHKLCreateRequestCaseController.searchUsers('NonExistentUser');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return empty list for non-existent user');
    }

    // Test getDueDatetime method
    @isTest
    static void testGetDueDatetime_Success() {
        Test.startTest();
        String result = CRMPHKLCreateRequestCaseController.getDueDatetime('TestRequestType', 'New');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        // Note: The actual format depends on CRMGlobalCaseTATService implementation
    }

    @isTest
    static void testGetDueDatetime_BlankRequestType() {
        Test.startTest();
        String result = CRMPHKLCreateRequestCaseController.getDueDatetime('', 'New');
        Test.stopTest();
        
        System.assertEquals('', result, 'Should return empty string for blank request type');
    }

    @isTest
    static void testGetDueDatetime_BlankCaseStatus() {
        Test.startTest();
        String result = CRMPHKLCreateRequestCaseController.getDueDatetime('TestRequestType', '');
        Test.stopTest();
        
        System.assertEquals('', result, 'Should return empty string for blank case status');
    }

    @isTest
    static void testGetDueDatetime_BothBlank() {
        Test.startTest();
        String result = CRMPHKLCreateRequestCaseController.getDueDatetime('', '');
        Test.stopTest();
        
        System.assertEquals('', result, 'Should return empty string for blank parameters');
    }

    // Test createRequestCase method
    @isTest
    static void testCreateRequestCase_Success() {
        CRMPHKLCreateRequestCaseController.RequestDataWrapper requestData = new CRMPHKLCreateRequestCaseController.RequestDataWrapper();
        requestData.requestType = 'Locate Payment';
        requestData.status = 'New';
        requestData.policyNumber = 'POL123456';
        requestData.nameOfAssured = 'Test Assured';
        requestData.amount = '1000.00';
        requestData.refundDate = '2024-01-01';
        
        String requestDataJson = JSON.serialize(requestData);
        
        Test.startTest();
        CRMPHKLCreateRequestCaseController.CreateResult result = 
            CRMPHKLCreateRequestCaseController.createRequestCase(requestDataJson);
        Test.stopTest();
        
        System.assertEquals(true, result.isSuccess, 'Create should be successful');
        System.assertNotEquals(null, result.caseId, 'Case ID should not be null');
        System.assertNotEquals(null, result.caseNumber, 'Case Number should not be null');
        
        // Verify the case was created
        Case createdCase = [SELECT Id, Status, CRM_Global_RequestCaseType__c, CRM_Global_PolicyNumber__c 
                          FROM Case WHERE Id = :result.caseId];
        System.assertEquals('New', createdCase.Status, 'Status should match');
        System.assertEquals('Locate Payment', createdCase.CRM_Global_RequestCaseType__c, 'Request type should match');
    }

    @isTest
    static void testCreateRequestCase_WithRecipients() {
        User testUser = [SELECT Id FROM User WHERE LastName LIKE 'User%' LIMIT 1];
        Case parentCase = [SELECT Id FROM Case LIMIT 1];
        
        CRMPHKLCreateRequestCaseController.RequestDataWrapper requestData = new CRMPHKLCreateRequestCaseController.RequestDataWrapper();
        requestData.requestType = 'General Inquiry';
        requestData.requestEnquiryCase = parentCase.Id;
        requestData.recipient1 = testUser.Id;
        requestData.recipient1Department = 'Test Department';
        requestData.requestSummary1 = 'Test Summary';
        requestData.autoProceed = true;
        
        String requestDataJson = JSON.serialize(requestData);
        
        Test.startTest();
        CRMPHKLCreateRequestCaseController.CreateResult result = 
            CRMPHKLCreateRequestCaseController.createRequestCase(requestDataJson);
        Test.stopTest();
        
        System.assertEquals(true, result.isSuccess, 'Create should be successful');
        
        // Verify the case was created with recipient
        Case createdCase = [SELECT Id, OwnerId, Status, ParentId, CRM_Global_AssignedDepartment_1__c 
                          FROM Case WHERE Id = :result.caseId];
        System.assertEquals(testUser.Id, createdCase.OwnerId, 'Owner should match recipient1');
        System.assertEquals('1st Round Processing', createdCase.Status, 'Status should be updated for recipient');
        System.assertEquals(parentCase.Id, createdCase.ParentId, 'Parent case should match');
    }

    @isTest
    static void testCreateRequestCase_EmptyJson() {
        Test.startTest();
        CRMPHKLCreateRequestCaseController.CreateResult result = 
            CRMPHKLCreateRequestCaseController.createRequestCase('');
        Test.stopTest();
        
        System.assertEquals(false, result.isSuccess, 'Create should fail for empty JSON');
        System.assert(result.message.contains('Request data cannot be empty'), 'Error message should indicate empty data');
    }

    @isTest
    static void testCreateRequestCase_NullJson() {
        Test.startTest();
        CRMPHKLCreateRequestCaseController.CreateResult result = 
            CRMPHKLCreateRequestCaseController.createRequestCase(null);
        Test.stopTest();
        
        System.assertEquals(false, result.isSuccess, 'Create should fail for null JSON');
        System.assert(result.message.contains('Request data cannot be empty'), 'Error message should indicate empty data');
    }

    @isTest
    static void testCreateRequestCase_InvalidJson() {
        Test.startTest();
        CRMPHKLCreateRequestCaseController.CreateResult result = 
            CRMPHKLCreateRequestCaseController.createRequestCase('invalid json');
        Test.stopTest();
        
        System.assertEquals(false, result.isSuccess, 'Create should fail for invalid JSON');
    }

    @isTest
    static void testCreateRequestCase_DefaultStatus() {
        CRMPHKLCreateRequestCaseController.RequestDataWrapper requestData = new CRMPHKLCreateRequestCaseController.RequestDataWrapper();
        requestData.requestType = 'General Inquiry';
        // Don't set status to test default
        
        String requestDataJson = JSON.serialize(requestData);
        
        Test.startTest();
        CRMPHKLCreateRequestCaseController.CreateResult result = 
            CRMPHKLCreateRequestCaseController.createRequestCase(requestDataJson);
        Test.stopTest();
        
        System.assertEquals(true, result.isSuccess, 'Create should be successful');
        
        // Verify default status
        Case createdCase = [SELECT Id, Status FROM Case WHERE Id = :result.caseId];
        System.assertEquals('New', createdCase.Status, 'Default status should be New');
    }

    @isTest
    static void testCreateRequestCase_WithTwoRecipients() {
        List<User> testUsers = [SELECT Id FROM User WHERE LastName LIKE 'User%' LIMIT 2];
        
        CRMPHKLCreateRequestCaseController.RequestDataWrapper requestData = new CRMPHKLCreateRequestCaseController.RequestDataWrapper();
        requestData.requestType = 'General Inquiry';
        requestData.recipient1 = testUsers[0].Id;
        requestData.recipient1Department = 'Department 1';
        requestData.requestSummary1 = 'Summary 1';
        requestData.recipient2 = testUsers[1].Id;
        requestData.recipient2Department = 'Department 2';
        requestData.requestSummary2 = 'Summary 2';
        
        String requestDataJson = JSON.serialize(requestData);
        
        Test.startTest();
        CRMPHKLCreateRequestCaseController.CreateResult result = 
            CRMPHKLCreateRequestCaseController.createRequestCase(requestDataJson);
        Test.stopTest();
        
        System.assertEquals(true, result.isSuccess, 'Create should be successful');
        
        // Verify the case was created with both recipients
        Case createdCase = [SELECT Id, CRM_Global_Recipient_1__c, CRM_Global_Recipient_2__c,
                          CRM_Global_AssignedDepartment_1__c, CRM_Global_AssignedDepartment_2__c,
                          CRM_Global_RequestSummary_1__c, CRM_Global_RequestSummary_2__c
                          FROM Case WHERE Id = :result.caseId];
        System.assertEquals(testUsers[0].Id, createdCase.CRM_Global_Recipient_1__c, 'Recipient 1 should match');
        System.assertEquals(testUsers[1].Id, createdCase.CRM_Global_Recipient_2__c, 'Recipient 2 should match');
        System.assertEquals('Department 1', createdCase.CRM_Global_AssignedDepartment_1__c, 'Department 1 should match');
        System.assertEquals('Department 2', createdCase.CRM_Global_AssignedDepartment_2__c, 'Department 2 should match');
    }

    // Test wrapper classes
    @isTest
    static void testCreateResultWrapper() {
        CRMPHKLCreateRequestCaseController.CreateResult result = 
            new CRMPHKLCreateRequestCaseController.CreateResult(true, 'Success', 'case123', '00001234');
        
        System.assertEquals(true, result.isSuccess, 'isSuccess should match');
        System.assertEquals('Success', result.message, 'message should match');
        System.assertEquals('case123', result.caseId, 'caseId should match');
        System.assertEquals('00001234', result.caseNumber, 'caseNumber should match');
    }

    @isTest
    static void testRequestDataWrapper() {
        CRMPHKLCreateRequestCaseController.RequestDataWrapper wrapper = new CRMPHKLCreateRequestCaseController.RequestDataWrapper();
        wrapper.requestType = 'Test Type';
        wrapper.status = 'New';
        wrapper.autoProceed = true;
        
        System.assertEquals('Test Type', wrapper.requestType, 'requestType should match');
        System.assertEquals('New', wrapper.status, 'status should match');
        System.assertEquals(true, wrapper.autoProceed, 'autoProceed should match');
    }
}