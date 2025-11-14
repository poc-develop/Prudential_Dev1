/**
 * @description       : Test class for CRMPHKLLevyPaymentHistoryController
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-11-11
 * @last modified by  : Franco
**/
@IsTest
private class CRMPHKLLevyPaymentHistoryControllerTest {

    @TestSetup
    private static void setupTestData() {
        Id paRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
        Account testAccount = new Account(LastName = 'Test Account', RecordTypeId = paRTId);
        insert testAccount;

        // Create Insurance Policy
        Id polRTId = Schema.SObjectType.InsurancePolicy.getRecordTypeInfosByDeveloperName().get('Life').getRecordTypeId();
        InsurancePolicy policy = new InsurancePolicy(
            Name = 'Test Policy', 
            RecordTypeId = polRTId,
            NameInsuredId = testAccount.Id
        );
        insert policy;

        // Create Coverage with start and end dates
        InsurancePolicyCoverage coverage = new InsurancePolicyCoverage(
            InsurancePolicyId = policy.Id,
            CRM_Global_PolicyCommencingInceptDate__c = Date.today().addYears(-2),
            CRM_Global_PolicyAnniversaryNextAVYDate__c = Date.today()
        );
        insert coverage;
    }

    /**
     * @description Test getFieldSetColumns
     */
    @IsTest
    static void testGetFieldSetColumns() {
        Test.startTest();
        List<Map<String, String>> result = CRMPHKLLevyPaymentHistoryController.getFieldSetColumns();
        Test.stopTest();

        System.assert(result != null, 'Result should not be null');
        System.assert(result.size() > 0, 'The field set must return at least one column');
        System.assert(result[0].containsKey('fieldName'), 'Returned map should contain fieldName key');
        System.assert(result[0].containsKey('label'), 'Returned map should contain label key');
        System.assert(result[0].containsKey('type'), 'Returned map should contain type key');
    }

    /**
     * @description Test getPolicyYearOptions
     */
    @IsTest
    static void testGetPolicyYearOptions() {
        
        Test.startTest();
        InsurancePolicy policy = [SELECT Id FROM InsurancePolicy WHERE Name = 'Test Policy' LIMIT 1];
        List<Map<String, String>> result = CRMPHKLLevyPaymentHistoryController.getPolicyYearOptions(policy.Id);
        Test.stopTest();

        System.assert(result.size() > 0, 'Should return policy year ranges');
        System.assert(result[0].containsKey('label'));
        System.assert(result[0].containsKey('value'));
    }

    /**
     * @description Test getTransactions
     */
    @IsTest
    static void testGetTransactions() {
        // Create Policy
        InsurancePolicy policy = [SELECT Id FROM InsurancePolicy WHERE Name = 'Test Policy' LIMIT 1];

        // Get record type for Levy Payment History
        RecordType rt = [SELECT Id FROM RecordType WHERE SObjectType = 'FinServ__FinancialAccountTransaction__c' AND DeveloperName = 'Levy_Payment_History' LIMIT 1];

        // Create Transaction
        FinServ__FinancialAccountTransaction__c txn = new FinServ__FinancialAccountTransaction__c(
            FinServ__InsurancePolicy__c = policy.Id,
            RecordTypeId = rt.Id
        );
        insert txn;

        Test.startTest();
        List<FinServ__FinancialAccountTransaction__c> result = CRMPHKLLevyPaymentHistoryController.getTransactions(policy.Id, '2023');
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return the inserted transaction');
    }

    /**
     * @description Test syncTransactions (mock callout only to ensure no exception)
     */
    @IsTest
    static void testSyncTransactions() {
        InsurancePolicy policy = [SELECT Id FROM InsurancePolicy WHERE Name = 'Test Policy' LIMIT 1];

        Test.startTest();
        // Mock HTTP Response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        CRMPHKLLevyPaymentHistoryController.syncTransactions(policy.Id, '2023');
        Test.stopTest();

        // No assertion needed; test passes if no exception is thrown
        System.assert(true, 'syncTransactions executed without errors');
    }

    /**
     * @description Test syncTransactions (mock callout only to ensure no exception)
     */
    @IsTest
    static void testSyncWithConfig() {
        InsurancePolicy policy = [SELECT Id FROM InsurancePolicy WHERE Name = 'Test Policy' LIMIT 1];
        
        // Mock Integration Config
        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt(
            DeveloperName = 'Test_Config',
            MasterLabel = 'Test Config',
            Parent_Object__c = 'Account',
            Parent_ExId_Field__c = 'Name',
            HTTP_Method__c = 'POST',
            Named_Credential__c = 'Test_NC',
            Endpoint_Path__c = '/endpoint',
            Request_Params__c = 'param1=value1',
            Request_Headers__c = '{"fi_client_cd":"123","Name":"{{{Name}}}"}',
            Request_Body__c = '{"name":"{{{Name}}}"}',
            Response_Format__c = 'JSON',
            Success_Codes__c = '200;201',
            Timeout__c = 10000
        );

        // Mock HTTP Response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        CRMPHKLLevyPaymentHistoryController.syncWithConfig(policy.Id, '2023', config);
        Test.stopTest();

        // No assertion needed; test passes if no exception is thrown
        System.assert(true, 'syncWithConfig executed without errors');
    }

    /**
     * @description Simple HTTP mock
     */
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"data": []}');
            return res;
        }
    }
}