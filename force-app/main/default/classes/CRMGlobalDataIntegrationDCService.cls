/**
 * @description       : Service for Data Cloud Integration
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-12
 * @last modified by  : Franco
**/
public with sharing class CRMGlobalDataIntegrationDCService {

    /**
     * @description Execute Data Cloud Query
     * @param config 
     * @param record 
     * @return  `List<SObject>`
     * @throws CRMGlobalDataIntegrationException
     */
    public static List<SObject> executeDataCloudQuery(CRM_Global_DataIntegration_Config__mdt config, SObject record) {
        List<SObject> queryResults = new List<SObject>();
        String query = config.DataCloud_Query__c;

        if(CRMGlobalTemplateMergeFieldService.hasMergeFields(query)) {
            query = CRMGlobalTemplateMergeFieldService.mergeTemplate(query, record, false);
        }
        System.debug(LoggingLevel.INFO, 'Data Cloud Query: ' + query);
        try {
            queryResults = Database.query(query, AccessLevel.SYSTEM_MODE);
        } catch (QueryException e) {
            System.debug(LoggingLevel.ERROR, 'Query Data Cloud Error: ' + e.getMessage());
            throw new CRMGlobalDataIntegrationException(e);
        }
        return queryResults;
    }

    /**
     * @description Convert SObject list to List of Maps
     * @param sObjectList 
     * @return  `Object`
     */
    public static Object parseDataCloudQueryResponse(List<SObject> sObjectList) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        if(sObjectList == null) {
            return result;
        }
        for (SObject sobj : sObjectList) {
            result.add(sobj.getPopulatedFieldsAsMap());
        }
        return result;
    }
}