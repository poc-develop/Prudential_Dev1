/**
 * CrmGlobalDataIngestionHandlerCase
 * @author       : Easin Zhou
 * @date         : 2025-10-15
 * @description  : Class for Data Ingestion Job Case Handler.
 */
public with sharing class CrmGlobalDataIngestionHandlerCase extends CrmGlobalDataIngestionHandlerAbstract {

    /**
     * @description Policy No Map To policy.
     */
    public Map<String, InsurancePolicy> policyNoToPolicy;

    /**
     * @description Account Id Map To Master Case.
     */
    public Map<String, Case> accountIdToMasterCase;

    /**
     * @description Case Owner Name Map to User.
     */
    public Map<String, User> caseOwnerInfoToUser;

    /**
     * @description Outbound Case List.
     */
    public List<Case> outboundCaseList;

    /**
     * @description All Policy Set.
     */
    public Set<String> allPolicySet;

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

        allPolicySet = new Set<String>();

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
        outboundCaseList = new List<Case>();
        rawDataIdList = new List<String>();

        policyNoToPolicy = new Map<String, InsurancePolicy>();
        accountIdToMasterCase = new Map<String, Case>();
        caseOwnerInfoToUser = new Map<String, User>();

        checkListRaws = new List<String>{'Case Received Date', 'Policy No.', 'Case Owner', 'Priority'};

        // Case Priority picklist
        if (commonData.isEmpty() || !commonData.containsKey('case_priority') || commonData.get('case_priority') == null) {
            List<String> casePriorityPicklistValue = new List<String>();
            for(Schema.PicklistEntry entry : Schema.getGlobalDescribe()
                .get('Case')
                .getDescribe()
                .fields.getMap()
                .get('Priority')
                .getDescribe()
                .getPicklistValues()) {
                    
                casePriorityPicklistValue.add(entry.getValue());
            }
            commonData.put('case_priority', casePriorityPicklistValue);
        }
        
        // TAT due date mdt
        if (commonData.isEmpty() || !commonData.containsKey('TAT_due_date') || commonData.get('TAT_due_date') == null) {
            Map<String, CRM_Global_OutBound_Case_TAT_Setting__mdt> dueDateMap = new Map<String, CRM_Global_OutBound_Case_TAT_Setting__mdt>();
            for(CRM_Global_OutBound_Case_TAT_Setting__mdt mdt : [SELECT Id, CRM_Global_CallType__c, CRM_Global_Channel__c,
                                                        CRM_Global_SubType_1__c, CRM_Global_TAT__c, CRM_Global_TAT_Unit__c
                                                        FROM CRM_Global_OutBound_Case_TAT_Setting__mdt ]) {
                dueDateMap.put(
                    (String.isNotBlank(mdt.CRM_Global_CallType__c) ? mdt.CRM_Global_CallType__c : '#') + '_' +
                    (String.isNotBlank(mdt.CRM_Global_Channel__c) ? mdt.CRM_Global_Channel__c : '#') + '_' +
                    (String.isNotBlank(mdt.CRM_Global_SubType_1__c) ? mdt.CRM_Global_SubType_1__c : '#'), 
                    mdt
                );
            }
            commonData.put('TAT_due_date', dueDateMap);
        }

        prepareRawDataAndUpsertMasterCase();

        return this;
    }


    /**
     * @method processTargetResult
     * @description Process Target Result.
     * @return Database.UpsertResult[]
     */
    protected override Database.UpsertResult[] processTargetResult() {
        // Deduplicate
        deduplicateOutboundCase();

        // Upsert Child Outbound Case
        Database.UpsertResult[] resultUpserts = new List<Database.UpsertResult>();
        if (!outboundCaseList.isEmpty() && !rawDataIdList.isEmpty()) {
            resultUpserts = upsertRelatedCase();
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
                String policyNo = rawMap.containsKey('Policy No.') ? String.valueof(rawMap.get('Policy No.')) : '';
                String caseOwnerInfo = rawMap.containsKey('Case Owner') ? (String)rawMap.get('Case Owner') : '';
                String subType2 = rawMap.containsKey('Sub Type 2') ? (String)rawMap.get('Sub Type 2') : '';

                if (errorMap.containsKey(raw.Id)) {
                    continue;
                }

                if (!policyNoToPolicy.containsKey(policyNo) || !accountIdToMasterCase.containsKey(policyNoToPolicy.get(policyNo).NameInsuredId)) {
                    continue;
                }
                
                Case outboundCase = new Case();
                outboundCase.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Enquiry_Outbound').getRecordTypeId();
                outboundCase.Priority = (String)rawMap.get('Priority');
                outboundCase.CRM_Global_CaseReceivedDate__c = getDateFromString((String)rawMap.get('Case Received Date'));
                outboundCase.CRM_Global_Policy__c = policyNoToPolicy.containsKey(policyNo) ? policyNoToPolicy.get(policyNo).Id : '';
                outboundCase.OwnerId = caseOwnerInfoToUser.containsKey(caseOwnerInfo) ? caseOwnerInfoToUser.get(caseOwnerInfo).Id : '';
                outboundCase.AccountId = policyNoToPolicy.get(policyNo).NameInsuredId;
                outboundCase.ParentId = accountIdToMasterCase.get(outboundCase.AccountId).Id;
                outboundCase.Status = 'Active';
                outboundCase.CRM_Global_PolicyNumber__c = policyNo;
                
                outboundCase.CRM_Global_Outbound_Call_Type__c = raw.CRM_Global_DataIngestionJob__r.CRM_Global_Call_Type__c;
                outboundCase.CRM_Global_Outbound_Channel__c = raw.CRM_Global_DataIngestionJob__r.CRM_Global_Channel__c;
                outboundCase.CRM_Global_Outbound_Sub_Type_1__c = raw.CRM_Global_DataIngestionJob__r.CRM_Global_Sub_Type_1__c;
                outboundCase.CRM_Global_Outbound_Sub_Type_2__c = subType2;
                outboundCase.CRM_Global_Outbound_TAT_StartDate__c = Date.today();

                Date dueDate = getTATDueData(
                    outboundCase.CRM_Global_Outbound_Channel__c,
                    outboundCase.CRM_Global_Outbound_Call_Type__c,
                    outboundCase.CRM_Global_Outbound_Sub_Type_1__c
                );
                if (dueDate != null) {
                    outboundCase.CRM_Global_Outbound_TAT_DueDate__c = dueDate;
                }

                outboundCaseList.add(outboundCase);
                rawDataIdList.add(raw.Id);
            }

        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('Error Handle Raw Data And Prepare Outbound Case records: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Error Handle Raw Data And Prepare Outbound Case records: ' + e.getMessage() + '#line:' + e.getLineNumber());
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

            if (rawKey == 'Case Received Date') {
                Date receivedDate = getDateFromString(rawDataItem);
                if (receivedDate == null) {
                    return 'Case Received Date [' + rawDataItem + '] not in date format';
                }
            }
            if (rawKey == 'Policy No.') {
                if (!policyNoToPolicy.containsKey(rawDataItem)) {
                    return 'Policy No. [' + rawDataItem + '] unable to find the correct Policy';
                }
            }
            if (rawKey == 'Case Owner') {
                if (!caseOwnerInfoToUser.containsKey(rawDataItem)) {
                    return 'Case Owner [' + rawDataItem +  '] unable to find the correct User';
                }
            }
            if (rawKey == 'Priority') {
                if (!((List<String>)commonData.get('case_priority')).contains(rawDataItem)) {
                    return 'Priority [' + rawDataItem +  '] is not a correct value';
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
     * getAttribute
     * @description Get Attribute.
     * @param attributeName
     * @return Object
     */
    public Date getTATDueData(String channel, String callType, String subType) {
        Date dueDate;

        try {
            Object dueDateObject = commonData.get('TAT_due_date');
            if (dueDateObject == null) {
                return dueDate;
            }
            Map<String, CRM_Global_OutBound_Case_TAT_Setting__mdt> dueDateMap = (Map<String, CRM_Global_OutBound_Case_TAT_Setting__mdt>)dueDateObject;
            
            String mdtKey = (String.isNotBlank(callType) ? callType : '#') + '_' +
            (String.isNotBlank(channel) ? channel : '#') + '_' +
            (String.isNotBlank(subType) ? subType : '#');
            if (!dueDateMap.containsKey(mdtKey)) {
                return dueDate;
            }
            CRM_Global_OutBound_Case_TAT_Setting__mdt dueDateMdt = dueDateMap.get(mdtKey);

            // 【 todo 】 - check -- todo(test)
            // system.debug(LoggingLevel.Info, 'dueDateMdt.CRM_Global_TAT__c: ' + dueDateMdt.CRM_Global_TAT__c);
            // system.debug(LoggingLevel.Info, 'dueDateMdt.CRM_Global_TAT_Unit__c: ' + dueDateMdt.CRM_Global_TAT_Unit__c);

            //______________[ call function from franco ]_______________________________________________________________________
            //______channel, channel, subType, dueDateMdt.CRM_Global_TAT__c, dueDateMdt.CRM_Global_TAT_Unit__c__________________
            //__________________________________________________________________________________________________________________

        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('Error Get TAT Due Date: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Error Get TAT Due Date: ' + e.getMessage() + '#line:' + e.getLineNumber());
            throw e;
        }

        return dueDate;
    }

    /**
     * @method deduplicateOutboundCase
     * @description Deduplicate Outbound Case.
     * @param errorMap
     */
    private void deduplicateOutboundCase() {
        try {
            List<Case> outboundCaseListNew = new List<Case>();
            List<String> rawDataIdListNew = new List<String>();
            if (outboundCaseList.isEmpty() || rawDataIdList.isEmpty()) {
                return;
            }

            for (Integer i = 0; i < outboundCaseList.size(); i++) {
                Id rawId = rawDataIdList.get(i);
                Case outbound = outboundCaseList.get(i);
                if (!allPolicySet.contains(outbound.CRM_Global_Policy__c)) {
                    outboundCaseListNew.add(outbound);
                    rawDataIdListNew.add(rawId);
                    allPolicySet.add(outbound.CRM_Global_Policy__c);
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
            CRMGlobalLogManager.addApexErrorLog('Scheduler Deduplicate Outbound Case: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Scheduler Deduplicate Outbound Case: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
    }

    /**
     * @method prepareRawDataAndUpsertMasterCase
     * @description Prepare Raw Data And Upsert Master Case.
     */
    private void prepareRawDataAndUpsertMasterCase() {
        try {
            Set<String> policyNoSet = new Set<String>();
            Set<String> caseOwnerSet = new Set<String>();
            
            for (CRM_Global_Raw_Data_Staging__c rawRecord : rawDataList) {
                Map<String, Object> rawMap = (Map<String, Object>) JSON.deserializeUntyped(rawRecord.CRM_Global_RawJSONData__c);
                if (String.isNotBlank(String.valueOf(rawMap.get('Policy No.')))) {
                    policyNoSet.add(String.valueOf((Object)rawMap.get('Policy No.')));
                }
                if (String.isNotBlank((String)rawMap.get('Case Owner'))) {
                    caseOwnerSet.add((String)rawMap.get('Case Owner'));
                }
            }
    
            // Prepare Case Owner List
            if (!caseOwnerSet.isEmpty()) {
                for (User caseOwnerUser : [SELECT Id, Name, Email FROM User WHERE Email IN :caseOwnerSet]) {
                    caseOwnerInfoToUser.put(caseOwnerUser.Email, caseOwnerUser);
                }
            }
    
            // Prepare Master case
            if (!policyNoSet.isEmpty()) {
                for (InsurancePolicy policy : [SELECT Id, Name, NameInsuredId FROM InsurancePolicy WHERE Name IN :policyNoSet]) {
                    policyNoToPolicy.put(policy.Name, policy);
                    accountIdToMasterCase.put(policy.NameInsuredId, new Case(
                        RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Master_Outbound').getRecordTypeId(),
                        AccountId = policy.NameInsuredId
                    ));
                }
            }
            for (Case oldMasterCase : [SELECT Id, AccountId FROM Case 
                                        WHERE AccountId IN :accountIdToMasterCase.keySet() 
                                        AND RecordTypeId = :Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Master_Outbound').getRecordTypeId()]) {
                accountIdToMasterCase.get(oldMasterCase.AccountId).Id = oldMasterCase.Id;
            }
    
            // Upsert Master
            Database.upsert(accountIdToMasterCase.values(), false);
        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('Scheduler Prepare And Upsert Master Case failed: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Scheduler Prepare And Upsert Master Case failed: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
    }


    /**
     * @method upsertRelatedCase
     * @description Upsert Related Case.
     * @return Database.UpsertResult[]
     */
    private Database.UpsertResult[] upsertRelatedCase() {
        Database.UpsertResult[] resultUpserts = new List<Database.UpsertResult>();
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

                resultUpserts = Database.upsert(outboundCaseList, false);
                System.debug(LoggingLevel.INFO, 'Upsert ' + outboundCaseList.size() + ' Outbound Case.');
            }
        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('Scheduler Upsert Related Case: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            System.debug(LoggingLevel.ERROR, 'Scheduler Upsert Related Case: ' + e.getMessage() + '#line:' + e.getLineNumber());
        }
        return resultUpserts;
    }


    /**
     * getDateFromString
     * @description Get Date From String.
     * @param dateString
     * @return date
     */
    private Date getDateFromString(String dateString) {
        Date dateFromString;
        try {
            dateFromString = Date.valueOf(dateString);
            return dateFromString;
        } catch (Exception e) {
            System.debug(LoggingLevel.INFO, 'Error Get Date From String: ' + dateString);
        }
        return dateFromString;
    }
}