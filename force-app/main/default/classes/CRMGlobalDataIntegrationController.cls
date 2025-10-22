/**
 * @description       : Controller for CRM Global Data Integration LWC
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-20
 * @last modified by  : Franco
**/
public with sharing class CRMGlobalDataIntegrationController {
    
    /**
     * @description GET Integration Config by Name
     * @param configName 
     * @return  `CRM_Global_DataIntegration_Config__mdt`
     * @exception 
     */
    public static CRM_Global_DataIntegration_Config__mdt getIntegrationConfig(String configName) {
        List<CRM_Global_DataIntegration_Config__mdt> configs = [
            SELECT Id, MasterLabel, DeveloperName, Is_Active__c, Integration_Name__c,
                Sync_Type__c, Integration_Type__c, DataCloud_Query__c, Endpoint_Path__c, HTTP_Method__c,  
                Named_Credential__c, Request_Body__c, Request_Headers__c, Request_Params__c, Response_Format__c,
                Parent_ExId_Field__c, Parent_Object__c, Success_Codes__c, Timeout__c, Boolean_True_Values__c, 
                Date_Format__c, Datetime_Format__c, 
                    (SELECT Id, Target_Object__c, Target_ExId_Field__c, Target_Parent_Field__c, Field_Mappings__c,
                            Response_Path__c, Target_Record_Type__c, Response_Composite_Keys__c, Include_Parent_Id_To_ExId_Field__c 
                    FROM DataIntegration_Target__r
                    WHERE Is_Active__c = true)
            FROM CRM_Global_DataIntegration_Config__mdt
            WHERE DeveloperName = :configName
            AND Is_Active__c = TRUE
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if(configs.size() > 0) {
            return configs[0];
        }
        return null;
    }

    /**
     * @description Sync with Integration
     * @param recordId 
     * @param configName 
     * @return `CRMGlobalDataIntegrationSyncResult`
     * @exception 
     */
    @AuraEnabled
    public static CRMGlobalDataIntegrationSyncResult syncWithIntegration(String recordId, String configName) {
        CRMGlobalDataIntegrationSyncResult syncResult;
        CRM_Global_DataIntegration_Config__mdt config = getIntegrationConfig(configName);
        if (config == null) {
            String message = 'Configuration [' + configName + '] is not found or not active';
            syncResult = new CRMGlobalDataIntegrationSyncResult(false, message, null);
            return syncResult;
        }
        syncResult = syncWithIntegrationWithConfig(recordId, config);
        return syncResult;
    }

    /**
     * @description Sync with Integration With Config
     * @param recordId 
     * @param config 
     * @return `CRMGlobalDataIntegrationSyncResult`
     * @exception 
     */
    public static CRMGlobalDataIntegrationSyncResult syncWithIntegrationWithConfig(String recordId, CRM_Global_DataIntegration_Config__mdt config) {
        CRMGlobalDataIntegrationSyncResult syncResult;
        try {
            CRMGlobalDataIntegrationConfigWrapper configWrapper = new CRMGlobalDataIntegrationConfigWrapper(config, recordId);

            if (config.Integration_Type__c == 'Data_Cloud') {
                List<SObject> queryResult = CRMGlobalDataIntegrationDCService.executeDataCloudQuery(config, configWrapper.parentRecord);
                Object responseData = CRMGlobalDataIntegrationDCService.parseDataCloudQueryResponse(queryResult);
                CRMGlobalDataIntegrationService.processAndUpsertRecords(responseData, configWrapper);
            } else if(config.Integration_Type__c == 'External_API') {
                HttpResponse response = CRMGlobalDataIntegrationAPIService.callExternalApi(configWrapper);
                Object responseData = CRMGlobalDataIntegrationAPIService.parseApiResponse(configWrapper, response);
                CRMGlobalDataIntegrationService.processAndUpsertRecords(responseData, configWrapper);
            }
            syncResult = new CRMGlobalDataIntegrationSyncResult(true, 'Sync completed successfully', null);
        } catch (Exception e) {
            String message = e.getMessage();
            syncResult = new CRMGlobalDataIntegrationSyncResult(false, message, null);
            System.debug(LoggingLevel.ERROR, e.getMessage() + '-' + e.getStacktraceString());
            CRMGlobalLogManager.addApexErrorLog(message, e);
        } finally {
            CRMGlobalLogManager.saveAndFlushLogs();
        }
        return syncResult;
    }

}