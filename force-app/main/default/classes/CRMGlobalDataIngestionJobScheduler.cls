/**
 * CRMGlobalDataIngestionJobScheduler
 * @author       : Easin Zhou
 * @date         : 2025-10-15
 * @description  : For scheduling the processing of uploaded lists.
 */
public with sharing class CRMGlobalDataIngestionJobScheduler implements Schedulable {
    /**
     * @description Job Limit Number Of Per Execute.
     */
    public Integer jobLimitNumberPerExecute = 1;

    /**
     * @description batch Size Job Handler.
     */
    public Integer batchSizeJobHandler = 50;

    /**
     * @description Processing Jobs.
     */
    public List<CRM_Global_Data_Ingestion_Job__c> processingJobs;

    /**
     * @method constructor
     * @description constructor
     */
    public CRMGlobalDataIngestionJobScheduler() {
        System.debug(LoggingLevel.INFO, 'CRMGlobalDataIngestionJobScheduler constructor');
    }

    /**
     * @method constructor
     * @description constructor
     * @param jobLimitNumber
     * @param batchSize
     */
    public CRMGlobalDataIngestionJobScheduler(Integer jobLimitNumber, Integer batchSize) {
        if (jobLimitNumber != null && jobLimitNumber > 0 && jobLimitNumber <= 5) {
            jobLimitNumberPerExecute = jobLimitNumber;
        }
        if (batchSize != null && batchSize > 0) {
            batchSizeJobHandler = batchSize;
        }
    }


    /**
     * @method execute
     * @description Entry of scheduler
     * @param sc
     */
    public void execute(SchedulableContext sc) {
        beginExecuteJob();
    }

    /**
     * @method beginExecuteJob
     * @description Method of entry
     */
    public void beginExecuteJob() {
        try {
            prepareJobAndRawData();

            if (processingJobs.size() > 0) {
                Database.executeBatch(new CRMGlobalDataIngestionJobBatch(processingJobs, batchSizeJobHandler), batchSizeJobHandler);
            }

        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('Scheduler execution failed: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Scheduler execution failed: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
    }


    /**
     * @method prepareJobAndRawData
     * @description Prepare Ingestion Job And Raw Data
     */
    private void prepareJobAndRawData() {
        processingJobs = new List<CRM_Global_Data_Ingestion_Job__c>();

        try {
            // Prepare Data Ingestion Job
            if (Schema.sObjectType.CRM_Global_Data_Ingestion_Job__c.isAccessible()) {
                processingJobs = [
                    SELECT Id, CRM_Global_TargetObject__c, CRM_Global_Status__c, CRM_Global_EndTime__c, CRM_Global_ErrorSummary__c,
                    CRM_Global_FailedRecords__c, CRM_Global_SuccessRecords__c, CRM_Global_TotalRecords__c,
                    CRM_Global_Channel__c, CRM_Global_Sub_Type_1__c, CRM_Global_Call_Type__c
                    FROM CRM_Global_Data_Ingestion_Job__c
                    WHERE CRM_Global_Status__c = 'Processing'
                    ORDER BY CreatedDate ASC
                    LIMIT :jobLimitNumberPerExecute
                ];
            } else {
                System.debug(LoggingLevel.ERROR, 'No access to CRM_Global_Data_Ingestion_Job__c object.');
            }
            if (processingJobs.isEmpty()) {
                return;
            }

        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('Scheduler Prepare Ingestion Job failed: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Scheduler Prepare Ingestion Job failed: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
    }

}