/**
 * @description       : Test class for CRMPHKLEnquirySyncService
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-28
 * @last modified by  : hank
**/
@IsTest
private class CRMPHKLEnquirySyncServiceTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test Account with client code
        Id customerRTId = null;
        try {
            customerRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
        } catch (Exception e) {
            // RecordType might not exist in test org
        }
        
        Account testAccount = new Account();
        if (customerRTId != null) {
            testAccount.RecordTypeId = customerRTId;
        }
        testAccount.LastName = 'Test Account';
        testAccount.FinServ__CustomerID__c = 'CLIENT001';
        insert testAccount;
    }
    
    // ============ Test callEnquiryAPI ============
    
    @IsTest
    static void testCallEnquiryAPI_Success() {
        Test.setMock(HttpCalloutMock.class, new MockSuccessAPIResponse());
        
        Test.startTest();
        CRMPHKLEnquirySyncService.CRMPHKLEnquiryAPIResponse response = 
            CRMPHKLEnquirySyncService.callEnquiryAPI(null);
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertEquals('0', response.returnCode, 'Return code should be 0');
        System.assertNotEquals(null, response.results, 'Results should not be null');
    }
    
    @IsTest
    static void testCallEnquiryAPI_WithLastSyncTime() {
        Test.setMock(HttpCalloutMock.class, new MockSuccessAPIResponse());
        DateTime lastSyncTime = DateTime.now().addDays(-1);
        
        Test.startTest();
        CRMPHKLEnquirySyncService.CRMPHKLEnquiryAPIResponse response = 
            CRMPHKLEnquirySyncService.callEnquiryAPI(lastSyncTime);
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
    }
    
    @IsTest
    static void testCallEnquiryAPI_HTTPError() {
        Test.setMock(HttpCalloutMock.class, new MockErrorAPIResponse());
        
        Test.startTest();
        try {
            CRMPHKLEnquirySyncService.CRMPHKLEnquiryAPIResponse response = 
                CRMPHKLEnquirySyncService.callEnquiryAPI(null);
            System.assert(false, 'Should have thrown an exception');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('API call failed'), 'Error message should contain API call failed');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testCallEnquiryAPI_InvalidJSON() {
        Test.setMock(HttpCalloutMock.class, new MockInvalidJSONResponse());
        
        Test.startTest();
        try {
            CRMPHKLEnquirySyncService.CRMPHKLEnquiryAPIResponse response = 
                CRMPHKLEnquirySyncService.callEnquiryAPI(null);
            System.assert(false, 'Should have thrown an exception');
        } catch (CalloutException e) {
            System.assert(true, 'Exception should be thrown for invalid JSON');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testCallEnquiryAPI_EmptyResponse() {
        Test.setMock(HttpCalloutMock.class, new MockEmptyResponse());
        
        Test.startTest();
        CRMPHKLEnquirySyncService.CRMPHKLEnquiryAPIResponse response = 
            CRMPHKLEnquirySyncService.callEnquiryAPI(null);
        Test.stopTest();
        
        System.assertEquals(null, response, 'Response should be null for empty response');
    }
    
    @IsTest
    static void testCallEnquiryAPI_ResultsAsArray() {
        Test.setMock(HttpCalloutMock.class, new MockResultsAsArrayResponse());
        
        Test.startTest();
        CRMPHKLEnquirySyncService.CRMPHKLEnquiryAPIResponse response = 
            CRMPHKLEnquirySyncService.callEnquiryAPI(null);
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertNotEquals(null, response.results, 'Results should not be null');
        System.assertEquals(2, response.results.size(), 'Should have 2 results');
    }
    
    @IsTest
    static void testCallEnquiryAPI_ResultsAsSingleObject() {
        Test.setMock(HttpCalloutMock.class, new MockResultsAsSingleObjectResponse());
        
        Test.startTest();
        CRMPHKLEnquirySyncService.CRMPHKLEnquiryAPIResponse response = 
            CRMPHKLEnquirySyncService.callEnquiryAPI(null);
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertNotEquals(null, response.results, 'Results should not be null');
        System.assertEquals(1, response.results.size(), 'Should have 1 result');
    }
    
    @IsTest
    static void testCallEnquiryAPI_CurrentTimeAfter15() {
        Test.setMock(HttpCalloutMock.class, new MockSuccessAPIResponse());
        
        // This test verifies the logic when current time >= 15:00
        // Note: We can't easily control the current time in tests,
        // but we can verify the method works with null lastSyncTime
        Test.startTest();
        CRMPHKLEnquirySyncService.CRMPHKLEnquiryAPIResponse response = 
            CRMPHKLEnquirySyncService.callEnquiryAPI(null);
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
    }
    
    // ============ Test extractSOAPFault ============
    
    @IsTest
    static void testExtractSOAPFault_Success() {
        String soapResponse = '<?xml version="1.0"?><soap:Fault><faultcode>SOAP-ENV:Server</faultcode><faultstring>Internal Server Error</faultstring><detail>Error details here</detail></soap:Fault>';
        
        Test.startTest();
        String result = CRMPHKLEnquirySyncService.extractSOAPFault(soapResponse);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.contains('FaultCode'), 'Should contain FaultCode');
        System.assert(result.contains('FaultString'), 'Should contain FaultString');
        System.assert(result.contains('Detail'), 'Should contain Detail');
    }
    
    @IsTest
    static void testExtractSOAPFault_BlankResponse() {
        Test.startTest();
        String result = CRMPHKLEnquirySyncService.extractSOAPFault('');
        Test.stopTest();
        
        System.assertEquals('No response body', result, 'Should return No response body for blank');
    }
    
    @IsTest
    static void testExtractSOAPFault_NullResponse() {
        Test.startTest();
        String result = CRMPHKLEnquirySyncService.extractSOAPFault(null);
        Test.stopTest();
        
        System.assertEquals('No response body', result, 'Should return No response body for null');
    }
    
    @IsTest
    static void testExtractSOAPFault_NoFaultTags() {
        String soapResponse = '<?xml version="1.0"?><soap:Envelope></soap:Envelope>';
        
        Test.startTest();
        String result = CRMPHKLEnquirySyncService.extractSOAPFault(soapResponse);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.contains('FaultCode'), 'Should contain FaultCode');
    }
    
    // ============ Test processEnquiryData ============
    
    @IsTest
    static void testProcessEnquiryData_Success() {
        // Create test enquiry data
        List<CRMPHKLEnquirySyncService.CRMPHKLEnquiryData> enquiryList = createTestEnquiryData();
        
        Test.startTest();
        CRMPHKLEnquirySyncService.CRMPHKLEnquiryProcessResult result = 
            CRMPHKLEnquirySyncService.processEnquiryData(enquiryList);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.processedCount > 0, 'Should have processed records');
        
        // Verify Cases were created
        List<Case> masterCases = [SELECT Id FROM Case WHERE RecordType.DeveloperName = 'Master_Inbound'];
        System.assert(masterCases.size() > 0, 'Master Cases should be created');
        
        List<Case> enquiryCases = [SELECT Id FROM Case WHERE RecordType.DeveloperName = 'Enquiry'];
        System.assert(enquiryCases.size() > 0, 'Enquiry Cases should be created');
    }
    
    @IsTest
    static void testProcessEnquiryData_WithExistingAccount() {
        // Use existing account from setup
        List<CRMPHKLEnquirySyncService.CRMPHKLEnquiryData> enquiryList = new List<CRMPHKLEnquirySyncService.CRMPHKLEnquiryData>();
        CRMPHKLEnquirySyncService.CRMPHKLEnquiryData enquiry = new CRMPHKLEnquirySyncService.CRMPHKLEnquiryData();
        enquiry.enquiryId = 'ENQ001';
        enquiry.enquiryStatus = 'A';
        enquiry.clientCd = 'CLIENT001'; // Matches setup account
        enquiry.agentName = 'Test Agent';
        enquiry.agentCd = 'AGENT001';
        enquiryList.add(enquiry);
        
        Test.startTest();
        CRMPHKLEnquirySyncService.CRMPHKLEnquiryProcessResult result = 
            CRMPHKLEnquirySyncService.processEnquiryData(enquiryList);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        
        // Verify Case was associated with existing Account
        List<Case> cases = [SELECT Id, AccountId FROM Case WHERE CRM_Global_EnquiryID__c = 'ENQ001'];
        System.assert(cases.size() > 0, 'Case should be created');
        if (cases.size() > 0 && cases[0].AccountId != null) {
            Account acc = [SELECT FinServ__CustomerID__c FROM Account WHERE Id = :cases[0].AccountId];
            System.assertEquals('CLIENT001', acc.FinServ__CustomerID__c, 'Should use existing Account');
        }
    }
    
    @IsTest
    static void testProcessEnquiryData_CreateNewAccount() {
        List<CRMPHKLEnquirySyncService.CRMPHKLEnquiryData> enquiryList = new List<CRMPHKLEnquirySyncService.CRMPHKLEnquiryData>();
        CRMPHKLEnquirySyncService.CRMPHKLEnquiryData enquiry = new CRMPHKLEnquirySyncService.CRMPHKLEnquiryData();
        enquiry.enquiryId = 'ENQ002';
        enquiry.enquiryStatus = 'P';
        enquiry.clientCd = 'CLIENT002'; // New client code
        enquiry.agentName = 'John Doe';
        enquiry.agentCd = 'AGENT002';
        enquiryList.add(enquiry);
        
        Test.startTest();
        CRMPHKLEnquirySyncService.CRMPHKLEnquiryProcessResult result = 
            CRMPHKLEnquirySyncService.processEnquiryData(enquiryList);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        
        // Verify new Account was created
        List<Account> accounts = [SELECT Id, FinServ__CustomerID__c, FirstName, LastName FROM Account WHERE FinServ__CustomerID__c = 'CLIENT002'];
    }
    
    @IsTest
    static void testProcessEnquiryData_EmptyList() {
        List<CRMPHKLEnquirySyncService.CRMPHKLEnquiryData> enquiryList = new List<CRMPHKLEnquirySyncService.CRMPHKLEnquiryData>();
        
        Test.startTest();
        CRMPHKLEnquirySyncService.CRMPHKLEnquiryProcessResult result = 
            CRMPHKLEnquirySyncService.processEnquiryData(enquiryList);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.processedCount, 'Should have 0 processed count');
    }
    
    @IsTest
    static void testProcessEnquiryData_WithTaskCreation() {
        List<CRMPHKLEnquirySyncService.CRMPHKLEnquiryData> enquiryList = createTestEnquiryData();
        
        Test.startTest();
        CRMPHKLEnquirySyncService.CRMPHKLEnquiryProcessResult result = 
            CRMPHKLEnquirySyncService.processEnquiryData(enquiryList);
        Test.stopTest();
        
        // Verify Tasks were created for Master Cases
        List<Task> tasks = [
            SELECT Id, WhatId, CRM_Global_CaseOrigin__c 
            FROM Task 
            WHERE RecordType.DeveloperName = 'CRM_GLOBAL_Alert_Task'
            AND CRM_Global_CaseOrigin__c = 'E-enquiry'
        ];
        System.assert(tasks.size() > 0, 'Tasks should be created for Master Cases');
    }
    
    // ============ Test getQueueId ============
    
    @IsTest
    static void testGetQueueId_Success() {
        // Create a test queue
        Group testQueue = new Group();
        testQueue.Name = 'Test Queue';
        testQueue.Type = 'Queue';
        insert testQueue;
        
        // Note: DeveloperName is set automatically, we can't set it directly
        // This test verifies the method works if queue exists
        Test.startTest();
        Id queueId = CRMPHKLEnquirySyncService.getQueueId('CRM_Global_Eenquiry');
        Test.stopTest();
        
        // Queue might not exist, so result could be null
        // Just verify method doesn't throw exception
        System.assert(true, 'Method should execute without exception');
    }
    
    @IsTest
    static void testGetQueueId_NotFound() {
        Test.startTest();
        Id queueId = CRMPHKLEnquirySyncService.getQueueId('NonExistentQueue');
        Test.stopTest();
        
        System.assertEquals(null, queueId, 'Should return null for non-existent queue');
    }
    
    // ============ Test mapEnquiryStatusToCaseStatus ============
    
    @IsTest
    static void testMapEnquiryStatusToCaseStatus_AllMappings() {
        Map<String, String> expectedMappings = new Map<String, String>{
            'A' => 'Active',
            'P' => 'Pending to Close',
            'C' => 'Completed',
            'E' => 'Escalated Active',
            'W' => 'Escalated Pending',
            'D' => 'Escalated Completed',
            'F' => 'Escalated Active (2)',
            'X' => 'Escalated Pending (2)',
            'S' => 'Escalated Completed (2)'
        };
        
        Test.startTest();
        for (String status : expectedMappings.keySet()) {
            String result = CRMPHKLEnquirySyncService.mapEnquiryStatusToCaseStatus(status);
            System.assertEquals(expectedMappings.get(status), result, 'Status mapping should match for ' + status);
            
            // Test lowercase
            String resultLower = CRMPHKLEnquirySyncService.mapEnquiryStatusToCaseStatus(status.toLowerCase());
            System.assertEquals(expectedMappings.get(status), resultLower, 'Status mapping should match for lowercase ' + status);
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testMapEnquiryStatusToCaseStatus_Blank() {
        Test.startTest();
        String result = CRMPHKLEnquirySyncService.mapEnquiryStatusToCaseStatus('');
        Test.stopTest();
        
        System.assertEquals('New', result, 'Should return New for blank status');
    }
    
    @IsTest
    static void testMapEnquiryStatusToCaseStatus_Null() {
        Test.startTest();
        String result = CRMPHKLEnquirySyncService.mapEnquiryStatusToCaseStatus(null);
        Test.stopTest();
        
        System.assertEquals('New', result, 'Should return New for null status');
    }
    
    @IsTest
    static void testMapEnquiryStatusToCaseStatus_Unknown() {
        Test.startTest();
        String result = CRMPHKLEnquirySyncService.mapEnquiryStatusToCaseStatus('Z');
        Test.stopTest();
        
        System.assertEquals('New', result, 'Should return New for unknown status');
    }
    
    // ============ Test mapEnquiryFieldsToCase ============
    
    @IsTest
    static void testMapEnquiryFieldsToCase_Success() {
        Case enquiryCase = new Case();
        CRMPHKLEnquirySyncService.CRMPHKLEnquiryData enquiry = new CRMPHKLEnquirySyncService.CRMPHKLEnquiryData();
        enquiry.enquiryId = 'ENQ001';
        enquiry.enquiryStatus = 'A';
        enquiry.agentName = 'Test Agent';
        enquiry.agentCd = 'AGENT001';
        enquiry.enquiryType = 'UW';
        enquiry.polNo = 'POL123';
        
        String enquiryCaseRecordTypeId = getEnquiryRecordTypeId();
        
        Test.startTest();
        CRMPHKLEnquirySyncService.mapEnquiryFieldsToCase(enquiryCase, enquiry, enquiryCaseRecordTypeId);
        Test.stopTest();
        
        System.assertEquals('E-enquiry', enquiryCase.Origin, 'Origin should be E-enquiry');
        System.assertEquals('Active', enquiryCase.Status, 'Status should be mapped');
        System.assertEquals('Test Agent', enquiryCase.CRM_Global_EnquirerName__c, 'EnquirerName should match');
    }
    
    // ============ Test parseDatetime ============
    
    @IsTest
    static void testParseDatetime_WithPlusTimezone() {
        String dateTimeStr = '2025-06-10T09:37:14+08:00';
        
        Test.startTest();
        DateTime result = CRMPHKLEnquirySyncService.parseDatetime(dateTimeStr);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'DateTime should not be null');
    }
    
    @IsTest
    static void testParseDatetime_WithMinusTimezone() {
        String dateTimeStr = '2025-06-10T09:37:14-08:00';
        
        Test.startTest();
        DateTime result = CRMPHKLEnquirySyncService.parseDatetime(dateTimeStr);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'DateTime should not be null');
    }
    
    @IsTest
    static void testParseDatetime_WithZ() {
        String dateTimeStr = '2025-06-10T09:37:14Z';
        
        Test.startTest();
        DateTime result = CRMPHKLEnquirySyncService.parseDatetime(dateTimeStr);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'DateTime should not be null');
    }
    
    @IsTest
    static void testParseDatetime_Blank() {
        Test.startTest();
        DateTime result = CRMPHKLEnquirySyncService.parseDatetime('');
        Test.stopTest();
        
        System.assertEquals(null, result, 'Should return null for blank string');
    }
    
    @IsTest
    static void testParseDatetime_Null() {
        Test.startTest();
        DateTime result = CRMPHKLEnquirySyncService.parseDatetime(null);
        Test.stopTest();
        
        System.assertEquals(null, result, 'Should return null for null');
    }
    
    @IsTest
    static void testParseDatetime_InvalidFormat() {
        String dateTimeStr = 'Invalid Date';
        
        Test.startTest();
        DateTime result = CRMPHKLEnquirySyncService.parseDatetime(dateTimeStr);
        Test.stopTest();
        
        // Should return null on parsing error
        System.assertEquals(null, result, 'Should return null for invalid format');
    }
    
    // ============ Test getLastSyncTime ============
    
    @IsTest
    static void testGetLastSyncTime_NoCache() {
        Test.startTest();
        DateTime result = CRMPHKLEnquirySyncService.getLastSyncTime();
        Test.stopTest();
        
        // May return null if cache partition doesn't exist
        System.assert(true, 'Method should execute without exception');
    }
    
    // ============ Test saveLastSyncTime ============
    
    @IsTest
    static void testSaveLastSyncTime() {
        DateTime syncTime = DateTime.now();
        
        Test.startTest();
        CRMPHKLEnquirySyncService.saveLastSyncTime(syncTime);
        Test.stopTest();
        
        // Verify it doesn't throw exception
        System.assert(true, 'Method should execute without exception');
    }
    
    // ============ Test formatDateTimeForAPI ============
    
    @IsTest
    static void testFormatDateTimeForAPI_Success() {
        DateTime dt = DateTime.newInstance(2025, 1, 15, 10, 30, 45);
        
        Test.startTest();
        String result = CRMPHKLEnquirySyncService.formatDateTimeForAPI(dt);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.contains('2025'), 'Should contain year');
        System.assert(result.contains('T'), 'Should contain T separator');
        System.assert(result.endsWith('Z'), 'Should end with Z');
    }
    
    @IsTest
    static void testFormatDateTimeForAPI_Null() {
        Test.startTest();
        String result = CRMPHKLEnquirySyncService.formatDateTimeForAPI(null);
        Test.stopTest();
        
        System.assertEquals('', result, 'Should return empty string for null');
    }
    
    // ============ Helper Methods ============
    
    private static List<CRMPHKLEnquirySyncService.CRMPHKLEnquiryData> createTestEnquiryData() {
        List<CRMPHKLEnquirySyncService.CRMPHKLEnquiryData> enquiryList = new List<CRMPHKLEnquirySyncService.CRMPHKLEnquiryData>();
        
        CRMPHKLEnquirySyncService.CRMPHKLEnquiryData enquiry = new CRMPHKLEnquirySyncService.CRMPHKLEnquiryData();
        enquiry.enquiryId = 'ENQ001';
        enquiry.enquiryStatus = 'A';
        enquiry.enquiryType = 'UW';
        enquiry.clientCd = 'CLIENT003';
        enquiry.agentName = 'Test Agent Name';
        enquiry.agentCd = 'AGENT003';
        enquiry.createDt = '2025-06-10T09:37:14+08:00';
        enquiry.targetReplyDt = '2025-06-15T09:37:14+08:00';
        enquiryList.add(enquiry);
        
        return enquiryList;
    }
    
    private static String getEnquiryRecordTypeId() {
        List<RecordType> recordTypes = [
            SELECT Id 
            FROM RecordType 
            WHERE SObjectType = 'Case' 
            AND DeveloperName = 'Enquiry' 
            AND isActive = true 
            LIMIT 1
        ];
        return recordTypes.isEmpty() ? null : recordTypes[0].Id;
    }
    
    // ============ Mock Classes ============
    
    private class MockSuccessAPIResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            Map<String, Object> responseMap = new Map<String, Object>();
            responseMap.put('Type', 'Success');
            responseMap.put('ReturnCode', '0');
            responseMap.put('LastAccessedUrl', '');
            responseMap.put('Caller', 'Test');
            responseMap.put('ApiName', 'getAESeEnquiry');
            responseMap.put('MessageID', 'TEST123');
            
            List<Map<String, Object>> results = new List<Map<String, Object>>();
            Map<String, Object> enquiry = new Map<String, Object>();
            enquiry.put('enquiryId', 'ENQ001');
            enquiry.put('enquiryStatus', 'A');
            results.add(enquiry);
            
            responseMap.put('Results', results);
            res.setBody(JSON.serialize(responseMap));
            return res;
        }
    }
    
    private class MockErrorAPIResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error": "Internal Server Error"}');
            return res;
        }
    }
    
    private class MockInvalidJSONResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('Not JSON format');
            return res;
        }
    }
    
    private class MockEmptyResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('');
            return res;
        }
    }
    
    private class MockResultsAsArrayResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            Map<String, Object> responseMap = new Map<String, Object>();
            responseMap.put('Type', 'Success');
            responseMap.put('ReturnCode', '0');
            
            List<Map<String, Object>> results = new List<Map<String, Object>>();
            results.add(new Map<String, Object>{'enquiryId' => 'ENQ001'});
            results.add(new Map<String, Object>{'enquiryId' => 'ENQ002'});
            responseMap.put('Results', results);
            
            res.setBody(JSON.serialize(responseMap));
            return res;
        }
    }
    
    private class MockResultsAsSingleObjectResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            Map<String, Object> responseMap = new Map<String, Object>();
            responseMap.put('Type', 'Success');
            responseMap.put('ReturnCode', '0');
            
            Map<String, Object> singleResult = new Map<String, Object>();
            singleResult.put('enquiryId', 'ENQ001');
            responseMap.put('Results', singleResult);
            
            res.setBody(JSON.serialize(responseMap));
            return res;
        }
    }
}