/**
 * @description       : Service for handling Data Integration
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-19
 * @last modified by  : Franco
**/
@SuppressWarnings('PMD')
public with sharing class CRMGlobalDataIntegrationService {

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

        for (CRMGlobalDataIntegrationTargetWrapper targetWrapper : configWrapper.targetWrappers) {
            Object targetSourceData = CRMGlobalDataIntegrationRespService.getNestedValue(responseData, targetWrapper.responsePath);
            List<Map<String, Object>> recordsToProcess = processResponseData(targetSourceData);

            List<SObject> recordsToUpsert = new List<SObject>();
            for (Map<String, Object> sourceRecord : recordsToProcess) {
                SObject targetRecord = targetWrapper.targetSObjectType.newSObject();
                
                // Apply field mappings
                for (String sourceField : targetWrapper.fieldMappings.keySet()) {
                    String targetField = targetWrapper.fieldMappings.get(sourceField);
                    Object value = CRMGlobalDataIntegrationRespService.getNestedValue(sourceRecord, sourceField);
                    if (value != null) {
                        Schema.DescribeFieldResult fieldDescribe = targetWrapper.targetFieldsMap.get(targetField.toLowerCase()).getDescribe();
                        targetRecord.put(targetField, CRMGlobalDataIntegrationRespService.convertFieldValue(configWrapper, fieldDescribe, value));
                    }
                }

                // If the target object is the same as the parent object
                // It means to crate/update the parnet record itself
                if(targetWrapper.isToUpdateParent()) {
                    // isToUpdateParent = true;
                    targetRecord.put('Id', configWrapper.recordId);
                    parentRecordToUpdate.add(targetRecord);
                    // Assume the response contains only one record for parent update
                    // Get the 1st one if multiple records returned
                    break;
                }
                
                // Otherwise, it means to crate/update the child records
                populateParentRelationshipField(targetWrapper, configWrapper, targetRecord);
                populateExternalIdField(targetWrapper, sourceRecord, targetRecord);

                System.debug(LoggingLevel.INFO, '#targetRecord -> ' + targetRecord);

                extIdToChildRecordMap.put(String.valueOf(targetRecord.get(targetWrapper.targetExIdField)), targetRecord);
            }

            Map<String, List<SObject>> relatedRecords = prepareChildRecords(targetWrapper, extIdToChildRecordMap);
            relatedRecordsToInsert.addAll(relatedRecords.get('TO_INSERT'));
            relatedRecordsToUpdate.addAll(relatedRecords.get('TO_UPDATE'));
        }

        performDML(parentRecordToUpdate, relatedRecordsToUpdate, relatedRecordsToInsert);
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
                allSaveResults.addAll(Database.update(parentRecordToUpdate, false, AccessLevel.SYSTEM_MODE));
            }

            System.debug(LoggingLevel.INFO, '#relatedRecordsToUpdate size: '+relatedRecordsToUpdate.size());
            if(relatedRecordsToUpdate.size() > 0) {
                allSaveResults.addAll(Database.update(relatedRecordsToUpdate, false, AccessLevel.SYSTEM_MODE));
            }

            System.debug(LoggingLevel.INFO, '#relatedRecordsToInsert size: '+relatedRecordsToInsert.size());
            if(relatedRecordsToInsert.size() > 0) {
                allSaveResults.addAll(Database.insert(relatedRecordsToInsert, false, AccessLevel.SYSTEM_MODE));
            }

            Integer successCount = 0;
            Integer failureCount = 0;
            for (Integer i = 0; i < allSaveResults.size(); i++) {
                Database.SaveResult result = allSaveResults[i];
                if (result.isSuccess()) {
                    successCount++;
                } else {
                    failureCount++;
                    for (Database.Error err : result.getErrors()) {
                        System.debug(LoggingLevel.ERROR, ' Record insert/update error: ' + err.getMessage());
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
        String parentFieldName = targetWrapper.targetParentField;
        String externalIdFieldName = targetWrapper.targetExIdField;
        Boolean isIncludeParentId = targetWrapper.includeParentIdToExIdField;
        List<String> compositeValues = new List<String>();
        if (isIncludeParentId) {
            compositeValues.add(String.valueOf(targetRecord.get(parentFieldName)));
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

                if(targetWrapper.targetRecordTypeId != null) {
                    record.put('RecordTypeId', targetWrapper.targetRecordTypeId);
                }
                relatedRecordsToInsert.add(record);
            }
        }
        
        return relatedRecords;
    }
}