/**
 * CrmGlobalDataIngestionHandlerImP
 * @author       : Mark
 * @date         : 2025-11-06
 * @description  : Class for Data Ingestion Job IncidentRelatedItem Handler.
 */
public with sharing class CrmGlobalDataIngestionHandlerImP extends CrmGlobalDataIngestionHandlerAbstract {

    /**
     * @description Policy No Map To policy.
     */
    public Map<String, InsurancePolicy> policyNoToIncidentPolicy;

    /**
     * @description incident Id Map To Incident.
     */
    public Map<String, Incident> incidentIdToIncident;
    
    /**
     * @description Policy ID Map To AccountId.
     */
    public Map<String, String> policyIdToAccountId;

    /**
     * @description Item ID Map to incident id.
     */
    public Map<String, String> ItemIdToIncidentId;

        /**
     * @description Item ID Map to incident.
     */
    public Map<String, String> ItemIdToPolicyId;

    /**
     * @description Outbound IncidentRelatedItem List.
     */
    public List<IncidentRelatedItem> incidentRelatedItemList;


    /**
     * @description Policy No Map To policy.
     */
    public Map<String, InsurancePolicy> globalPolicyIdToPolicyMap;

     /**
     * @description Policy No Map To Asset.
     */
    public Map<String, Asset> policyNoToAsset;

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
        policyNoToIncidentPolicy = new Map<String, InsurancePolicy>();
        incidentIdToIncident = new Map<String, Incident>();
        policyIdToAccountId = new Map<String, String>();
        globalPolicyIdToPolicyMap = new Map<String, InsurancePolicy>();
        ItemIdToIncidentId = new Map<String, String>();
        ItemIdToPolicyId = new Map<String, String>();   
        incidentRelatedItemList = new List<IncidentRelatedItem>();
        policyNoToAsset =  new Map<String,Asset>();
        rawDataIdList = new List<String>();

        checkListRaws = new List<String>{'Policy No', 'Incident ID'};

        prepareIncidentPolicy();
        return this;
    }

    /**
     * @method processTargetResult
     * @description Process Target Result.
     * @return Database.UpsertResult[]
     */
    protected override Database.UpsertResult[] processTargetResult() {
        // // Deduplicate
        // deduplicateIncidentRelatedItems();        
        Database.UpsertResult[] resultUpserts = new List<Database.UpsertResult>();
        if (!incidentRelatedItemList.isEmpty() && !rawDataIdList.isEmpty()) {
            resultUpserts = upsertIncidentRelatedItems();
        }
        return resultUpserts;
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
     * @method handleRawData
     * @description handle Raw Data
     */
    protected override void handleRawData() {
        try {
            
            for (CRM_Global_Raw_Data_Staging__c raw : rawDataList) {
                Map<String, Object> rawMap = (Map<String, Object>) JSON.deserializeUntyped(raw.CRM_Global_RawJSONData__c);
                String incidentRelatedItemIPolicyNo = rawMap.containsKey('Policy No') ? String.valueof(rawMap.get('Policy No')) : '';
                String incidentRelatedItemIncidentID = rawMap.containsKey('Incident ID') ? String.valueof(rawMap.get('Incident ID')) : '';

                if (errorMap.containsKey(raw.Id)) {
                    continue;
                }

                if (!policyNoToIncidentPolicy.containsKey(incidentRelatedItemIPolicyNo)) {
                    continue;
                }
                
                if (!incidentIdToIncident.containsKey(incidentRelatedItemIncidentID)) {
                    continue;
                }

                IncidentRelatedItem incidentRelatedItemItem = new IncidentRelatedItem();
                // incidentRelatedItemItem.CRM_Global_IncidentID__c = incidentRelatedItemIncidentID;

                
                incidentRelatedItemItem.CRM_Global_IncidentID__c =  incidentRelatedItemIncidentID;
                incidentRelatedItemItem.CRM_Global_PolicyNo__c = policyNoToIncidentPolicy.containsKey(incidentRelatedItemIPolicyNo) ? policyNoToIncidentPolicy.get(incidentRelatedItemIPolicyNo).Id : '';

                incidentRelatedItemList.add(incidentRelatedItemItem);
                rawDataIdList.add(raw.Id);
            }

        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('Error Handle Raw Data And Prepare  IncidentRelatedItem records: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Error Handle Raw Data And Prepare IncidentRelatedItem records: ' + e.getMessage() + '#line:' + e.getLineNumber());
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
            if (rawKey == 'Policy No') {
                if (!policyNoToIncidentPolicy.containsKey(rawDataItem)) {
                    return 'Policy No [' + rawDataItem + '] unable to find the correct Policy';
                }
            }
            if (rawKey == 'Incident ID') {
                if (!incidentIdToIncident.containsKey(rawDataItem)) {
                    return 'Incident ID [' + rawDataItem + '] unable to find the Incident ID';
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
     * @method prepareIncidentPolicy
     * @description Prepare policyNoToIncidentPolicy.
     */
    private void prepareIncidentPolicy() {
        try {
            Set<String> policyNoSet = new Set<String>();
            Set<String> incidentIdSet = new Set<String>();
            Map<String,String> assetNameToAssetId = new Map<String,String>();

            for (CRM_Global_Raw_Data_Staging__c rawRecord : rawDataList) {
                Map<String, Object> rawMap = (Map<String, Object>) JSON.deserializeUntyped(rawRecord.CRM_Global_RawJSONData__c);
                if (String.isNotBlank(String.valueOf(rawMap.get('Policy No')))) {
                    policyNoSet.add(String.valueOf((Object)rawMap.get('Policy No')));
                }
                if (String.isNotBlank(String.valueOf(rawMap.get('Incident ID')))) {
                    incidentIdSet.add(String.valueOf((Object)rawMap.get('Incident ID')));
                }
            }
            if (!policyNoSet.isEmpty()) {
                for (InsurancePolicy policy : [SELECT Id, NameInsured.Id, Name FROM InsurancePolicy WHERE Name IN :policyNoSet]) {
                    policyNoToIncidentPolicy.put(policy.Name, policy);
                    policyIdToAccountId.put(policy.Id, policy.NameInsured.Id);
                    globalPolicyIdToPolicyMap.put(policy.Id, policy);
                }
                for(Asset asset : [SELECT Id,Name FROM Asset WHERE Name IN :policyNoSet]){
                    assetNameToAssetId.put(asset.Name,asset.Id);
                }
                if(!policyNoToIncidentPolicy.keySet().isEmpty()){
                    for (String policyNo : policyNoToIncidentPolicy.keySet()) {
                        if(!assetNameToAssetId.containsKey(policyNo)){
                            policyNoToAsset.put(policyNo,(new Asset(
                                Name = policyNo,
                                AccountId = policyIdToAccountId.get(policyNoToIncidentPolicy.get(policyNo).Id)
                                )));
                        }
                    }
                }
            }

            if (!incidentIdSet.isEmpty()) {
                
                for(Incident inc : [SELECT Id,CRM_Global_IncidentID__c FROM Incident WHERE CRM_Global_IncidentID__c IN :incidentIdSet]){
                    incidentIdToIncident.put(inc.CRM_Global_IncidentID__c,inc);
                }
                // for (IncidentRelatedItem item : [SELECT Id,IncidentId,CRM_Global_IncidentID__c FROM IncidentRelatedItem WHERE CRM_Global_IncidentID__c IN :incidentIdSet]) {
                //     ItemIdToIncidentId.put(item.Id,item.IncidentId);
                // }
                // for (IncidentRelatedItem item : [SELECT Id,CRM_Global_PolicyNo__c FROM IncidentRelatedItem WHERE CRM_Global_PolicyNo__r.Name IN :policyNoSet]) {
                //     ItemIdToPolicyId.put(item.Id,item.CRM_Global_PolicyNo__c);
                // }
            }
            // Upsert Master
            Database.upsert(policyNoToAsset.values(), false); 
        } catch (Exception e) {
             CRMGlobalLogManager.addApexErrorLog('Scheduler Prepare And Upsert Asset failed: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
             System.debug(LoggingLevel.ERROR, 'Scheduler Prepare And Upsert Asset failed: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
    } 

    /**
     * @method upsertRelatedIncidentRelatedItem
     * @description Upsert Related IncidentRelatedItem.
     * @param incidentRelatedItemList
     * @return Database.UpsertResult[]
     */
    private Database.UpsertResult[] upsertIncidentRelatedItems() {
        Database.UpsertResult[] resultInserts;
        try {
            if (!incidentRelatedItemList.isEmpty()) {
                // Map<String, IncidentRelatedItem> policyNameToIncidentRelatedItem = new Map<String, IncidentRelatedItem>();
                
                Map<String, String> policyNoToAssetId = new Map<String, String>();
                Set<String> incidentIdSet = new Set<String>();
                Set<String> duplicateItemIdSet = new Set<String>();
                List<IncidentRelatedItem> incidentRelatedItemListNew = new List<IncidentRelatedItem>();
                List<String> rawDataIdListNew = new List<String>();
                // for (IncidentRelatedItem incidentRelatedItem : incidentRelatedItemList) {
                //     if (incidentRelatedItem.Id == null) {
                //         policyNameToIncidentRelatedItem.put(incidentRelatedItem.CRM_Global_PolicyNo__c, new IncidentRelatedItem());
                //     }
                // }

                // if (policyNameToIncidentRelatedItem.keySet().size() > 0) {
                //     for (IncidentRelatedItem item : [SELECT Id, CRM_Global_PolicyNo__c  FROM IncidentRelatedItem WHERE CRM_Global_PolicyNo__c IN :policyNameToIncidentRelatedItem.keySet()]) {
                //         policyNameToIncidentRelatedItem.put(item.CRM_Global_PolicyNo__c, item);
                //     }
                // }

                // for (IncidentRelatedItem incidentRelatedItem : incidentRelatedItemList) {
                //     if (incidentRelatedItem.Id == null && String.isNotBlank(policyNameToIncidentRelatedItem.get(incidentRelatedItem.CRM_Global_PolicyNo__c).Id)) {
                //         incidentRelatedItem.Id = policyNameToIncidentRelatedItem.get(incidentRelatedItem.CRM_Global_PolicyNo__c).Id;
                //     }
                // }
                for(Asset asset : [SELECT Id, Name FROM Asset WHERE Name IN :policyNoToIncidentPolicy.keySet()]){
                    policyNoToAssetId.put(asset.Name,asset.Id);
                }
                for (String policyNo : policyNoToIncidentPolicy.keySet()) {
                    for(IncidentRelatedItem incidentRelatedItem : incidentRelatedItemList){
                        if(policyNoToIncidentPolicy.get(policyNo).Id == incidentRelatedItem.CRM_Global_PolicyNo__c){
                            incidentRelatedItem.AssetId = policyNoToAssetId.get(policyNo);
                        }
                    }
                }
                   
                //bind account id
                for (IncidentRelatedItem incidentRelatedItem : incidentRelatedItemList) {
                        String policyId = (incidentRelatedItem.CRM_Global_PolicyNo__c != null) 
                            ? incidentRelatedItem.CRM_Global_PolicyNo__c 
                            : null;
                        if (policyId != null && policyIdToAccountId.containsKey(policyId)) {
                            incidentRelatedItem.Account__c = policyIdToAccountId.get(policyId);
                        }
                }

                for (IncidentRelatedItem incidentRelatedItem : incidentRelatedItemList) {
                    incidentIdSet.add(incidentRelatedItem.CRM_Global_IncidentID__c);
                }
                 //bind incident id
                if (!incidentIdSet.isEmpty()) {  
                    Map<String, Id> globalIncidentIdToIncidentIdMap = new Map<String, Id>();
                    incidentRelatedItemListNew.clear();
                    rawDataIdListNew.clear();
                    for (Incident incident : [SELECT Id, CRM_Global_IncidentID__c 
                                            FROM Incident 
                                            WHERE CRM_Global_IncidentID__c IN :incidentIdSet]) {
                        if (incident.CRM_Global_IncidentID__c != null) {
                            globalIncidentIdToIncidentIdMap.put(incident.CRM_Global_IncidentID__c, incident.Id);
                        }
                    }
                    
                    for (Integer i = 0; i < incidentRelatedItemList.size(); i++) {
                        IncidentRelatedItem incidentRelatedItem = incidentRelatedItemList.get(i);
                        String itemGlobalIncidentId = incidentRelatedItem.CRM_Global_IncidentID__c;
                        Id rawId = rawDataIdList.get(i);
                        if (itemGlobalIncidentId != null && globalIncidentIdToIncidentIdMap.containsKey(itemGlobalIncidentId)) {
                            incidentRelatedItem.IncidentId = globalIncidentIdToIncidentIdMap.get(itemGlobalIncidentId);
                            incidentRelatedItemListNew.add(incidentRelatedItem);
                            rawDataIdListNew.add(rawId);
                        }
                    }
                    if(incidentRelatedItemListNew.size () > 0){
                        incidentRelatedItemList.clear();
                        rawDataIdList.clear();
                        incidentRelatedItemList.addAll(incidentRelatedItemListNew);
                        rawDataIdList.addAll(rawDataIdListNew);
                    }
                }

                if(!globalPolicyIdToPolicyMap.keySet().isEmpty()){
                    incidentRelatedItemListNew.clear();
                    rawDataIdListNew.clear();
                    for (Integer i = 0; i < incidentRelatedItemList.size(); i++) {
                        IncidentRelatedItem incidentRelatedItem = incidentRelatedItemList.get(i);
                        String itemGlobalPolicyId = incidentRelatedItem.CRM_Global_PolicyNo__c;
                        Id rawId = rawDataIdList.get(i);
                        if (itemGlobalPolicyId != null && globalPolicyIdToPolicyMap.containsKey(itemGlobalPolicyId)) {
                            incidentRelatedItemListNew.add(incidentRelatedItem);
                            rawDataIdListNew.add(rawId);
                        }
                    }
                    if(incidentRelatedItemListNew.size () > 0){
                        incidentRelatedItemList.clear();
                        rawDataIdList.clear();
                        incidentRelatedItemList.addAll(incidentRelatedItemListNew);
                        rawDataIdList.addAll(rawDataIdListNew);
                    }
                }

                // if (!ItemIdToPolicyId.keySet().isEmpty() && ItemIdToIncidentId.keySet().size() > 0) {
                //     for (String itemId : ItemIdToPolicyId.keySet()) {
                //         if (String.isNotBlank(ItemIdToIncidentId.get(itemId))) {
                //             duplicateItemIdSet.add(itemId);
                //         }
                //     }
                // }
                // if (!duplicateItemIdSet.isEmpty()) {
                //     incidentRelatedItemListNew.clear();
                //     for (Integer i = 0; i < incidentRelatedItemList.size(); i++) {
                //         IncidentRelatedItem item = incidentRelatedItemList.get(i);
                //         if (!duplicateItemIdSet.contains(item.id)) {
                //             incidentRelatedItemListNew.add(item);
                //         }
                //     }
                //     incidentRelatedItemList.clear();
                //     incidentRelatedItemList.addAll(incidentRelatedItemListNew);
                // }
                resultInserts = Database.upsert(incidentRelatedItemList, false);
                System.debug(LoggingLevel.INFO, resultInserts.toString());
                System.debug(LoggingLevel.INFO, 'Upsert ' + incidentRelatedItemList.size() + ' IncidentRelatedItem.');
            }
        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('Scheduler Upsert Related IncidentRelatedItem: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Scheduler Upsert Related IncidentRelatedItem: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
        return resultInserts;
    }

    // /**
    //  * @method deduplicateIncidentRelatedItems
    //  * @description Deduplicate IncidentRelatedItem.
    //  * @param incidentRelatedItemList
    //  * @param rawDataIdList
    //  * @param errorMap
    //  */
    // private void deduplicateIncidentRelatedItems() {
    //     try {
    //         List<incidentRelatedItem> incidentRelatedItemListNew = new List<incidentRelatedItem>();
    //         List<String> rawDataIdListNew = new List<String>();
    //         Set<String> policySet = new Set<String>();

    //         for (Integer i = 0; i < incidentRelatedItemList.size(); i++) {
    //             Id rawId = rawDataIdList.get(i);
    //             IncidentRelatedItem incidentRelatedItem = incidentRelatedItemList.get(i);
    //             if (!policySet.contains(incidentRelatedItem.CRM_Global_PolicyNo__c)) {
    //                 incidentRelatedItemListNew.add(incidentRelatedItem);
    //                 rawDataIdListNew.add(rawId);
    //                 policySet.add(incidentRelatedItem.CRM_Global_PolicyNo__c);
    //             } else {
    //                 errorMap.put(rawId, new List<String>{'There is already a job with the current policy in the  of the currently executing task'});
    //             }
    //         }
    //         if (incidentRelatedItemList.size() != incidentRelatedItemListNew.size()) {
    //             incidentRelatedItemList.clear();
    //             rawDataIdList.clear();
    //             incidentRelatedItemList.addAll(incidentRelatedItemListNew);
    //             rawDataIdList.addAll(rawDataIdListNew);
    //         }
    //     } catch (Exception e) {
    //         CRMGlobalLogManager.addApexErrorLog('Scheduler Deduplicate incidentRelatedItem : ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
    //         System.debug(LoggingLevel.ERROR, 'Scheduler Deduplicate incidentRelatedItem : ' + e.getMessage() + '#line:' + e.getLineNumber());
    //     }
    // }

}