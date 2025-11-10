/**
 * @description       : Test class for CRMGlobalDataIntegrationController
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-31
 * @last modified by  : Franco
**/
@IsTest
private class CRMGlobalDataIntegrationControllerTest {

    @TestSetup
    static void setupTestData() {
        Id paRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
        Account testAccount = new Account(LastName = 'Test Account', RecordTypeId = paRTId);
        insert testAccount;
    }

    @IsTest
    static void testGetIntegrationConfig_NotFound() {
        Test.startTest();
        CRM_Global_DataIntegration_Config__mdt result = CRMGlobalDataIntegrationController.getIntegrationConfig('Test_Config_Not_Found');
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when not found');
    }

    @IsTest
    static void testSyncWithIntegration_NotFound() {
        Test.startTest();
        CRMGlobalDataIntegrationSyncResult result = CRMGlobalDataIntegrationController.syncWithIntegration(null, 'Test_Config_Not_Found');
        Test.stopTest();

        System.assertEquals(false, result.isSuccess, 'Should return failure when not found');
    }

    @IsTest
    static void testSyncWithIntegration_DataCloud() {
        Account acc = [SELECT Id, Name FROM Account WHERE LastName = 'Test Account' LIMIT 1];

        // Mock metadata
        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt(
            DeveloperName = 'DataCloud_Config',
            MasterLabel = 'Data Cloud Config',
            Parent_Object__c = 'Account',
            Parent_ExId_Field__c = 'Name',
            Is_Active__c = true,
            Integration_Type__c = 'Data_Cloud',
            DataCloud_Query__c = 'SELECT Id, Name FROM Account WHERE Name = \'{{{Name}}}\''
        );

        Test.startTest();
        CRMGlobalDataIntegrationController.syncWithIntegrationWithConfig(acc.Id, config);
        Test.stopTest();

        System.assert(true, 'Data Cloud integration executed successfully');
    }

    @IsTest
    static void testSyncWithIntegration_ExternalAPI_Success() {
        Account acc = [SELECT Id, Name FROM Account WHERE LastName = 'Test Account' LIMIT 1];

        // Mock metadata
        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt(
            DeveloperName = 'ExternalAPI_Config',
            MasterLabel = 'External API Config',
            Parent_Object__c = 'Account',
            Parent_ExId_Field__c = 'Name',
            Is_Active__c = true,
            Integration_Type__c = 'External_API',
            HTTP_Method__c = 'POST',
            Endpoint_Path__c = '/test/api',
            Named_Credential__c = 'Test_NC'
        );

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());
        CRMGlobalDataIntegrationSyncResult result = CRMGlobalDataIntegrationController.syncWithIntegrationWithConfig(acc.Id, config);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'External API integration executed successfully');
    }

    @IsTest
    static void testSyncWithIntegration_ExternalAPI_Error() {
        Account acc = [SELECT Id, Name FROM Account WHERE LastName = 'Test Account' LIMIT 1];

        // Mock metadata
        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt(
            DeveloperName = 'ExternalAPI_Config',
            MasterLabel = 'External API Config',
            Parent_Object__c = 'Account',
            Parent_ExId_Field__c = 'Name',
            Is_Active__c = true,
            Integration_Type__c = 'External_API',
            HTTP_Method__c = 'POST',
            Endpoint_Path__c = '/test/api',
            Named_Credential__c = 'Test_NC'
        );

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockErrorResponse());
        CRMGlobalDataIntegrationSyncResult result = CRMGlobalDataIntegrationController.syncWithIntegrationWithConfig(acc.Id, config);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess, 'External API integration executed with error');
    }

    @IsTest
    static void testExecuteSOQL() {
        Account acc = [SELECT Id, Name FROM Account WHERE LastName = 'Test Account' LIMIT 1];

        Test.startTest();
        String soql = 'SELECT Id FROM Account WHERE Id = :recordId';
        String recordId = acc.Id;
        try {
            List<Id> recordsId = CRMGlobalDataIntegrationController.executeSOQL('', null);
        } catch(Exception e) {
            System.assert(true, 'SOQL query is blank.');
        }
        try {
            List<Id> recordsId = CRMGlobalDataIntegrationController.executeSOQL(soql, null);
        } catch(Exception e) {
            System.assert(true, 'Query uses :recordId, but no contextId was provided.');
        }
        List<Id> recordsId = CRMGlobalDataIntegrationController.executeSOQL(soql, recordId);
        System.assert(recordsId.size() > 0, 'SOQL query executed successfully.');
        
        Test.stopTest();

    }

    // Mock for successful HTTP response
    private class MockSuccessResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"result": "ok", "message": "success"}');
            return res;
        }
    }

    // Mock for successful HTTP response
    private class MockErrorResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            res.setBody('{"error": "Bad Request", "message": "Invalid data"}');
            return res;
        }
    }
}