/**
 * @description       : Wrapper class for CRM_Global_DataIntegration_Config__mdt
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-19
 * @last modified by  : Franco
**/
public with sharing class CRMGlobalDataIntegrationConfigWrapper {

    public CRM_Global_DataIntegration_Config__mdt config;
    public String recordId;
    public SObject parentRecord;
    public List<CRMGlobalDataIntegrationTargetWrapper> targetWrappers;

    /**
     * @description Constructor to initialize the CRMGlobalDataIntegrationConfigWrapper object
     * @param config 
     * @param recordId 
     */
    public CRMGlobalDataIntegrationConfigWrapper(CRM_Global_DataIntegration_Config__mdt config, String recordId) {
        this.config = config;
        this.recordId = recordId;

        if(String.isNotBlank(recordId)) {
            initParentRecord();
        }

        initConfigTargets(config, config.DataIntegration_Target__r);
    }

    private void initParentRecord() {
        Set<String> fields = new Set<String>();
        fields.add('Id');
        if(String.isNotBlank(config.Parent_ExId_Field__c)) {
            fields.add(config.Parent_ExId_Field__c);
        }

        // Extract merge fields from Request_Body__c, Request_Headers__c and Request_Params__c
        fields.addAll(CRMGlobalTemplateMergeFieldService.getMergeFieldsFromTemplate(config.Request_Body__c));
        fields.addAll(CRMGlobalTemplateMergeFieldService.getMergeFieldsFromTemplate(config.Request_Headers__c));
        fields.addAll(CRMGlobalTemplateMergeFieldService.getMergeFieldsFromTemplate(config.Request_Params__c));

        String query = 'SELECT ' + String.join(new List<String>(fields), ', ')
                    + ' FROM ' + config.Parent_Object__c
                    + ' WHERE Id = :recordId';
        
        try {
            List<SObject> records = Database.query(String.escapeSingleQuotes(query), AccessLevel.SYSTEM_MODE);
            if(records.size() > 0) {
                this.parentRecord = records[0];
            }
        } catch (QueryException e) {
            String message = 'Error querying parent record: ' + e.getMessage();
            message = message + '. Query: ' + query;
            // add apex logging
            System.debug(LoggingLevel.ERROR, message);
            throw new CRMGlobalDataIntegrationException(message);
        }
    }

    @TestVisible
    private void initConfigTargets(CRM_Global_DataIntegration_Config__mdt config, List<CRM_Global_DataIntegration_Target__mdt> targets) {
        this.targetWrappers = new List<CRMGlobalDataIntegrationTargetWrapper>();
        List<String> targetObjectNames = new List<String>();
        for(CRM_Global_DataIntegration_Target__mdt target : targets) {
            targetObjectNames.add(target.Target_Object__c);
        }
        Map<String, Schema.DescribeSObjectResult> sObjectTypeMap = new Map<String, Schema.DescribeSObjectResult>();
        for(Schema.DescribeSObjectResult describe : Schema.describeSObjects(targetObjectNames, SObjectDescribeOptions.DEFERRED)) {
            sObjectTypeMap.put(describe.getName(), describe);
        }
        for(CRM_Global_DataIntegration_Target__mdt target : targets) {
            Schema.DescribeSObjectResult describe = sObjectTypeMap.get(target.Target_Object__c);
            CRMGlobalDataIntegrationTargetWrapper targetWrapper = new CRMGlobalDataIntegrationTargetWrapper(config, target, describe);
            this.targetWrappers.add(targetWrapper);
        }
    }
}