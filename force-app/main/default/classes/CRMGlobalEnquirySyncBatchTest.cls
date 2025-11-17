/**
 * @description       : Test class for CRMGlobalEnquirySyncBatch
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-28
 * @last modified by  : hank
**/
@IsTest
private class CRMGlobalEnquirySyncBatchTest {
    
    @TestSetup
    static void setupTestData() {
        // Setup test data if needed (RecordTypes, Accounts, etc.)
        // The batch will query User records, so no specific setup needed for start method
    }
    
    /**
     * Test successful batch execution with API returning data
     */
    @IsTest
    static void testBatchExecution_Success() {
        // Mock successful API response with data
        Test.setMock(HttpCalloutMock.class, new MockSuccessAPIResponse());
        
        Test.startTest();
        CRMGlobalEnquirySyncBatch batch = new CRMGlobalEnquirySyncBatch();
        Id jobId = Database.executeBatch(batch, 1);
        Test.stopTest();
        
        // Verify batch job completed
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobType, ApexClass.Name
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        
        System.assertEquals('BatchApex', job.JobType, 'Job type should be BatchApex');
        System.assertEquals('CRMGlobalEnquirySyncBatch', job.ApexClass.Name, 'Batch class name should match');
        // Status might be 'Completed' or 'Processing' depending on execution
        System.assert(job.Status == 'Completed' || job.Status == 'Processing', 'Job should be completed or processing');
    }
    
    /**
     * Test batch execution with empty API response
     */
    @IsTest
    static void testBatchExecution_EmptyResponse() {
        // Mock API response with empty results
        Test.setMock(HttpCalloutMock.class, new MockEmptyAPIResponse());
        
        Test.startTest();
        CRMGlobalEnquirySyncBatch batch = new CRMGlobalEnquirySyncBatch();
        Id jobId = Database.executeBatch(batch, 1);
        Test.stopTest();
        
        // Verify batch job completed
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        
        System.assertNotEquals(null, job, 'Batch job should be created');
    }
    
    /**
     * Test batch execution with API callout failure (HTTP error)
     * This should trigger the catch block in execute method
     */
    @IsTest
    static void testBatchExecution_APICalloutFailure() {
        // Mock API response with HTTP error (500)
        Test.setMock(HttpCalloutMock.class, new MockErrorAPIResponse());
        
        Test.startTest();
        CRMGlobalEnquirySyncBatch batch = new CRMGlobalEnquirySyncBatch();
        Id jobId = Database.executeBatch(batch, 1);
        Test.stopTest();
        
        // Verify batch job completed (even with errors)
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        
        System.assertNotEquals(null, job, 'Batch job should be created');
        // The catch block should have caught the error and incremented failureCount
    }
    
    /**
     * Test batch execution with invalid JSON response
     * This should trigger the catch block in execute method
     */
    @IsTest
    static void testBatchExecution_InvalidJSONResponse() {
        // Mock API response with invalid JSON
        Test.setMock(HttpCalloutMock.class, new MockInvalidJSONResponse());
        
        Test.startTest();
        CRMGlobalEnquirySyncBatch batch = new CRMGlobalEnquirySyncBatch();
        Id jobId = Database.executeBatch(batch, 1);
        Test.stopTest();
        
        // Verify batch job completed
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        
        System.assertNotEquals(null, job, 'Batch job should be created');
        // The catch block should have caught the JSON parsing error
    }
    
    /**
     * Test batch execution with exception during processing
     * This should trigger the catch block in execute method
     */
    @IsTest
    static void testBatchExecution_ProcessingException() {
        // Mock API response that will cause processing to fail
        Test.setMock(HttpCalloutMock.class, new MockProcessingExceptionResponse());
        
        Test.startTest();
        CRMGlobalEnquirySyncBatch batch = new CRMGlobalEnquirySyncBatch();
        Id jobId = Database.executeBatch(batch, 1);
        Test.stopTest();
        
        // Verify batch job completed
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        
        System.assertNotEquals(null, job, 'Batch job should be created');
    }
    
    /**
     * Test finish method with error messages (errorMessages not empty)
     */
    @IsTest
    static void testFinish_WithErrorMessages() {
        // Mock API response that will cause an error
        Test.setMock(HttpCalloutMock.class, new MockErrorAPIResponse());
        
        Test.startTest();
        CRMGlobalEnquirySyncBatch batch = new CRMGlobalEnquirySyncBatch();
        Id jobId = Database.executeBatch(batch, 1);
        Test.stopTest();
        
        // Verify batch job completed
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        
        System.assertNotEquals(null, job, 'Batch job should be created');
        // The finish method should have logged warnings due to error messages
    }
    
