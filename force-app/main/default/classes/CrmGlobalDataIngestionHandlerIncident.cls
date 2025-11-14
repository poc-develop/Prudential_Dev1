/**
 * CrmGlobalDataIngestionHandlerIncident
 * @author       : Mark
 * @date         : 2025-11-06
 * @description  : Class for Data Ingestion Job Incident Handler.
 */
public with sharing class CrmGlobalDataIngestionHandlerIncident extends CrmGlobalDataIngestionHandlerAbstract {

    /**
     * @description Outbound Incident List.
     */
    public List<Incident> incidentList;

    // /**
    //  * @description Raw Data String Record Id List.
    //  */
    // public List<String> rawDataIdList;

        /**
     * @method init
     * @description init method for pass parameters instead of constructor.
     * @param job
     * @return CrmGlobalDataIngestionHandlerAbstract
     */
    public override CrmGlobalDataIngestionHandlerAbstract init(
        CRM_Global_Data_Ingestion_Job__c job
    ) {
        super.init(job);

        return this;
    }

    /**
     * @method init
     * @description init method for pass parameters instead of constructor.
     * @param job
     * @param rawDataList
     * @param errorMap
     * @return CrmGlobalDataIngestionHandlerAbstract
     */
    public override CrmGlobalDataIngestionHandlerAbstract init(
        CRM_Global_Data_Ingestion_Job__c job,
        List<CRM_Global_Raw_Data_Staging__c> rawDataList,
        Map<String, List<String>> errorMap
    ) {
        super.init(job, rawDataList, errorMap);
        incidentList = new List<Incident>();
        rawDataIdList = new List<String>();
        // IncidentOwnerInfoToUser = new Map<String, User>();
        checkListRaws = new List<String>{'Incident ID', 'Incident Description', 'Status'};

        // Status picklist
        if (commonData.isEmpty() || !commonData.containsKey('Status') || commonData.get('Status') == null) {
            List<String> incidentStatusPicklistValue = new List<String>();
            for(Schema.PicklistEntry entry : Schema.getGlobalDescribe()
                .get('Incident')
                .getDescribe()
                .fields.getMap()
                .get('Status')
                .getDescribe()
                .getPicklistValues()) {
                    
                incidentStatusPicklistValue.add(entry.getValue());
            }
            commonData.put('Status', incidentStatusPicklistValue);
        }

        return this;
    }

    /**
     * @method processTargetResult
     * @description Process Target Result.
     * @return Database.UpsertResult[]
     */
    protected override Database.UpsertResult[] processTargetResult() {

        // Upsert Child Outbound Case
        Database.UpsertResult[] resultUpserts = new List<Database.UpsertResult>();
        if (!incidentList.isEmpty() && !rawDataIdList.isEmpty()) {
            resultUpserts = upsertIncidents();
        }
        return resultUpserts;
    }

    /**
     * @method handleRawData
     * @description handle Raw Data
     */
    protected override void handleRawData() {
        try {
            
            for (CRM_Global_Raw_Data_Staging__c raw : rawDataList) {
                Map<String, Object> rawMap = (Map<String, Object>) JSON.deserializeUntyped(raw.CRM_Global_RawJSONData__c);
                String incidentID = rawMap.containsKey('Incident ID') ? String.valueof(rawMap.get('Incident ID')) : '';
                String incidentDescription = rawMap.containsKey('Incident Description') ? (String)rawMap.get('Incident Description') : '';
                String status = rawMap.containsKey('Status') ? (String)rawMap.get('Status') : 'New';

                if (errorMap.containsKey(raw.Id)) {
                    continue;
                }

                Incident incidentItem = new Incident();
                incidentItem.Status = status;
                incidentItem.CRM_Global_IncidentDescription__c = incidentDescription;
                incidentItem.CRM_Global_IncidentID__c = incidentID;
                incidentList.add(incidentItem);
                rawDataIdList.add(raw.Id);
            }

        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('Error Handle Raw Data And Prepare Outbound Incident records: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Error Handle Raw Data And Prepare Outbound Incident records: ' + e.getMessage() + '#line:' + e.getLineNumber());
            throw e;
        }
    }

    /**
     * @method validateRawData
     * @description Validate Raw Data.
     */
    protected override void validateRawData() {
        try {
            
            for (CRM_Global_Raw_Data_Staging__c raw : rawDataList) {
                Map<String, Object> rawMap = (Map<String, Object>) JSON.deserializeUntyped(raw.CRM_Global_RawJSONData__c);

                List<String> errorMessageList = new List<String>();
                for (String rawKey : checkListRaws) {
                    String errorMessage= checkRawDataItem(
                        rawKey,
                        rawMap.containsKey(rawKey) ? String.valueof(rawMap.get(rawKey)) : ''
                    );
                    if (String.isNotBlank(errorMessage)) {
                        errorMessageList.add(errorMessage);
                    }
                }
                if (!errorMessageList.isEmpty()) {
                    errorMap.put(raw.Id, errorMessageList);
                }
            }

        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('Error Validate Raw Data: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Error Validate Raw Data: ' + e.getMessage() + '#line:' + e.getLineNumber());
            throw e;
        }
    }

    
    /**
     * checkRawDataItem
     * @description Check Raw Data Item.
     * @param rawKey
     * @param rawDataItem
     * @return String
     */
    protected override String checkRawDataItem(String rawKey, String rawDataItem) {
        try {
            //System.debug(LoggingLevel.INFO, 'Check Raw Data Item: ' + rawKey + ':' + String.valueOf(rawDataItem));
            String errorMessage;
            if (String.isBlank(rawDataItem)) {
                return rawKey + ' is Empty';
            }
            if (rawKey == 'Status') {
                if (!((List<String>)commonData.get('Status')).contains(rawDataItem)) {
                    return 'Status [' + rawDataItem +  '] is not a correct value';
                }
            }

            return errorMessage;
        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('Error Check Raw Data Item: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Error Check Raw Data Item: ' + e.getMessage() + '#line:' + e.getLineNumber());
            throw e;
        }
    }


     /**
     * setAttribute
     * @description Set Attribute.
     * @param attributeName
     * @param attributeValue
     * @return CrmGlobalDataIngestionHandlerAbstract
     */
    public override CrmGlobalDataIngestionHandlerAbstract setAttribute(String attributeName, Object attributeValue) {
        return this;
    }

    /**
     * getAttribute
     * @description Get Attribute.
     * @param attributeName
     * @return Object
     */
    public override Object getAttribute(String attributeName){
        return super.getAttribute(attributeName);
    }

    /**
     * @method upsertRelatedIncident
     * @description Upsert Related Incident.
     * @param incidentList
     * @return Database.UpsertResult[]
     */
    private Database.UpsertResult[] upsertIncidents() {
        Database.UpsertResult[] resultInserts;
        try {
            if (!incidentList.isEmpty()) {
                Map<String, Incident> existIncident = new Map<String, Incident>();
                for (Incident inc : incidentList) {
                    if (inc.Id == null) {
                        existIncident.put(inc.CRM_Global_IncidentID__c, new Incident());
                    }
                }

                if (existIncident.keySet().size() > 0) {
                    for (Incident inc : [SELECT Id, CRM_Global_IncidentID__c  FROM Incident WHERE CRM_Global_IncidentID__c IN :existIncident.keySet()]) {
                        existIncident.put(inc.CRM_Global_IncidentID__c, inc);
                    }
                }

                for (Incident inc : incidentList) {
                    if (inc.Id == null && String.isNotBlank(existIncident.get(inc.CRM_Global_IncidentID__c).Id)) {
                        inc.Id = existIncident.get(inc.CRM_Global_IncidentID__c).Id;
                    }
                }

                resultInserts = Database.upsert(incidentList, false);
                System.debug(LoggingLevel.INFO, resultInserts.toString());
                System.debug(LoggingLevel.INFO, 'Upsert ' + incidentList.size() + ' Incident.');
            }
        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('Scheduler Upsert Related Incident: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Scheduler Upsert Related Incident: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
        return resultInserts;
    }
}