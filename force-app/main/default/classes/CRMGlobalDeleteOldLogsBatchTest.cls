/**
 * @description       : Test class for CRMGlobalDeleteOldLogsBatch
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-11-07
 * @last modified by  : Franco
**/
@isTest
private class CRMGlobalDeleteOldLogsBatchTest {

    @testSetup
    static void setupData() {
        // 1. Create all records in memory
        for (Integer i = 0; i < 5; i++) {
            CRMGlobalLogManager.addApexInfoLog('Info Apex Log ' + i);
        }
        for (Integer i = 0; i < 5; i++) {
            CRMGlobalLogManager.addApexDebugLog('Debug Apex Log ' + i);
        }
        CRMGlobalLogManager.saveAndFlushLogs();

        // 2. Set CreatedDate for OLD records
        CRM_Global_Housekeeping_Config__mdt houseKeeping = [SELECT Duration_Days__c FROM CRM_Global_Housekeeping_Config__mdt WHERE Object_API_Name__c = 'CRM_Global_ApexLog__c'];
        Integer days = housekeeping.Duration_Days__c.intValue();
        Datetime oldDateTime = Datetime.now().addDays(-days-1);
        
        List<CRM_Global_ApexLog__c> oldLogs = [SELECT Id FROM CRM_Global_ApexLog__c WHERE Severity__c = 'DEBUG'];
        for (CRM_Global_ApexLog__c log : oldLogs) {
            Test.setCreatedDate(log.Id, oldDateTime);
        }
    }

    @isTest
    static void testBatchDeleteLogRecords() {

        Test.startTest();
        // 1. Directly call the execute method
        CRM_Global_Housekeeping_Config__mdt houseKeeping = [SELECT Object_API_Name__c, Duration_Days__c FROM CRM_Global_Housekeeping_Config__mdt WHERE Object_API_Name__c = 'CRM_Global_ApexLog__c'];
        Integer days = housekeeping.Duration_Days__c.intValue();
        String query = 'SELECT Id FROM ' + housekeeping.Object_API_Name__c + ' WHERE CreatedDate < N_DAYS_AGO:' + days;
        Database.executeBatch(new CRMGlobalDeleteOldLogsBatch(query), 200);
        Test.stopTest();

        // 2. Check that old records were deleted
        Integer infoLogCount = [SELECT COUNT() FROM CRM_Global_ApexLog__c WHERE Severity__c = 'INFO'];
        Integer debugLogCount = [SELECT COUNT() FROM CRM_Global_ApexLog__c WHERE Severity__c = 'DEBUG'];
        
        System.assertEquals(5, infoLogCount, '5 info logs should remain.');
        System.assertEquals(0, debugLogCount, '5 debug logs should be deleted.');
    }

    @isTest
    static void testSystemSchedule() {
        Test.startTest();
        
        // Schedule the job
        String cronExp = '0 0 2 * * ?'; 
        String jobName = 'Test Daily Old Data Deletion';
        System.schedule(jobName, cronExp, new CRMGlobalDeleteOldLogsBatch(null));
        
        Test.stopTest();

        // --- Verification ---
        // Check that the CronTrigger was created successfully
        Integer scheduledJobs = [SELECT COUNT() FROM CronTrigger WHERE CronExpression = :cronExp];
        System.assertEquals(1, scheduledJobs, 'The job should be scheduled.');
    }
}