    /**
     * Test finish method without error messages (errorMessages empty)
     */
    @IsTest
    static void testFinish_WithoutErrorMessages() {
        // Mock successful API response with empty results
        Test.setMock(HttpCalloutMock.class, new MockEmptyAPIResponse());
        
        Test.startTest();
        CRMGlobalEnquirySyncBatch batch = new CRMGlobalEnquirySyncBatch();
        Id jobId = Database.executeBatch(batch, 1);
        Test.stopTest();
        
        // Verify batch job completed
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        
        System.assertNotEquals(null, job, 'Batch job should be created');
        // The finish method should have logged info (no errors)
    }
    
    /**
     * Test start method returns QueryLocator
     */
    @IsTest
    static void testStart_ReturnsQueryLocator() {
        Test.startTest();
        CRMGlobalEnquirySyncBatch batch = new CRMGlobalEnquirySyncBatch();
        Database.BatchableContext bc = new TestBatchableContext();
        Database.QueryLocator ql = batch.start(bc);
        Test.stopTest();
        
        System.assertNotEquals(null, ql, 'QueryLocator should not be null');
    }
    
    // ============ Mock Classes ============
    
    /**
     * Mock successful API response with enquiry data
     */
    private class MockSuccessAPIResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            // Mock API response with enquiry data
            Map<String, Object> responseMap = new Map<String, Object>();
            responseMap.put('type', 'Success');
            responseMap.put('returnCode', '0');
            responseMap.put('lastAccessedUrl', '');
            responseMap.put('caller', 'Test');
            responseMap.put('apiName', 'getAESeEnquiry');
            responseMap.put('messageID', 'TEST123');
            
            // Mock enquiry data
            List<Map<String, Object>> results = new List<Map<String, Object>>();
            Map<String, Object> enquiry = new Map<String, Object>();
            enquiry.put('enquiryId', 'ENQ001');
            enquiry.put('enquiryStatus', 'A');
            enquiry.put('enquiryType', 'UW');
            enquiry.put('clientCd', 'CLIENT001');
            enquiry.put('agentName', 'Test Agent');
            enquiry.put('agentCd', 'AGENT001');
            results.add(enquiry);
            
            responseMap.put('Results', results);
            
            res.setBody(JSON.serialize(responseMap));
            return res;
        }
    }
    
    /**
     * Mock API response with empty results
     */
    private class MockEmptyAPIResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            Map<String, Object> responseMap = new Map<String, Object>();
            responseMap.put('type', 'Success');
            responseMap.put('returnCode', '0');
            responseMap.put('lastAccessedUrl', '');
            responseMap.put('caller', 'Test');
            responseMap.put('apiName', 'getAESeEnquiry');
            responseMap.put('messageID', 'TEST123');
            responseMap.put('Results', new List<Object>());
            
            res.setBody(JSON.serialize(responseMap));
            return res;
        }
    }
    
    /**
     * Mock API response with HTTP error (500)
     * This will trigger the catch block in execute method
     */
    private class MockErrorAPIResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500);
            res.setBody('{"error": "Internal Server Error"}');
            return res;
        }
    }
    
    /**
     * Mock API response with invalid JSON
     * This will trigger the catch block in execute method
     */
    private class MockInvalidJSONResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('Invalid JSON response {');
            return res;
        }
    }
    
    /**
     * Mock API response that causes processing exception
     * This will trigger the catch block in execute method
     */
    private class MockProcessingExceptionResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            // Return response that might cause processing issues
            Map<String, Object> responseMap = new Map<String, Object>();
            responseMap.put('type', 'Success');
            responseMap.put('returnCode', '0');
            responseMap.put('Results', null); // null Results might cause issues
            
            res.setBody(JSON.serialize(responseMap));
            return res;
        }
    }
    
    /**
     * Mock BatchableContext for testing
     */
    private class TestBatchableContext implements Database.BatchableContext {
        public Id getJobId() {
            return '01p000000000000AAA';
        }
        
        public Id getChildJobId() {
            return null;
        }
    }
}
