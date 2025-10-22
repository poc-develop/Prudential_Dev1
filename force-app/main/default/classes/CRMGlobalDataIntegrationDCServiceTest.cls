/**
 * @description       : Test class for CRMGlobalDataIntegrationDCService
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-16
 * @last modified by  : Franco
**/
@IsTest
private class CRMGlobalDataIntegrationDCServiceTest {
    
    @TestSetup
    static void setupTestData() {
        Id paRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
        Account testAccount = new Account(LastName = 'Test Account', RecordTypeId = paRTId);
        insert testAccount;
    }

    @IsTest
    static void testExecuteDataCloudQuery_NoMergeFields() {
        Account acc = [SELECT Id, Name FROM Account WHERE LastName = 'Test Account' LIMIT 1];
        // Mock metadata config without merge fields
        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt(
            DeveloperName = 'Test_Config',
            DataCloud_Query__c = 'SELECT Id, Name FROM Account WHERE Id = \'' + acc.Id + '\''
        );

        Test.startTest();
        List<SObject> result = CRMGlobalDataIntegrationDCService.executeDataCloudQuery(config, acc);
        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'Should return query result.');
        System.assertEquals(acc.Id, result[0].get('Id'), 'Should match Account Id.');
    }

    @IsTest
    static void testExecuteDataCloudQuery_WithMergeFields() {
        Account acc = [SELECT Id, Name FROM Account WHERE LastName = 'Test Account' LIMIT 1];
        // Mock metadata config with merge fields
        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt(
            DeveloperName = 'Config_With_Merge',
            DataCloud_Query__c = 'SELECT Id FROM Account WHERE Id = {{{Id}}}'
        );

        Test.startTest();
        if (CRMGlobalTemplateMergeFieldService.hasMergeFields(config.DataCloud_Query__c)) {
            config.DataCloud_Query__c = 'SELECT Id FROM Account WHERE Id = \'' + acc.Id + '\'';
        }

        List<SObject> result = CRMGlobalDataIntegrationDCService.executeDataCloudQuery(config, acc);
        Test.stopTest();

        System.assert(result.size() > 0, 'Should return query result after merge.');
    }

    @IsTest
    static void testExecuteDataCloudQuery_QueryException() {
        // Mock config with invalid SOQL
        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt(
            DeveloperName = 'Invalid_Config',
            DataCloud_Query__c = 'SELECT InvalidField__c FROM Account'
        );

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            CRMGlobalDataIntegrationDCService.executeDataCloudQuery(config, new Account());
        } catch (CRMGlobalDataIntegrationException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Should throw CRMGlobalDataIntegrationException.');
    }

    @IsTest
    static void testParseDataCloudQueryResponse() {
        Account acc = new Account(Name = 'Parse Test');
        List<Account> accList = new List<Account> { acc };
        Object result = CRMGlobalDataIntegrationDCService.parseDataCloudQueryResponse(accList);

        System.assert(result instanceof List<Map<String, Object>>, 'Should return list of maps.');
        System.assert(((List<Map<String, Object>>)result)[0].containsKey('Name'), 'Map should contain Name key.');

        // Null case
        Object emptyResult = CRMGlobalDataIntegrationDCService.parseDataCloudQueryResponse(null);
        System.assertEquals(0, ((List<Map<String, Object>>)emptyResult).size(), 'Should return empty list when input is null.');
    }
}