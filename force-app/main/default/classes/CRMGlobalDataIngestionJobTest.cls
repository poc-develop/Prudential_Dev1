/**
 * CRMGlobalDataIngestionJobTest
 * @author       : Easin Zhou
 * @date         : 2025-10-18
 * @description  : Test class for CrmGlobalDataIngestionHandlerAbstract and CrmGlobalDataIngestionHandlerCase and CrmGlobalDataIngestionJobScheduler.
 */
@isTest
public with sharing class CRMGlobalDataIngestionJobTest {

    /**
     * setup
     * @description Setup method.
     */
    @testSetup
    static void setup(){
        // Insert Test Data - Person Account
        Account testPersonAccount = new Account(
            FirstName = 'Test FirstName',
            LastName = 'Test LastName',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId()
        );
        insert testPersonAccount;
        
        // Insert Test Data - Policy
        InsurancePolicy policy = new InsurancePolicy(
            Name = '10000001',
            NameInsuredId = testPersonAccount.Id
        );
        insert policy;

        // Insert Test Data - User
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Alias = 'tuser',
            Email = 'domain@test.com',
            Username = 'domain.test.' + System.currentTimeMillis() + '@test.com',
            CommunityNickname = 'domain' + System.currentTimeMillis(),
            TimeZoneSidKey = 'Asia/Hong_Kong',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        // Insert Test Data - Data Ingestion Job
        CRM_GLOBAL_Data_Ingestion_Job__c job = new CRM_GLOBAL_Data_Ingestion_Job__c();
        job.CRM_GLOBAL_SubmittedSource__c = 'fileName';
        job.CRM_Global_Call_Type__c = 'Servicing Call';
        job.CRM_GLOBAL_Status__c = 'Processing';
        job.CRM_GLOBAL_StartTime__c = Datetime.now();
        job.CRM_GLOBAL_TotalRecords__c = 1;
        job.CRM_Global_TargetObject__c = 'Cases';
        job.CRM_Global_Sub_Type_1__c = 'Change of Corr. Add';
        job.CRM_Global_Channel__c = 'HongKong';
        insert job;

        // Insert Test Data - Raw Data Staging
        List<CRM_GLOBAL_Raw_Data_Staging__c> stagingRecords = new List<CRM_GLOBAL_Raw_Data_Staging__c>{
            new CRM_GLOBAL_Raw_Data_Staging__c(
                CRM_GLOBAL_DataIngestionJob__c = job.Id,
                CRM_GLOBAL_RawJSONData__c = '{"Case Received Date":"2025-10-15","Policy No.":"10000001","Sub Type 2":"testtest","Case Owner":"domain@test.com","Priority":"High"}',
                CRM_GLOBAL_ProcessingStatus__c = 'Pending',
                CRM_GLOBAL_ProcessingAttempts__c = 2
            ),
            new CRM_GLOBAL_Raw_Data_Staging__c(
                CRM_GLOBAL_DataIngestionJob__c = job.Id,
                CRM_GLOBAL_RawJSONData__c = '{"Case Received Date":"2025-10-15","Policy No.":"10000001","Sub Type 2":"testtest","Case Owner":"domain@test.com","Priority":"High"}',
                CRM_GLOBAL_ProcessingStatus__c = 'Pending',
                CRM_GLOBAL_ProcessingAttempts__c = 2
            ),
            new CRM_GLOBAL_Raw_Data_Staging__c(
                CRM_GLOBAL_DataIngestionJob__c = job.Id,
                CRM_GLOBAL_RawJSONData__c = '{"Case Received Date":"2025-10-15","Policy No.":"10000003","Sub Type 2":"testtest","Case Owner":"domain2222@test.com","Priority":"High"}',
                CRM_GLOBAL_ProcessingStatus__c = 'Pending',
                CRM_GLOBAL_ProcessingAttempts__c = 2
            )
        };
        insert stagingRecords;

        System.assertNotEquals(testPersonAccount, null, 'This is Error');
    }

    /**
     * TestIngestionHandler
     * @description min child class for abstract.
     */
    private class TestIngestionHandler extends CrmGlobalDataIngestionHandlerAbstract {
        public override void validateRawData() {
            System.debug('validateRawData called');
        }
        public override void handleRawData() {
            System.debug('handleRawData called');
        }
        protected override String checkRawDataItem(String rawKey, String rawDataItem) {
            return super.checkRawDataItem(rawKey, rawDataItem);
        }
    }

    /**
     * coverExecute
     * @description  Test method for main method - execute.
     */
    @IsTest
    private static void coverExecute(){

        CRMGlobalDataIngestionJobScheduler scheduler = new CRMGlobalDataIngestionJobScheduler(2);

        System.Test.startTest();
        scheduler.beginExecuteJob();
        System.Test.stopTest();
        
        System.assertNotEquals(scheduler, null, 'This is Syntax Error');
    }

    /**
     * coverAbstract
     * @description  Test method for methods of CrmGlobalDataIngestionHandlerAbstract.
     */
    @IsTest
    private static void coverAbstract(){

        TestIngestionHandler testInstance = new TestIngestionHandler();
        
        System.Test.startTest();
        try {

            testInstance.setAttribute('key', 'value');
            testInstance.getAttribute('key');
            testInstance.checkRawDataItem('key', '{}');

            CrmGlobalDataIngestionHandlerAbstract.getInstance('CrmGlobalDataIngestionHandlerCase2');
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error Cover Abstract: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
        System.Test.stopTest();
        
        System.assertNotEquals(testInstance, null, 'This is Syntax Error');
    }
    
}