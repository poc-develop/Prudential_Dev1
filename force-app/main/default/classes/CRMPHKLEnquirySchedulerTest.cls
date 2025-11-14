/**
 * @description       : Test class for CRMPHKLEnquiryScheduler
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-28
 * @last modified by  : hank
**/
@IsTest
private class CRMPHKLEnquirySchedulerTest {
    
    /**
     * Test the execute method of CRMPHKLEnquiryScheduler
     * Verifies that the scheduler correctly starts the batch job
     */
    @IsTest
    static void testExecute_Success() {
        // Mock HTTP response for API callout
        Test.setMock(HttpCalloutMock.class, new MockEnquiryAPIResponse());
        
        // Create scheduler instance
        CRMPHKLEnquiryScheduler scheduler = new CRMPHKLEnquiryScheduler();
        
        // Create a mock SchedulableContext
        TestSchedulableContext mockContext = new TestSchedulableContext();
        
        Test.startTest();
        // Execute the scheduler
        scheduler.execute(mockContext);
        Test.stopTest();
        
        // Verify that a batch job was queued
        List<AsyncApexJob> batchJobs = [
            SELECT Id, Status, JobType, ApexClass.Name
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex'
            AND ApexClass.Name = 'CRMPHKLEnquirySyncBatch'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        System.assertNotEquals(0, batchJobs.size(), 'Batch job should be queued');
        System.assertEquals('CRMPHKLEnquirySyncBatch', batchJobs[0].ApexClass.Name, 'Batch class name should match');
    }
    
    /**
     * Test scheduler execution with System.schedule
     * This tests the actual scheduling mechanism
     */
    @IsTest
    static void testScheduleJob() {
        // Mock HTTP response for API callout
        Test.setMock(HttpCalloutMock.class, new MockEnquiryAPIResponse());
        
        String cronExpression = '0 0 0 * * ?'; // Daily at midnight
        String jobName = 'Test Enquiry Sync Scheduler';
        
        Test.startTest();
        // Schedule the job
        String jobId = System.schedule(jobName, cronExpression, new CRMPHKLEnquiryScheduler());
        Test.stopTest();
        
        // Verify the scheduled job was created
        List<CronTrigger> scheduledJobs = [
            SELECT Id, CronJobDetail.Name, State, NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        
        System.assertNotEquals(0, scheduledJobs.size(), 'Scheduled job should be created');
        System.assertEquals(jobName, scheduledJobs[0].CronJobDetail.Name, 'Job name should match');
    }
    
    /**
     * Test scheduler with different batch size
     * Note: The current implementation uses a fixed batch size of 200,
     * but this test verifies the scheduler executes without error
     */
    @IsTest
    static void testExecute_MultipleTimes() {
        // Mock HTTP response for API callout
        Test.setMock(HttpCalloutMock.class, new MockEnquiryAPIResponse());
        
        CRMPHKLEnquiryScheduler scheduler = new CRMPHKLEnquiryScheduler();
        TestSchedulableContext mockContext = new TestSchedulableContext();
        
        Test.startTest();
        // Execute multiple times to verify it handles repeated calls
        scheduler.execute(mockContext);
        scheduler.execute(mockContext);
        Test.stopTest();
        
        // Verify multiple batch jobs were queued
        List<AsyncApexJob> batchJobs = [
            SELECT Id, Status, JobType
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex'
            AND ApexClass.Name = 'CRMPHKLEnquirySyncBatch'
            ORDER BY CreatedDate DESC
        ];
        
        System.assert(batchJobs.size() >= 2, 'Multiple batch jobs should be queued');
    }
    
    /**
     * Mock SchedulableContext for testing
     */
    private class TestSchedulableContext implements SchedulableContext {
        public String getTriggerId() {
            return '08e000000000000AAA';
        }
    }
    
    /**
     * Mock HTTP Response for Enquiry API
     */
    private class MockEnquiryAPIResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            // Mock API response structure
            Map<String, Object> responseMap = new Map<String, Object>();
            responseMap.put('Type', 'Success');
            responseMap.put('ReturnCode', '0');
            responseMap.put('LastAccessedUrl', '');
            responseMap.put('Caller', 'Test');
            responseMap.put('ApiName', 'getAESeEnquiry');
            responseMap.put('MessageID', 'TEST123');
            
            // Empty results for simplicity
            responseMap.put('Results', new List<Object>());
            
            res.setBody(JSON.serialize(responseMap));
            return res;
        }
    }
}