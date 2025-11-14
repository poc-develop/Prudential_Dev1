/**
 * @description       : Service for handling Data Integration
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-11-13
 * @last modified by  : Franco
**/
@SuppressWarnings('PMD')
public without sharing class CRMGlobalDataIntegrationService {

    private static Map<String, SObjectType> sObjectTypeMap = Schema.getGlobalDescribe();
    
    private static List<Map<String, Object>> processResponseData(Object responseData) {
        List<Map<String, Object>> recordsToProcess = new List<Map<String, Object>>();
        
        if (responseData instanceOf List<Object>) {
            for (Object item : (List<Object>)responseData) {
                if (item instanceof Map<String, Object>) {
                    recordsToProcess.add((Map<String, Object>)item);
                }
            }
        }
        else if (responseData instanceOf Map<String, Object>) {
            recordsToProcess.add((Map<String, Object>)responseData);
        }
        
        return recordsToProcess;
    }

    /**
     * @description       : Processes and upserts records
     * @param sourceData       : Source data
     * @param config       : Data Integration Configuration
     * @param recordId       : Record Id
     */
    public static void processAndUpsertRecords(Object responseData, CRMGlobalDataIntegrationConfigWrapper configWrapper) {

        // Parent record to update
        List<SObject> parentRecordToUpdate = new List<SObject>();

        // All related records
        Map<String, SObject> extIdToChildRecordMap = new Map<String, SObject>();
        // Related records to upsert
        List<SObject> relatedRecordsToInsert = new List<SObject>();
        // Related records to update
        List<SObject> relatedRecordsToUpdate = new List<SObject>();
        // Related records to delete
        List<SObject> relatedRecordsToDelete = new List<SObject>();

        for (CRMGlobalDataIntegrationTargetWrapper targetWrapper : configWrapper.targetWrappers) {
            Object targetSourceData = CRMGlobalDataIntegrationRespService.getNestedValue(responseData, targetWrapper.responsePath);
            List<Map<String, Object>> recordsToProcess = processResponseData(targetSourceData);

            List<SObject> recordsToUpsert = new List<SObject>();
            CRMGlobalLogManager.addApexInfoLog('Processing ' + recordsToProcess.size() + ' records for target object: ' + targetWrapper.targetObject);
            if(targetWrapper.resultFilter != null) {
                String filterJson = targetWrapper.resultFilter;
                if (CRMGlobalTemplateMergeFieldService.hasMergeFields(filterJson)) {
                    filterJson = CRMGlobalTemplateMergeFieldService.mergeTemplate(filterJson, configWrapper.parentRecord, false);
                }
                recordsToProcess = filterRecords(recordsToProcess, filterJson);
                CRMGlobalLogManager.addApexInfoLog('Filtered result: ' + recordsToProcess.size() + ' records for target object: ' + targetWrapper.targetObject);
            }
            Boolean isToUpdateParentRecord = false;
            for (Map<String, Object> sourceRecord : recordsToProcess) {
                // Apply field mappings
                SObject targetRecord = convertSourceDataToTargetRecord(sourceRecord, targetWrapper, configWrapper);

                // If the target object is the same as the parent object
                // It means to crate/update the parnet record itself
                if(targetWrapper.isToUpdateParent()) {
                    isToUpdateParentRecord = true;
                    targetRecord.put('Id', configWrapper.recordId);
                    parentRecordToUpdate.add(targetRecord);
                    // Assume the response contains only one record for parent update
                    // Get the 1st one if multiple records returned
                    break;
                }
                
                // Otherwise, it means to crate/update the child records
                populateParentRelationshipField(targetWrapper, configWrapper, targetRecord);

                if(targetWrapper.targetRecordTypeId != null) {
                    targetRecord.put('RecordTypeId', targetWrapper.targetRecordTypeId);
                }

                // external id equals Id means always insert
                if('Id'.equalsIgnoreCase(targetWrapper.targetExIdField)) {
                    relatedRecordsToInsert.add(targetRecord);
                } else {
                    populateExternalIdField(targetWrapper, sourceRecord, targetRecord);
                    extIdToChildRecordMap.put(String.valueOf(targetRecord.get(targetWrapper.targetExIdField)), targetRecord);
                }
                
                System.debug(LoggingLevel.INFO, '#targetRecord -> ' + targetRecord);
            }
            if(isToUpdateParentRecord) {
                continue;
            }

            Map<String, List<SObject>> relatedRecords = prepareChildRecords(targetWrapper, extIdToChildRecordMap);
            relatedRecordsToInsert.addAll(relatedRecords.get('TO_INSERT'));
            relatedRecordsToUpdate.addAll(relatedRecords.get('TO_UPDATE'));

            // Delete existing data if needed
            if(!targetWrapper.isToUpdateParent() && targetWrapper.isDeleteExistingData) {
                String deleteQuery = 'SELECT Id FROM ' + targetWrapper.targetObject + ' WHERE ' + targetWrapper.targetParentField + ' = \'' + configWrapper.recordId + '\'';
                if(String.isNotBlank(targetWrapper.targetRecordTypeId)) {
                    deleteQuery += ' AND RecordTypeId = \'' + targetWrapper.targetRecordTypeId + '\'';
                }
                relatedRecordsToDelete.addAll(Database.query(deleteQuery, AccessLevel.SYSTEM_MODE));
            }
        }

        deleteExistingData(relatedRecordsToDelete);
        performDML(parentRecordToUpdate, relatedRecordsToUpdate, relatedRecordsToInsert);
    }

    /**
     * @description Converts source data to target record
     * @param sourceData 
     * @param targetWrapper 
     * @param configWrapper 
     * @return  `SObject`
     */
    private static SObject convertSourceDataToTargetRecord(Map<String, Object> sourceData, CRMGlobalDataIntegrationTargetWrapper targetWrapper, CRMGlobalDataIntegrationConfigWrapper configWrapper) {
        SObject targetRecord = targetWrapper.targetSObjectType.newSObject();
        for (String sourceField : targetWrapper.fieldMappings.keySet()) {
            String[] sourceFieldArr = sourceField.split(':');
            String sourceFieldName = sourceFieldArr[0];
            String targetField = targetWrapper.fieldMappings.get(sourceField);
            Schema.DescribeFieldResult fieldDescribe = targetWrapper.targetFieldsMap.get(targetField.toLowerCase()).getDescribe();
            // Target Value Logic:
            // 1. get from merge field
            // 2. get from source data
            // 3. get from default value if null
            // 4. set to null if no default value
            Object targetValue = null;
            if (CRMGlobalTemplateMergeFieldService.hasMergeFields(sourceField)) {
                targetValue = CRMGlobalTemplateMergeFieldService.mergeTemplate(sourceField, configWrapper.parentRecord, false);
            } else {
                targetValue = CRMGlobalDataIntegrationRespService.getNestedValue(sourceData, sourceFieldName);
            }
            if (targetValue != null) {
                targetRecord.put(targetField, CRMGlobalDataIntegrationRespService.convertFieldValue(configWrapper, fieldDescribe, targetValue));
            } else if(sourceFieldArr.size() > 1) {
                String defaultValue = sourceFieldArr[1];
                targetRecord.put(targetField, CRMGlobalDataIntegrationRespService.convertFieldValue(configWrapper, fieldDescribe, defaultValue));
            } else {
                targetRecord.put(targetField, CRMGlobalDataIntegrationRespService.convertFieldValue(configWrapper, fieldDescribe, ''));
            }
        }
        return targetRecord;
    }

    private static void deleteExistingData(List<SObject> relatedRecordsToDelete) {
        if (!relatedRecordsToDelete.isEmpty()) {
            Database.delete(relatedRecordsToDelete, AccessLevel.SYSTEM_MODE);
            relatedRecordsToDelete.clear();
        }
    }

    /**
     * @description Perform create or update for parent record and child records.
     * @param parentRecordToUpdate 
     * @param relatedRecordsToUpdate 
     * @param relatedRecordsToInsert 
     * @exception 
     */
    private static void performDML(List<SObject> parentRecordToUpdate, List<SObject> relatedRecordsToUpdate, List<SObject> relatedRecordsToInsert) {
        try {
            List<Database.SaveResult> allSaveResults = new List<Database.SaveResult>();
            System.debug(LoggingLevel.INFO, '#parentRecordToUpdate size: '+parentRecordToUpdate.size());
            if (parentRecordToUpdate.size() > 0) {
                CRMGlobalLogManager.addApexInfoLog('Updating ' + parentRecordToUpdate[0].getSObjectType() + ' record with Id: ' + parentRecordToUpdate[0].get('Id'));
                allSaveResults.addAll(Database.update(parentRecordToUpdate, false, AccessLevel.SYSTEM_MODE));
            }

            System.debug(LoggingLevel.INFO, '#relatedRecordsToUpdate size: '+relatedRecordsToUpdate.size());
            if(relatedRecordsToUpdate.size() > 0) {
                CRMGlobalLogManager.addApexInfoLog('Updating ' + relatedRecordsToUpdate[0].getSObjectType() + ' records');
                allSaveResults.addAll(Database.update(relatedRecordsToUpdate, false, AccessLevel.SYSTEM_MODE));
            }

            System.debug(LoggingLevel.INFO, '#relatedRecordsToInsert size: '+relatedRecordsToInsert.size());
            if(relatedRecordsToInsert.size() > 0) {
                CRMGlobalLogManager.addApexInfoLog('Inserting ' + relatedRecordsToInsert[0].getSObjectType() + ' records');
                allSaveResults.addAll(Database.insert(relatedRecordsToInsert, false, AccessLevel.SYSTEM_MODE));
            }

            system.debug('parentRecordToUpdate: ' + parentRecordToUpdate);
            system.debug('relatedRecordsToUpdate: ' + relatedRecordsToUpdate);
            system.debug('relatedRecordsToInsert: ' + relatedRecordsToInsert);

            Integer successCount = 0;
            Integer failureCount = 0;
            for (Integer i = 0; i < allSaveResults.size(); i++) {
                Database.SaveResult result = allSaveResults[i];
                if (result.isSuccess()) {
                    successCount++;
                } else {
                    failureCount++;
                    for (Database.Error err : result.getErrors()) {
                        CRMGlobalLogManager.addApexErrorLog('Record insert/update error: ' + err.getMessage(), null);
                        System.debug(LoggingLevel.ERROR, 'Record insert/update error: ' + err.getMessage());
                    }
                }
            }
            System.debug(LoggingLevel.INFO, '#successCount: ' + successCount);
            System.debug(LoggingLevel.INFO, '#failureCount: ' + failureCount);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'processAndUpsertRecords Error: ' + e.getMessage() + e.getStackTraceString());
            throw new CRMGlobalDataIntegrationException(e);
        }
    }

    /**
     * @description Populate Parent relationship field
     * @param targetWrapper 
     * @param configWrapper 
     * @param targetRecord 
     */
    private static void populateParentRelationshipField(CRMGlobalDataIntegrationTargetWrapper targetWrapper, CRMGlobalDataIntegrationConfigWrapper configWrapper, SObject targetRecord) {
        // Set parent relationship if needed
        // This is to populate the lookup/master-detail field for child records
        String parentFieldName = targetWrapper.targetParentField;
        if (String.isNotBlank(parentFieldName)) {
            targetRecord.put(parentFieldName, configWrapper.recordId);
        }
    }

    /**
     * @description Populate External Id Field
     * @param targetWrapper 
     * @param sourceRecord 
     * @param targetRecord 
     */
    private static void populateExternalIdField(CRMGlobalDataIntegrationTargetWrapper targetWrapper, Map<String, Object> sourceRecord, SObject targetRecord) {
        // Set external Id field if needed
        // This is to determine whether to update or insert
        // Either use composite keys or field mapping to map the external id field
        // The composite keys will be used when both composite keys and field mapping are provided
        // String parentFieldName = targetWrapper.targetParentField;
        String externalIdFieldName = targetWrapper.targetExIdField;
        Boolean isIncludeParentId = targetWrapper.includeParentIdToExIdField;
        Boolean isIncludeParentExtId = targetWrapper.includeParentExtIdToExIdField;
        String targetRecordType = targetWrapper.targetRecordTypeId;
        SObject parentRecord = targetWrapper.parentRecord;
        List<String> compositeValues = new List<String>();
        if(isIncludeParentId) {
            compositeValues.add(String.valueOf(parentRecord.get('Id')));
        }
        if(isIncludeParentExtId) {
            compositeValues.add(String.valueOf(parentRecord.get(targetWrapper.parentExtFieldName)));
        }
        if(String.isNotBlank(targetRecordType) && !targetWrapper.isToUpdateParent() && externalIdFieldName != 'Name' && externalIdFieldName != 'FinServ__CustomerID__c') {
            compositeValues.add(targetRecordType);
        }
        if(!targetWrapper.compositeKeyFields.isEmpty()) {
            for(String key : targetWrapper.compositeKeyFields) {
                Object value = CRMGlobalDataIntegrationRespService.getNestedValue(sourceRecord, key);
                compositeValues.add(String.valueOf(value));
            }
        } else if(targetRecord.get(externalIdFieldName) != null) {
            compositeValues.add(String.valueOf(targetRecord.get(externalIdFieldName)));
        }
        targetRecord.put(externalIdFieldName, String.join(compositeValues, '_'));
    }

    /**
     * @description Prepare child records
     * @param targetWrapper 
     * @param extIdToRecordMap 
     * @return  `Map<String, List<SObject>>`
     */
    public static Map<String, List<SObject>> prepareChildRecords(CRMGlobalDataIntegrationTargetWrapper targetWrapper, Map<String, SObject> extIdToRecordMap) {
        Map<String, List<SObject>> relatedRecords = new Map<String, List<SObject>>();
        List<SObject> relatedRecordsToInsert = new List<SObject>();
        List<SObject> relatedRecordsToUpdate = new List<SObject>();
        relatedRecords.put('TO_INSERT', relatedRecordsToInsert);
        relatedRecords.put('TO_UPDATE', relatedRecordsToUpdate);

        if(extIdToRecordMap.isEmpty()) {
            return relatedRecords;
        }

        Set<String> extIdSet = extIdToRecordMap.keySet();   // NOPMD
        String externalIdField = targetWrapper.targetExIdField;
        String targetObject = targetWrapper.targetObject;
        String sql = 'SELECT Id, ' + externalIdField 
                    + ' FROM ' + targetObject 
                    + ' WHERE ' + externalIdField + ' IN :extIdSet';
        Map<String, Id> existingRecordIdMap = new Map<String, Id>();
        for(SObject existingRecord : Database.query(String.escapeSingleQuotes(sql), AccessLevel.SYSTEM_MODE)) {
            existingRecordIdMap.put(String.valueOf(existingRecord.get(externalIdField)), (Id) existingRecord.get('Id'));
        }

        // Check if record exists, populate the record id for the existing record
        // Then split the extIdToRecordMap into insert and update record list
        for(String externalId : extIdToRecordMap.keySet()) {
            SObject record = extIdToRecordMap.get(externalId);
            if(existingRecordIdMap.containsKey(externalId)) {
                record.put('Id', existingRecordIdMap.get(externalId));
                relatedRecordsToUpdate.add(record);
            } else {
                relatedRecordsToInsert.add(record);
            }
        }
        
        return relatedRecords;
    }

    /**
     * @description Filter Records
     * @param recordsToProcess 
     * @param filterJson 
     * @return  `List<Map<String, Object>>`
     */
    @TestVisible
    private static List<Map<String, Object>> filterRecords(List<Map<String, Object>> recordsToProcess, String filterJson) {
        if (recordsToProcess == null || recordsToProcess.isEmpty() || String.isBlank(filterJson)) {
            return new List<Map<String, Object>>();
        }

        Map<String, Object> filterMap = (Map<String, Object>) JSON.deserializeUntyped(filterJson);
        List<Map<String, Object>> result = new List<Map<String, Object>>();

        for (Map<String, Object> record : recordsToProcess) {
            Boolean match = true;
            for (String key : filterMap.keySet()) {
                if(!isMatch(key, record, filterMap)) {
                    match = false;
                    break;
                }
            }
            if (match) {
                result.add(record);
            }
        }
        return result;
    }

    private static Boolean isMatch(String key, Map<String, Object> record, Map<String, Object> filterMap) {
        Boolean match = true;
        if(!record.containsKey(key) || record.get(key) == null) {
            return false;
        }
        String recordVal = String.valueOf(record.get(key));
        String filterVal = String.valueOf(filterMap.get(key));
        Boolean isOROperation = filterVal.contains('|');
        List<String> filterValList = filterVal.split('\\|');

        if(isOROperation) {
            if(!filterValList.contains(recordVal)) {
                match = false;
            }
        } else if(!recordVal.equals(filterVal)) {
            match = false;
        }
        return match;
    }
}