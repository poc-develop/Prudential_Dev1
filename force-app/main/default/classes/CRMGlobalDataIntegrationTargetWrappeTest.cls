/**
 * @description       : Tesst for CRMGlobalDataIntegrationTargetWrapper
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-19
 * @last modified by  : Franco
**/
@IsTest
private class CRMGlobalDataIntegrationTargetWrappeTest {

    // Create test config metadata
    private static CRM_Global_DataIntegration_Config__mdt createTestConfig() {
        return new CRM_Global_DataIntegration_Config__mdt(
            DeveloperName = 'Test_Config',
            MasterLabel = 'Test Config',
            Parent_Object__c = 'Account'
        );
    }

    // Create test target metadata
    private static CRM_Global_DataIntegration_Target__mdt createTestTarget(String targetObject, String fieldMappingsJson, String recordTypeDevName) {
        return new CRM_Global_DataIntegration_Target__mdt(
            DeveloperName = 'Test_Target',
            MasterLabel = 'Test Target',
            Target_Object__c = targetObject,
            Target_ExId_Field__c = 'External_Id__c',
            Target_Parent_Field__c = 'ParentId',
            Response_Path__c = 'data.results',
            Include_Parent_Id_To_ExId_Field__c = true,
            Field_Mappings__c = fieldMappingsJson,
            Response_Composite_Keys__c = 'Id;Name',
            Target_Record_Type__c = recordTypeDevName
        );
    }

    @IsTest
    static void testConstructor_Success() {
        CRM_Global_DataIntegration_Config__mdt parentConfig = createTestConfig();
        String fieldMappings = '{"Name":"Name"}';
        CRM_Global_DataIntegration_Target__mdt target = createTestTarget('Account', fieldMappings, null);

        Schema.DescribeSObjectResult describe = Account.SObjectType.getDescribe();

        CRMGlobalDataIntegrationTargetWrapper wrapper = new CRMGlobalDataIntegrationTargetWrapper(parentConfig, target, describe);

        System.assertEquals('Account', wrapper.targetObject);
        System.assertEquals('External_Id__c', wrapper.targetExIdField);
        System.assert(wrapper.fieldMappings.containsKey('Name'));
        System.assertNotEquals(null, wrapper.targetFieldsMap);
        System.assert(wrapper.targetFieldLabels.size() > 0);
        System.assertEquals(true, wrapper.includeParentIdToExIdField);
        System.assert(wrapper.compositeKeyFields.contains('Id'));
    }

    @IsTest
    static void testConstructor_WithRecordType_Success() {
        CRM_Global_DataIntegration_Config__mdt parentConfig = createTestConfig();
        String fieldMappings = '{"Name":"Name"}';
        // Using 'CRM_GLOBAL_Customer' record type which always exists
        CRM_Global_DataIntegration_Target__mdt target = createTestTarget('Account', fieldMappings, 'CRM_GLOBAL_Customer');

        Schema.DescribeSObjectResult describe = Account.SObjectType.getDescribe();

        CRMGlobalDataIntegrationTargetWrapper wrapper = new CRMGlobalDataIntegrationTargetWrapper(parentConfig, target, describe);

        System.assertNotEquals(null, wrapper.targetRecordTypeId);
    }

    @IsTest
    static void testConstructor_FieldNotFound_ShouldThrowException() {
        CRM_Global_DataIntegration_Config__mdt parentConfig = createTestConfig();
        String invalidFieldMapping = '{"FakeField":"NotExistingField"}';
        CRM_Global_DataIntegration_Target__mdt target = createTestTarget('Account', invalidFieldMapping, null);

        Schema.DescribeSObjectResult describe = Account.SObjectType.getDescribe();

        try {
            new CRMGlobalDataIntegrationTargetWrapper(parentConfig, target, describe);
            System.assert(false, 'Expected exception not thrown');
        } catch (CRMGlobalDataIntegrationException e) {
            System.assert(e.getMessage().contains('Target field [NotExistingField] not found'));
        }
    }

    @IsTest
    static void testConstructor_RecordTypeNotFound_ShouldThrowException() {
        CRM_Global_DataIntegration_Config__mdt parentConfig = createTestConfig();
        String fieldMappings = '{"Name":"Name"}';
        CRM_Global_DataIntegration_Target__mdt target = createTestTarget('Account', fieldMappings, 'InvalidRecordType');

        Schema.DescribeSObjectResult describe = Account.SObjectType.getDescribe();

        try {
            new CRMGlobalDataIntegrationTargetWrapper(parentConfig, target, describe);
            System.assert(false, 'Expected exception not thrown');
        } catch (CRMGlobalDataIntegrationException e) {
            System.assert(e.getMessage().contains('Target record type [InvalidRecordType] not found'));
        }
    }

    @IsTest
    static void testIsToUpdateParent_True() {
        CRM_Global_DataIntegration_Config__mdt parentConfig = createTestConfig();
        String fieldMappings = '{"Name":"Name"}';
        CRM_Global_DataIntegration_Target__mdt target = createTestTarget('Account', fieldMappings, null);

        Schema.DescribeSObjectResult describe = Account.SObjectType.getDescribe();
        CRMGlobalDataIntegrationTargetWrapper wrapper = new CRMGlobalDataIntegrationTargetWrapper(parentConfig, target, describe);

        System.assertEquals(true, wrapper.isToUpdateParent());
    }

    @IsTest
    static void testIsToUpdateParent_False() {
        CRM_Global_DataIntegration_Config__mdt parentConfig = createTestConfig();
        String fieldMappings = '{"Name":"Name"}';
        CRM_Global_DataIntegration_Target__mdt target = createTestTarget('Contact', fieldMappings, null);

        Schema.DescribeSObjectResult describe = Contact.SObjectType.getDescribe();
        CRMGlobalDataIntegrationTargetWrapper wrapper = new CRMGlobalDataIntegrationTargetWrapper(parentConfig, target, describe);

        System.assertEquals(false, wrapper.isToUpdateParent());
    }
}