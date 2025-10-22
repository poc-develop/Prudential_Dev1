/**
 * @description       : Test class for CRMGlobalDataIntegrationConfigWrapper
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-19
 * @last modified by  : Franco
**/
@IsTest
private class CRMGlobalDataIntegrationConfigWrappeTest {

    @IsTest
    static void testWrapperInitialization() {
        Id customerRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
        Account acc = new Account(LastName = 'Test Account', RecordTypeId = customerRTId);
        insert acc;

        CRM_Global_DataIntegration_Target__mdt target = new CRM_Global_DataIntegration_Target__mdt(
            DeveloperName = 'Test_Target',
            MasterLabel = 'Test Target',
            Target_Object__c = 'Account',
            Target_ExId_Field__c = 'LastName',
            Include_Parent_Id_To_ExId_Field__c = false,
            Field_Mappings__c = '{"Name":"Name"}',
            Response_Composite_Keys__c = 'Name',
            Target_Record_Type__c = 'CRM_GLOBAL_Customer'
        );
        List<CRM_Global_DataIntegration_Target__mdt> targets = new List<CRM_Global_DataIntegration_Target__mdt>();
        targets.add(target);

        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt(
            DeveloperName = 'TestConfig',
            MasterLabel = 'Test Config',
            Parent_Object__c = 'Account',
            Parent_ExId_Field__c = 'Id',
            Request_Body__c = '{"name":"{{Name}}","id":"{{Id}}"}',
            Request_Headers__c = '{"Authorization":"Bearer {{Id}}"}',
            Request_Params__c = '{"AccountName":"{{Name}}"}'
        );

        Test.startTest();
        CRMGlobalDataIntegrationConfigWrapper wrapper =
            new CRMGlobalDataIntegrationConfigWrapper(config, acc.Id);
        Test.stopTest();

        // validate common fields
        System.assertNotEquals(null, wrapper.config, 'Config should not be null');
        System.assertEquals(acc.Id, wrapper.recordId, 'Record Id should match');
    }

    @IsTest
    static void testInitConfigTargets() {
        Id customerRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
        Account acc = new Account(LastName = 'Test Account', RecordTypeId = customerRTId);
        insert acc;

        CRM_Global_DataIntegration_Target__mdt target = new CRM_Global_DataIntegration_Target__mdt(
            DeveloperName = 'Test_Target',
            MasterLabel = 'Test Target',
            Target_Object__c = 'Account',
            Target_ExId_Field__c = 'LastName',
            Include_Parent_Id_To_ExId_Field__c = false,
            Field_Mappings__c = '{"Name":"Name"}',
            Response_Composite_Keys__c = 'Name',
            Target_Record_Type__c = 'CRM_GLOBAL_Customer'
        );
        List<CRM_Global_DataIntegration_Target__mdt> targets = new List<CRM_Global_DataIntegration_Target__mdt>();
        targets.add(target);

        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt(
            DeveloperName = 'TestConfig',
            MasterLabel = 'Test Config',
            Parent_Object__c = 'Account',
            Parent_ExId_Field__c = 'Id'
        );

        Test.startTest();
        CRMGlobalDataIntegrationConfigWrapper wrapper =
            new CRMGlobalDataIntegrationConfigWrapper(config, acc.Id);
        wrapper.initConfigTargets(config, targets);
        Test.stopTest();

        System.assert(wrapper.targetWrappers.size() > 0, 'Targets should be initialized');
    }

    @IsTest
    static void testInvalidQuery() {
        Id customerRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
        Account acc = new Account(LastName = 'Test Account', RecordTypeId = customerRTId);
        insert acc;

        CRM_Global_DataIntegration_Target__mdt target = new CRM_Global_DataIntegration_Target__mdt(
            DeveloperName = 'Test_Target',
            MasterLabel = 'Test Target',
            Target_Object__c = 'Account',
            Target_ExId_Field__c = 'LastName',
            Include_Parent_Id_To_ExId_Field__c = false,
            Field_Mappings__c = '{"Name":"Name"}',
            Response_Composite_Keys__c = 'Name',
            Target_Record_Type__c = 'CRM_GLOBAL_Customer'
        );
        List<CRM_Global_DataIntegration_Target__mdt> targets = new List<CRM_Global_DataIntegration_Target__mdt>();
        targets.add(target);

        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt(
            DeveloperName = 'TestConfig',
            MasterLabel = 'Test Config',
            Parent_Object__c = 'Account',
            Parent_ExId_Field__c = 'Id',
            Request_Body__c = '{"name":"{{{FIELD_NOT_EXIST}}}"}'
        );

        Test.startTest();
        try {
            CRMGlobalDataIntegrationConfigWrapper wrapper =
            new CRMGlobalDataIntegrationConfigWrapper(config, acc.Id);
        } catch (CRMGlobalDataIntegrationException e) {
            System.assert(e.getMessage().contains('Error querying parent record'));
        }
        Test.stopTest();
    }
}