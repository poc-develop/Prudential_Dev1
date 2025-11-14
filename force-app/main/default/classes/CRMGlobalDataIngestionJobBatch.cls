/**
 * CRMGlobalDataIngestionJobBatch
 * @author       : Easin Zhou
 * @date         : 2025-11-11
 * @description  : Data Ingestion Job Batch.
 */
public with sharing class CRMGlobalDataIngestionJobBatch implements Database.Batchable<sObject>, Database.Stateful  {

    /**
     * @description Current Jobs.
     */
    public CRM_Global_Data_Ingestion_Job__c currentJob;

    /**
     * @description Current Job Type.
     */
    public String currentJobType;

    /**
     * @description Max Processing Attempts.
     */
    public Integer maxProcessingAttempts = 3;

    /**
     * @description Remain Jobs.
     */
    public List<CRM_Global_Data_Ingestion_Job__c> remainJobs;

    /**
     * @description handler.
     */
    public CrmGlobalDataIngestionHandlerAbstract handler;

    /**
     * @description Raw Data Id Map to Raw Data.
     */
    public Map<String, CRM_Global_Raw_Data_Staging__c> rawDataMap;

    /**
     * @description batch Size Job Handler.
     */
    public Integer batchSizeJobHandler = 50;

    /**
     * @method constructor
     * @description constructor
     * @param allJobs
     * @param batchSize
     */
    public CRMGlobalDataIngestionJobBatch(List<CRM_Global_Data_Ingestion_Job__c> allJobs, Integer batchSize) {
        currentJob = new CRM_Global_Data_Ingestion_Job__c();
        remainJobs = new List<CRM_Global_Data_Ingestion_Job__c>();
        currentJobType = 'Cases';

        if (batchSize != null && batchSize > 0) {
            batchSizeJobHandler = batchSize;
        }

        if (allJobs.size() > 0) {
            for (Integer i = 0; i < allJobs.size(); i++) {
                if (i == 0) {
                    currentJob = allJobs[0];
                    currentJobType = currentJob.CRM_Global_TargetObject__c;
                } else {
                    remainJobs.add(allJobs[i]);
                }
            }

            if (currentJobType == 'Cases') {
                handler = CrmGlobalDataIngestionHandlerAbstract.getInstance('CrmGlobalDataIngestionHandlerCase').init(currentJob);
            }else if(currentJobType == 'Incidents'){
                handler = CrmGlobalDataIngestionHandlerAbstract.getInstance('CrmGlobalDataIngestionHandlerIncident').init(currentJob);
            }else if(currentJobType == 'IncidentRelatedItems'){
                handler = CrmGlobalDataIngestionHandlerAbstract.getInstance('CrmGlobalDataIngestionHandlerImP').init(currentJob);
            }

        }

        System.debug(LoggingLevel.INFO, 'CRMGlobalDataIngestionJobBatch constructor:' + allJobs.size());
    }

    /**
     * @description start
     * @param bc
     * @return Database.QueryLocator
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, CRM_Global_RawJSONData__c, CRM_Global_DataIngestionJob__c,
            CRM_Global_FailureMessage__c, CRM_Global_ProcessingAttempts__c, CRM_Global_ProcessingStatus__c,
            CRM_Global_DataIngestionJob__r.CRM_Global_Channel__c, CRM_Global_DataIngestionJob__r.CRM_Global_Sub_Type_1__c, 
            CRM_Global_DataIngestionJob__r.CRM_Global_Call_Type__c
            FROM CRM_Global_Raw_Data_Staging__c
            WHERE CRM_Global_DataIngestionJob__c = :currentJob.Id AND CRM_Global_ProcessingStatus__c = 'Pending'
        ]);

    }

    /**
     * @description execute
     * @param bc
     * @param transactionSummaries
     */
    public void execute(Database.BatchableContext bc, list<CRM_Global_Raw_Data_Staging__c> rawDataStagings) {
        
        if (rawDataStagings.size() == 0) {
            return;
        }

        try {

            Map<String, List<String>> errorMap = new Map<String, List<String>>();

            handler = handler.init(currentJob, rawDataStagings, errorMap);
            Database.UpsertResult[] resultUpserts = handler.processJob();
            List<String> rawDataIdList = (List<String>)handler.getAttribute('rawDataIdList');

            // Update Job and Raw Status
            rawDataMap = new Map<String, CRM_Global_Raw_Data_Staging__c>();
            for (CRM_Global_Raw_Data_Staging__c rawData : rawDataStagings) {
                rawDataMap.put(rawData.Id, rawData);
            }
            updateRawDataStatus(resultUpserts, rawDataIdList, errorMap);

        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('Scheduler execution failed: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Scheduler execution failed: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }


    }

    /**
     * @description finish
     * @param bc
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'Finish: ' + (currentJob != null ? currentJob.Id : ''));
        if (currentJob != null && currentJob.Id != null) {
            updateJobStatus();
        }

        if (remainJobs != null && remainJobs.size() > 0) {
            Database.executeBatch(new CRMGlobalDataIngestionJobBatch(remainJobs, batchSizeJobHandler), batchSizeJobHandler);
        }
    }


    /**
     * @method updateRawDataStatus
     * @description update Raw Data Status.
     * @param resultUpserts
     * @param rawDataIdList
     * @param errorMap
     */
    private void updateRawDataStatus(Database.UpsertResult[] resultUpserts, List<String> rawDataIdList, Map<String, List<String>> errorMap) {
        try {
            List<CRM_Global_Raw_Data_Staging__c> rawsToUpdate = new List<CRM_Global_Raw_Data_Staging__c>();
            if (!errorMap.keySet().isEmpty()) {
                for (String rawDid : errorMap.keySet()) {
                    if (rawDataMap.containsKey(rawDid)) {
                        Decimal attempts = rawDataMap.get(rawDid).CRM_Global_ProcessingAttempts__c != null ?
                                            rawDataMap.get(rawDid).CRM_Global_ProcessingAttempts__c + 1 :
                                            1;
                        CRM_Global_Raw_Data_Staging__c raw = new CRM_Global_Raw_Data_Staging__c(
                            Id = rawDid,
                            CRM_Global_ProcessingStatus__c = attempts >= maxProcessingAttempts ? 'Error' : 'Pending',
                            CRM_Global_FailureMessage__c = String.join(errorMap.get(rawDid), ' ;'),
                            CRM_Global_ProcessingAttempts__c = attempts
                        );
                        rawsToUpdate.add(raw);
                    }
                }
            }
            if (resultUpserts != null && rawDataIdList != null && !rawDataIdList.isEmpty()) {
                for (Integer i = 0; i < resultUpserts.size(); i++) {
                    Id rawId = rawDataIdList.get(i);
                    if (rawId == null) {
                        continue;
                    }
    
                    if (!rawDataMap.containsKey(rawId)) {
                        continue;
                    }

                    CRM_Global_Raw_Data_Staging__c raw = new CRM_Global_Raw_Data_Staging__c(Id = rawId);
                    
                    if (resultUpserts[i].isSuccess()) {
                        raw.CRM_Global_ProcessingStatus__c = 'Success';
                        raw.CRM_Global_FailureMessage__c = null;
                    } else {
                        Decimal attempts = rawDataMap.get(rawId).CRM_Global_ProcessingAttempts__c != null ?
                                            rawDataMap.get(rawId).CRM_Global_ProcessingAttempts__c + 1 :
                                            1;

                        raw.CRM_Global_ProcessingStatus__c = attempts >= maxProcessingAttempts ? 'Error' : 'Pending';
                        raw.CRM_Global_FailureMessage__c = resultUpserts[i].getErrors()[0].getMessage();
                        raw.CRM_Global_ProcessingAttempts__c = attempts;
                       
                    }
    
                    rawsToUpdate.add(raw);
                }
            }

            if (!rawsToUpdate.isEmpty()) {
                Database.update(rawsToUpdate, false);
                System.debug(LoggingLevel.INFO, 'Updated ' + rawsToUpdate.size() + ' raw record statuses.');
            }
        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('Scheduler Update Raw Data Status failed: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Scheduler Update Raw Data Status failed: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
    }

    
    /**
     * @method updateJobStatus
     * @description update Job Status.
     * @param allJobIdSet
     */
    private void updateJobStatus() {

        try {
            currentJob.CRM_Global_FailedRecords__c = 0;
            currentJob.CRM_Global_SuccessRecords__c = 0;
            currentJob.CRM_Global_TotalRecords__c = 0;

            for (CRM_Global_Raw_Data_Staging__c rawDataStaging : [SELECT Id, CRM_Global_ProcessingStatus__c, CRM_Global_DataIngestionJob__c FROM CRM_Global_Raw_Data_Staging__c WHERE CRM_Global_DataIngestionJob__c = :currentJob.Id]) {
                if (rawDataStaging.CRM_Global_ProcessingStatus__c == 'Success') {
                    currentJob.CRM_Global_SuccessRecords__c += 1;
                } else if (rawDataStaging.CRM_Global_ProcessingStatus__c == 'Error') {
                    currentJob.CRM_Global_FailedRecords__c += 1;
                }
                currentJob.CRM_Global_TotalRecords__c += 1;
            }
            
            if (currentJob.CRM_Global_TotalRecords__c == 0) {
                currentJob.CRM_Global_Status__c = 'Failed';
            } else if (currentJob.CRM_Global_FailedRecords__c + currentJob.CRM_Global_SuccessRecords__c < currentJob.CRM_Global_TotalRecords__c) {
                currentJob.CRM_Global_Status__c = 'Processing';
            } else if (currentJob.CRM_Global_FailedRecords__c > 0 && currentJob.CRM_Global_SuccessRecords__c == 0) {
                currentJob.CRM_Global_Status__c = 'Failed';
                currentJob.CRM_Global_EndTime__c = Datetime.now();
            } else if (currentJob.CRM_Global_FailedRecords__c > 0 && currentJob.CRM_Global_SuccessRecords__c > 0) {
                currentJob.CRM_Global_Status__c = 'Completed With Errors';
                currentJob.CRM_Global_EndTime__c = Datetime.now();
            } else if (currentJob.CRM_Global_FailedRecords__c == 0 && currentJob.CRM_Global_SuccessRecords__c > 0) {
                currentJob.CRM_Global_Status__c = 'Completed';
                currentJob.CRM_Global_EndTime__c = Datetime.now();
            }

            // Update Job status
            Database.update(currentJob, false);

        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('Batch Update Job Status failed: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Batch Update Job Status failed: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
    }


}