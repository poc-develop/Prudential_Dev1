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
     * @description Max Processing Attempts.
     */
    public Integer maxProcessingAttempts = 3;

    /**
     * @description Processing Jobs.
     */
    public List<CRM_Global_Data_Ingestion_Job__c> processingJobs;

    /**
     * @description Job Id To Raw Data.
     */
    public Map<String, List<CRM_Global_Raw_Data_Staging__c>> jobIdToRawData;

    /**
     * @description Raw Data Id Map to Raw Data.
     */
    public Map<String, CRM_Global_Raw_Data_Staging__c> rawDataMap;

    /**
     * @description Policy No Set.
     */
    public Set<String> policyNoSet;

    /**
     * @description Case Owner Name Map to User.
     */
    public Map<String, User> caseOwnerInfoToUser;

    /**
     * @description Policy No To Policy.
     */
    public Map<String, InsurancePolicy> policyNoToPolicy;

    /**
     * @description Account Id To Master Case.
     */
    public Map<String, Case> accountIdToMasterCase;

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
     */
    public CRMGlobalDataIngestionJobScheduler(Integer jobLimitNumber) {
        jobLimitNumberPerExecute = jobLimitNumber;
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
        processingJobs = new List<CRM_Global_Data_Ingestion_Job__c>();
        jobIdToRawData = new Map<String, List<CRM_Global_Raw_Data_Staging__c>>();
        rawDataMap = new Map<String, CRM_Global_Raw_Data_Staging__c>();
        policyNoSet = new Set<String>();
        caseOwnerInfoToUser = new Map<String, User>();
        policyNoToPolicy = new Map<String, InsurancePolicy>();
        accountIdToMasterCase = new Map<String, Case>();

        try {

            // prepare Ingestion Job And Raw Data
            prepareJobAndRawData();
            if (processingJobs.isEmpty()) {
                return;
            }

            // Prepare And Upsert Master case
            prepareUpsertMasterCase();

            // Handler
            List<Case> outboundCaseList = new List<Case>();
            List<String> rawDataIdList = new List<String>();
            List<CRM_Global_Raw_Data_Staging__c> rawDataToUpdate= new List<CRM_Global_Raw_Data_Staging__c>();
            Map<String, List<String>> errorMap = new Map<String, List<String>>();
            for (CRM_Global_Data_Ingestion_Job__c job : processingJobs) {
                CrmGlobalDataIngestionHandlerAbstract handler;

                if (job.CRM_Global_TargetObject__c == 'Cases') {
                    handler = CrmGlobalDataIngestionHandlerAbstract.getInstance('CrmGlobalDataIngestionHandlerCase')
                        .init(job, jobIdToRawData.get(job.Id), errorMap)
                        .setAttribute('policyNoToPolicy', policyNoToPolicy)
                        .setAttribute('accountIdToMasterCase', accountIdToMasterCase)
                        .setAttribute('caseOwnerInfoToUser', caseOwnerInfoToUser);
                } else {
                    System.debug(LoggingLevel.ERROR, 'Unknown target object: ' + job.CRM_Global_TargetObject__c);
                    continue;
                }

                handler.processJob();

                if (job.CRM_Global_TargetObject__c == 'Cases') {
                    outboundCaseList.addAll((List<Case>)handler.getAttribute('outboundCaseList'));
                    rawDataIdList.addAll((List<String>)handler.getAttribute('rawDataIdList'));
                }
            }
            
            // Upsert Outbound Case
            if ((!outboundCaseList.isEmpty() && !rawDataIdList.isEmpty()) || !errorMap.keySet().isEmpty()) {
                // deduplicate
                deduplicateOutboundCase(outboundCaseList, rawDataIdList, errorMap);
                
                Database.UpsertResult[] resultInserts = upsertRelatedCase(outboundCaseList);

                // Update Job and Raw Status
                updateRawDataStatus(resultInserts, rawDataIdList, errorMap);
            }

            updateJobStatus(jobIdToRawData.keySet());

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Scheduler execution failed: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
    }


    /**
     * @method prepareJobAndRawData
     * @description Prepare Ingestion Job And Raw Data
     */
    private void prepareJobAndRawData() {
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

            // Prepare Raw Data Staging
            Set<String> caseOwnerSet = new Set<String>();
            if (Schema.sObjectType.CRM_Global_Raw_Data_Staging__c.isAccessible()) {
                rawDataMap = new Map<String, CRM_Global_Raw_Data_Staging__c>([
                    SELECT Id, CRM_Global_RawJSONData__c, CRM_Global_DataIngestionJob__c,
                    CRM_Global_FailureMessage__c, CRM_Global_ProcessingAttempts__c, CRM_Global_ProcessingStatus__c,
                    CRM_Global_DataIngestionJob__r.CRM_Global_Channel__c, CRM_Global_DataIngestionJob__r.CRM_Global_Sub_Type_1__c, 
                    CRM_Global_DataIngestionJob__r.CRM_Global_Call_Type__c
                    FROM CRM_Global_Raw_Data_Staging__c
                    WHERE CRM_Global_DataIngestionJob__c IN :processingJobs AND CRM_Global_ProcessingStatus__c = 'Pending'
                ]);
                for (CRM_Global_Raw_Data_Staging__c rawRecord : rawDataMap.values()) {
                    Map<String, Object> rawMap = (Map<String, Object>) JSON.deserializeUntyped(rawRecord.CRM_Global_RawJSONData__c);
                    if (String.isNotBlank(String.valueOf(rawMap.get('Policy No.')))) {
                        policyNoSet.add(String.valueOf((Object)rawMap.get('Policy No.')));
                    }
                    if (String.isNotBlank((String)rawMap.get('Case Owner'))) {
                        caseOwnerSet.add((String)rawMap.get('Case Owner'));
                    }
                    if (!jobIdToRawData.containsKey(rawRecord.CRM_Global_DataIngestionJob__c)) {
                        jobIdToRawData.put(rawRecord.CRM_Global_DataIngestionJob__c, new List<CRM_Global_Raw_Data_Staging__c>());
                    }
                    jobIdToRawData.get(rawRecord.CRM_Global_DataIngestionJob__c).add(rawRecord);
                }
            } else {
                System.debug(LoggingLevel.ERROR, 'No access to CRM_Global_Raw_Data_Staging__c object.');
            }

            // Prepare Case Owner List
            if (!caseOwnerSet.isEmpty()) {
                for (User caseOwnerUser : [SELECT Id, Name, Email FROM User WHERE Email IN :caseOwnerSet]) {
                    caseOwnerInfoToUser.put(caseOwnerUser.Email, caseOwnerUser);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Scheduler Prepare Ingestion Job And Raw Data failed: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
    }


    /**
     * @method prepareUpsertMasterCase
     * @description Prepare And Upsert Master Case.
     */
    private void prepareUpsertMasterCase() {
        try {
            // Prepare Master case
            for (InsurancePolicy policy : [SELECT Id, Name, NameInsuredId FROM InsurancePolicy WHERE Name IN :policyNoSet]) {
                policyNoToPolicy.put(policy.Name, policy);
                accountIdToMasterCase.put(policy.NameInsuredId, new Case(
                    RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Master_Outbound').getRecordTypeId(),
                    AccountId = policy.NameInsuredId
                ));
            }
            for (Case oldMasterCase : [SELECT Id, AccountId FROM Case 
            WHERE AccountId IN :accountIdToMasterCase.keySet() 
            AND RecordTypeId = :Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Master_Outbound').getRecordTypeId()]) {
                accountIdToMasterCase.get(oldMasterCase.AccountId).Id = oldMasterCase.Id;
            }

            // Upsert Master
            Database.upsert(accountIdToMasterCase.values(), false);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Scheduler Prepare And Upsert Master Case failed: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
    }


    /**
     * @method updateRawDataStatus
     * @description update Raw Data Status.
     * @param resultInserts
     * @param rawDataIdList
     * @param errorMap
     */
    private void updateRawDataStatus(Database.UpsertResult[] resultInserts, List<String> rawDataIdList, Map<String, List<String>> errorMap) {
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
            if (resultInserts != null && !rawDataIdList.isEmpty()) {
                for (Integer i = 0; i < resultInserts.size(); i++) {
                    Id rawId = rawDataIdList.get(i);
                    if (rawId == null) {
                        continue;
                    }
    
                    if (!rawDataMap.containsKey(rawId)) {
                        continue;
                    }

                    CRM_Global_Raw_Data_Staging__c raw = new CRM_Global_Raw_Data_Staging__c(Id = rawId);
                    
                    if (resultInserts[i].isSuccess()) {
                        raw.CRM_Global_ProcessingStatus__c = 'Success';
                        raw.CRM_Global_FailureMessage__c = null;
                    } else {
                        Decimal attempts = rawDataMap.get(rawId).CRM_Global_ProcessingAttempts__c != null ?
                                            rawDataMap.get(rawId).CRM_Global_ProcessingAttempts__c + 1 :
                                            1;

                        raw.CRM_Global_ProcessingStatus__c = attempts >= maxProcessingAttempts ? 'Error' : 'Pending';
                        raw.CRM_Global_FailureMessage__c = resultInserts[i].getErrors()[0].getMessage();
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
            System.debug(LoggingLevel.ERROR, 'Scheduler Update Raw Data Status failed: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
    }
    
    /**
     * @method deduplicateOutboundCase
     * @description Deduplicate Outbound Case.
     * @param outboundCaseList
     * @param rawDataIdList
     * @param errorMap
     */
    private void deduplicateOutboundCase(List<Case> outboundCaseList, List<String> rawDataIdList, Map<String, List<String>> errorMap) {
        try {
            List<Case> outboundCaseListNew = new List<Case>();
            List<String> rawDataIdListNew = new List<String>();
            Set<String> policySet = new Set<String>();

            for (Integer i = 0; i < outboundCaseList.size(); i++) {
                Id rawId = rawDataIdList.get(i);
                Case outbound = outboundCaseList.get(i);
                if (!policySet.contains(outbound.CRM_Global_Policy__c)) {
                    outboundCaseListNew.add(outbound);
                    rawDataIdListNew.add(rawId);
                    policySet.add(outbound.CRM_Global_Policy__c);
                } else {
                    errorMap.put(rawId, new List<String>{'There is already a job with the current policy in the  of the currently executing task'});
                }
            }
            if (outboundCaseList.size() != outboundCaseListNew.size()) {
                outboundCaseList.clear();
                rawDataIdList.clear();
                outboundCaseList.addAll(outboundCaseListNew);
                rawDataIdList.addAll(rawDataIdListNew);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Scheduler Deduplicate Outbound Case: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
    }

    /**
     * @method upsertRelatedCase
     * @description Upsert Related Case.
     * @param outboundCaseList
     * @return Database.UpsertResult[]
     */
    private Database.UpsertResult[] upsertRelatedCase(List<Case> outboundCaseList) {
        Database.UpsertResult[] resultInserts;
        try {
            if (!outboundCaseList.isEmpty()) {
                String enquiryOutboundId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Enquiry_Outbound').getRecordTypeId();

                Map<String, Case> policyNameToCase = new Map<String, Case>();
                for (Case outboundCase : outboundCaseList) {
                    if (outboundCase.RecordTypeId == enquiryOutboundId && outboundCase.Id == null) {
                        policyNameToCase.put(outboundCase.CRM_Global_Policy__c, new Case());
                    }
                }

                if (policyNameToCase.keySet().size() > 0) {
                    for (Case outbound : [SELECT Id, CRM_Global_Policy__c  FROM Case WHERE CRM_Global_Policy__c IN :policyNameToCase.keySet() AND RecordTypeId = :enquiryOutboundId]) {
                        policyNameToCase.put(outbound.CRM_Global_Policy__c, outbound);
                    }
                }

                for (Case outboundCase : outboundCaseList) {
                    if (outboundCase.RecordTypeId == enquiryOutboundId && outboundCase.Id == null && String.isNotBlank(policyNameToCase.get(outboundCase.CRM_Global_Policy__c).Id)) {
                        outboundCase.Id = policyNameToCase.get(outboundCase.CRM_Global_Policy__c).Id;
                    }
                }

                resultInserts = Database.upsert(outboundCaseList, false);
                System.debug(LoggingLevel.INFO, 'Upsert ' + outboundCaseList.size() + ' Outbound Case.');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Scheduler Upsert Related Case: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
        return resultInserts;
    }

    
    /**
     * @method updateJobStatus
     * @description update Job Status.
     * @param allJobIdSet
     */
    private void updateJobStatus(Set<String> allJobIdSet) {
        if (allJobIdSet.size() == 0 && processingJobs.size() == 0) {
            return;
        }

        try {
            Map<String, CRM_Global_Data_Ingestion_Job__c> jobStatusMap = new Map<String, CRM_Global_Data_Ingestion_Job__c>();
            for (CRM_Global_Data_Ingestion_Job__c job : processingJobs) {
                jobStatusMap.put(
                    job.Id,
                    new CRM_Global_Data_Ingestion_Job__c(
                        Id =job.Id,
                        CRM_Global_FailedRecords__c = 0,
                        CRM_Global_SuccessRecords__c = 0,
                        CRM_Global_TotalRecords__c = 0
                    )
                );
            }
            for (CRM_Global_Raw_Data_Staging__c rawDataStaging2 : [SELECT Id, CRM_Global_ProcessingStatus__c, CRM_Global_DataIngestionJob__c FROM CRM_Global_Raw_Data_Staging__c WHERE CRM_Global_DataIngestionJob__c IN :allJobIdSet]) {
                if (rawDataStaging2.CRM_Global_ProcessingStatus__c == 'Success') {
                    jobStatusMap.get(rawDataStaging2.CRM_Global_DataIngestionJob__c).CRM_Global_SuccessRecords__c += 1;
                } else if (rawDataStaging2.CRM_Global_ProcessingStatus__c == 'Error') {
                    jobStatusMap.get(rawDataStaging2.CRM_Global_DataIngestionJob__c).CRM_Global_FailedRecords__c += 1;
                }
                jobStatusMap.get(rawDataStaging2.CRM_Global_DataIngestionJob__c).CRM_Global_TotalRecords__c += 1;
            }
            for (CRM_Global_Data_Ingestion_Job__c job : jobStatusMap.values()) {
                if (job.CRM_Global_TotalRecords__c == 0) {
                    job.CRM_Global_Status__c = 'Failed';
                } else if (job.CRM_Global_FailedRecords__c + job.CRM_Global_SuccessRecords__c < job.CRM_Global_TotalRecords__c) {
                    job.CRM_Global_Status__c = 'Processing';
                } else if (job.CRM_Global_FailedRecords__c > 0 && job.CRM_Global_SuccessRecords__c == 0) {
                    job.CRM_Global_Status__c = 'Failed';
                    job.CRM_Global_EndTime__c = Datetime.now();
                } else if (job.CRM_Global_FailedRecords__c > 0 && job.CRM_Global_SuccessRecords__c > 0) {
                    job.CRM_Global_Status__c = 'Completed With Errors';
                    job.CRM_Global_EndTime__c = Datetime.now();
                } else if (job.CRM_Global_FailedRecords__c == 0 && job.CRM_Global_SuccessRecords__c > 0) {
                    job.CRM_Global_Status__c = 'Completed';
                    job.CRM_Global_EndTime__c = Datetime.now();
                }
            }

            // Update Job status
            Database.update(jobStatusMap.values(), false);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Scheduler Update Job Status failed: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
    }


}