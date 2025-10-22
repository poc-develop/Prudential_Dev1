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
     * @description Raw Data String Record Id List.
     */
    public List<String> rawDataIdList;

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
        caseOwnerInfoToUser = new Map<String, User>();

        outboundCaseList = new List<Case>();
        rawDataIdList = new List<String>();

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

        return this;
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
        if (attributeName == 'policyNoToPolicy') {
            policyNoToPolicy = (Map<String, InsurancePolicy>) attributeValue;
        }
        if (attributeName == 'accountIdToMasterCase') {
            accountIdToMasterCase = (Map<String, Case>) attributeValue;
        }
        if (attributeName == 'caseOwnerInfoToUser') {
            caseOwnerInfoToUser = (Map<String, User>) attributeValue;
        }
        return this;
    }

    /**
     * getAttribute
     * @description Get Attribute.
     * @param attributeName
     * @return Object
     */
    public override Object getAttribute(String attributeName){
        if (attributeName == 'outboundCaseList') {
            return (Object)outboundCaseList;
        }
        if (attributeName == 'rawDataIdList') {
            return (Object)rawDataIdList;
        }
        Object myVar;
        return myVar;
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
            System.debug(LoggingLevel.ERROR, 'Error Get TAT Due Date: ' + e.getMessage() + '#line:' + e.getLineNumber());
            throw e;
        }

        return dueDate;
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