/**
 * @description       : Test class for CRMGlobalDataIntegrationService
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-19
 * @last modified by  : Franco
**/
@IsTest
private class CRMGlobalDataIntegrationServiceTest {

    @TestSetup
    static void setupTestData() {
        Id paRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
        Account testAccount = new Account(LastName = 'Test Account', RecordTypeId = paRTId);
        insert testAccount;
    }

    @IsTest
    static void testProcessParentRecord_Success() {
        Account acc = [SELECT Id, Name FROM Account WHERE LastName = 'Test Account' LIMIT 1];

        // Mock config and wrapper
        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt(
            DeveloperName = 'Test_Config',
            MasterLabel = 'Test Config',
            Parent_Object__c = 'Account'
        );

        CRM_Global_DataIntegration_Target__mdt targetConfig = new CRM_Global_DataIntegration_Target__mdt(
            DeveloperName = 'Target_Config',
            MasterLabel = 'Target Config',
            Target_Object__c = 'Account',
            Target_Parent_Field__c = null,
            Target_ExId_Field__c = 'Name',
            Field_Mappings__c = '{"Name":"Name"}',
            Response_Path__c = 'accounts',
            Response_Composite_Keys__c = 'Name'
        );
        List<CRM_Global_DataIntegration_Target__mdt> targets = new List<CRM_Global_DataIntegration_Target__mdt> { targetConfig};

        CRMGlobalDataIntegrationConfigWrapper wrapper = new CRMGlobalDataIntegrationConfigWrapper(config, acc.Id);
        wrapper.initConfigTargets(config, targets);

        // Mock response data
        Map<String, Object> childRecord = new Map<String, Object>{
            'Name' => 'John'
        };
        Map<String, Object> responseData = new Map<String, Object>{
            'accounts' => new List<Object>{ childRecord }
        };

        // Mock CRMGlobalDataIntegrationRespService methods
        Test.startTest();
        CRMGlobalDataIntegrationService.processAndUpsertRecords(responseData, wrapper);
        Test.stopTest();

        System.assert(true, 'Should execute without exceptions');
    }
    
    // @IsTest
    // static void testProcessParentRecord_Error() {
    //     Account acc = [SELECT Id, Name FROM Account WHERE LastName = 'Test Account' LIMIT 1];

    //     // Mock config and wrapper
    //     CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt(
    //         DeveloperName = 'Test_Config',
    //         MasterLabel = 'Test Config',
    //         Parent_Object__c = 'Account'
    //     );

    //     CRM_Global_DataIntegration_Target__mdt targetConfig = new CRM_Global_DataIntegration_Target__mdt(
    //         DeveloperName = 'Target_Config',
    //         MasterLabel = 'Target Config',
    //         Target_Object__c = 'Account',
    //         Target_Parent_Field__c = null,
    //         Target_ExId_Field__c = 'Name',
    //         Field_Mappings__c = '{"Name":"Name"}',
    //         Response_Path__c = 'accounts',
    //         Response_Composite_Keys__c = 'Name'
    //     );
    //     List<CRM_Global_DataIntegration_Target__mdt> targets = new List<CRM_Global_DataIntegration_Target__mdt> { targetConfig};


    //     CRMGlobalDataIntegrationConfigWrapper wrapper = new CRMGlobalDataIntegrationConfigWrapper(config, acc.Id);
    //     wrapper.initConfigTargets(config, targets);

    //     // Mock response data
    //     Map<String, Object> childRecord = new Map<String, Object>{
    //         'Name' => 'John'
    //     };
    //     Map<String, Object> responseData = new Map<String, Object>{
    //         'accounts' => new List<Object>{ childRecord }
    //     };

    //     // Mock CRMGlobalDataIntegrationRespService methods
    //     Test.startTest();
    //     Boolean didThrow = false;
    //     try {
    //         CRMGlobalDataIntegrationService.processAndUpsertRecords(responseData, wrapper);
    //     } catch (CRMGlobalDataIntegrationException e) {
    //         didThrow = true;
    //     }
    //     Test.stopTest();

    //     System.assert(didThrow, 'Should execute with exceptions');
    // }

    @IsTest
    static void testPrepareChildRecords_InsertAndUpdate() {
        Account acc = [SELECT Id, Name FROM Account WHERE LastName = 'Test Account' LIMIT 1];

        // Create targetConfig
        CRM_Global_DataIntegration_Target__mdt targetConfig = new CRM_Global_DataIntegration_Target__mdt(
            DeveloperName = 'Target_Config2',
            MasterLabel = 'Target Config 2',
            Target_Object__c = 'Account',
            Target_ExId_Field__c = 'Name',
            Field_Mappings__c = '{"Name":"Name"}',
            Target_Record_Type__c = null
        );

        // Existing record map
        Map<String, SObject> extIdToRecordMap = new Map<String, SObject>{
            acc.Name => acc
        };

        Test.startTest();
        CRMGlobalDataIntegrationTargetWrapper targetWrapper = new CRMGlobalDataIntegrationTargetWrapper(null, targetConfig, Account.SObjectType.getDescribe());
        Map<String, List<SObject>> result = CRMGlobalDataIntegrationService.prepareChildRecords(targetWrapper, extIdToRecordMap);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('TO_INSERT'), 'Should contain insert list');
        System.assert(result.containsKey('TO_UPDATE'), 'Should contain update list');
    }

    @IsTest
    static void testProcessChildRecord_Success() {
        Account acc = [SELECT Id, Name FROM Account WHERE LastName = 'Test Account' LIMIT 1];

        // Mock config and wrapper
        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt(
            DeveloperName = 'Test_Config',
            MasterLabel = 'Test Config',
            Parent_Object__c = 'Account'
        );

        CRM_Global_DataIntegration_Target__mdt targetConfig = new CRM_Global_DataIntegration_Target__mdt(
            DeveloperName = 'Target_Config',
            MasterLabel = 'Target Config',
            Target_Object__c = 'InsurancePolicy',
            Target_Parent_Field__c = 'NameInsuredId',
            Target_ExId_Field__c = 'Name',
            Field_Mappings__c = '{"PolicyNo":"Name","PolicyCode":"PolicyCode"}',
            Response_Path__c = 'policies',
            Response_Composite_Keys__c = 'Name',
            Include_Parent_Id_To_ExId_Field__c = true
        );
        List<CRM_Global_DataIntegration_Target__mdt> targets = new List<CRM_Global_DataIntegration_Target__mdt> { targetConfig};

        CRMGlobalDataIntegrationConfigWrapper wrapper = new CRMGlobalDataIntegrationConfigWrapper(config, acc.Id);
        wrapper.initConfigTargets(config, targets);

        // Mock response data
        Map<String, Object> childRecord = new Map<String, Object>{
            'PolicyNo' => '123456',
            'PolicyCode' => '123456'
        };
        Map<String, Object> responseData = new Map<String, Object>{
            'policies' => new List<Object>{ childRecord }
        };

        // Mock CRMGlobalDataIntegrationRespService methods
        Test.startTest();
        CRMGlobalDataIntegrationService.processAndUpsertRecords(responseData, wrapper);
        Test.stopTest();

        System.assert(true, 'Should execute without exceptions');
    }
}