/**
 * @description       : Wrapper class for CRM_Global_DataIntegration_Target__mdt
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-19
 * @last modified by  : Franco
**/
public with sharing class CRMGlobalDataIntegrationTargetWrapper {

    private CRM_Global_DataIntegration_Config__mdt parentConfig;
    private CRM_Global_DataIntegration_Target__mdt target;

    public String targetObject;
    public String targetExIdField;
    public String targetParentField;
    public String responsePath;
    public Boolean includeParentIdToExIdField;

    public Schema.SObjectType targetSObjectType;
    public Map<String, Schema.SObjectField> targetFieldsMap;

    public List<String> compositeKeyFields = new List<String>();
    public Map<String, String> fieldMappings = new Map<String, String>();
    public Id targetRecordTypeId;
    public List<String> targetFieldLabels = new List<String>();

    /**
     * @description Constructor to initialize the CRMGlobalDataIntegrationTargetWrapper object
     * @param parentConfig 
     * @param target 
     * @param describe 
     */
    public CRMGlobalDataIntegrationTargetWrapper(CRM_Global_DataIntegration_Config__mdt parentConfig, CRM_Global_DataIntegration_Target__mdt target, Schema.DescribeSObjectResult describe) {
        this.parentConfig = parentConfig;
        this.target = target;
        this.targetObject = target.Target_Object__c;
        this.targetExIdField = target.Target_ExId_Field__c;
        this.targetParentField = target.Target_Parent_Field__c;
        this.responsePath = target.Response_Path__c;
        this.includeParentIdToExIdField = target.Include_Parent_Id_To_ExId_Field__c;
        initAndValidateTarget(describe);
    }

    private void initAndValidateTarget(Schema.DescribeSObjectResult describe) {
        this.targetSObjectType = describe.getSObjectType();
        this.targetFieldsMap = describe.fields.getMap();
        this.fieldMappings = (Map<String, String>) JSON.deserialize(target.Field_Mappings__c, Map<String, String>.class);
        for(String sourceField : fieldMappings.keySet()) {
            String targetField = fieldMappings.get(sourceField);
            if(!targetFieldsMap.containsKey(targetField.toLowerCase())) {
                throw new CRMGlobalDataIntegrationException('Target field [' + targetField + '] not found on object [' + targetObject + ']');
            }
            Schema.SObjectField targetFieldSchema = targetFieldsMap.get(targetField.toLowerCase());
            this.targetFieldLabels.add(targetFieldSchema.getDescribe().getLabel());
        }

        if(String.isNotBlank(target.Response_Composite_Keys__c)) {
            this.compositeKeyFields = target.Response_Composite_Keys__c.split(';');
        }

        if(String.isNotBlank(target.Target_Record_Type__c)) {
            Map<String, Schema.RecordTypeInfo> targetRecordTypesMap = describe.getRecordTypeInfosByDeveloperName();
            if(!targetRecordTypesMap.containsKey(target.Target_Record_Type__c)) {
                throw new CRMGlobalDataIntegrationException('Target record type [' + target.Target_Record_Type__c + '] not found on object [' + targetObject + ']');
            }
            this.targetRecordTypeId = targetRecordTypesMap.get(target.Target_Record_Type__c).getRecordTypeId();
        }
    }

    /**
     * @description Is To Update Parent Record
     * @return  `Boolean`
     */
    public Boolean isToUpdateParent() {
        // If the target object is the same as the parent object
        // It means to crate/update the parnet record itself
        // Otherwise, it means to crate/update the child records
        return this.targetObject == parentConfig.Parent_Object__c;
    }
}