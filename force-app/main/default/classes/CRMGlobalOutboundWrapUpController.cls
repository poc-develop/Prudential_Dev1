/**
 * CRMGlobalOutboundWrapUpController
 * @author       : Easin Zhou
 * @date         : 2025-10-29
 * @description  : Used for Wrap Up of Outbound Enquiry Case.
 */
public with sharing class CRMGlobalOutboundWrapUpController {

    /**
     * @description Wrap Up Wrappers
     */
    public class WrapUpWrapper {
        @AuraEnabled public String callerIdentity { get; set; }
        @AuraEnabled public String attemptRecordType { get; set; }
        @AuraEnabled public String callAttemptOwner { get; set; }
        @AuraEnabled public String contactNo { get; set; }
        @AuraEnabled public List<WrapUpBodyWrapper> wrapUpBodys { get; set; }

        /**
         * @description constructor
         */
        public WrapUpWrapper() {
            this.callerIdentity = '';
            this.attemptRecordType = '';
            this.callAttemptOwner = '';
            this.contactNo = '';
            this.wrapUpBodys = new List<WrapUpBodyWrapper>();
        }
    }


    /**
     * @description Wrap Up Body Wrappers
     */
    public class WrapUpBodyWrapper {
        @AuraEnabled public String callAttemptResult { get; set; }
        @AuraEnabled public String remark { get; set; }
        @AuraEnabled public Boolean ur { get; set; }
        @AuraEnabled public Boolean suspicious { get; set; }
        @AuraEnabled public Boolean sms { get; set; }
        @AuraEnabled public Boolean email { get; set; }
        @AuraEnabled public Boolean form { get; set; }
        @AuraEnabled public List<String> relatedCaseIds { get; set; }

        /**
         * @description constructor
         */
        public WrapUpBodyWrapper() {
            this.callAttemptResult = '';
            this.remark = '';
            this.ur = false;
            this.suspicious = false;
            this.sms = false;
            this.email = false;
            this.form = false;
            this.relatedCaseIds = new List<String>();
        }
    }


    /**
     * @description Wrap Up results
     */
    public class WrapUpResult {
        @AuraEnabled public Boolean wrapUpSuccess { get; set; }
        @AuraEnabled public String wrapUpErrorMessage { get; set; }
        
        /**
         * @description constructor
         */
        public WrapUpResult() {
            this.wrapUpSuccess = true;
            this.wrapUpErrorMessage = '';
        }
    }


    /**
     * @description page results
     */
    public class PageInitResult {
        @AuraEnabled public Boolean pageSuccess { get; set; }
        @AuraEnabled public String pageErrorMessage { get; set; }
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public String caseOwner { get; set; }
        @AuraEnabled public String callType { get; set; }
        @AuraEnabled public String caseSubType { get; set; }
        @AuraEnabled public String caseRecordType { get; set; }
        @AuraEnabled public String contactNo { get; set; }
        @AuraEnabled public String callAttemptOwner { get; set; }
        @AuraEnabled public List<Case> relatedCaseList { get; set; }
        
        /**
         * @description constructor
         */
        public PageInitResult() {
            this.pageSuccess = true;
            this.pageErrorMessage = '';
            this.caseNumber = '';
            this.caseOwner = '';
            this.callType = '';
            this.caseSubType = '';
            this.caseRecordType = '';
            this.contactNo = '';
            this.callAttemptOwner = '';
            this.relatedCaseList = new List<Case>();
        }
    }


    /**
     * @method pageInit
     * @description The main methods of Page Initial Data
     * @param voiceCallId
     * @return PageInitResult
     */
    @AuraEnabled(cacheable=true)
    public static PageInitResult pageInit(String voiceCallId) {

        PageInitResult pageResult = new PageInitResult();
        try {

            if (!Schema.sObjectType.Case.isAccessible() || !Schema.sObjectType.VoiceCall.isAccessible()) {
                pageResult.pageSuccess = false;
                pageResult.pageErrorMessage = 'No permission to use case or voice call';
                return pageResult;
            }
            List<VoiceCall> voiceCalls = [SELECT Id, RelatedRecordId, UserId FROM VoiceCall WHERE Id = :voiceCallId];
            if (voiceCalls.size() == 0) {
                pageResult.pageSuccess = false;
                pageResult.pageErrorMessage = 'Can not Found the Voice Call';
                return pageResult;
            }

            List<Case> relatedCases = new List<Case>();
            List<Case> cases = [SELECT Id, CaseNumber, ParentId, Owner.Name, CRM_Global_Outbound_Call_Type__c, CRM_Global_Outbound_Sub_Type_1__c,
                                RecordType.Name, CRM_Global_Policy__r.NameInsured.CRM_PHKL_PersonMobilePhoneMask__c
                                FROM Case WHERE Id = :voiceCalls[0].RelatedRecordId];
            if (cases.size() == 0) {
                pageResult.pageSuccess = false;
                pageResult.pageErrorMessage = 'Can not Found the Case';
                return pageResult;
            }
            relatedCases = [SELECT Id, CaseNumber, CRM_Global_Outbound_Call_Type__c, CRM_Global_Policy__r.CRM_Global_ProductCode__c,
                            CRM_Global_Outbound_Sub_Type_1__c, CRM_Global_PolicyNumber__c,CRM_Global_Policy__r.Name
                            FROM Case WHERE ParentId = :cases[0].ParentId AND CRM_Global_IsFinalWrapUp__c = false];

             pageResult.caseNumber = cases[0].caseNumber;
             pageResult.caseOwner = cases[0].Owner.Name;
             pageResult.callType = cases[0].CRM_Global_Outbound_Call_Type__c;
             pageResult.caseSubType = cases[0].CRM_Global_Outbound_Sub_Type_1__c;
             pageResult.caseRecordType = cases[0].RecordType.Name;
             pageResult.contactNo = cases[0].CRM_Global_Policy__r.NameInsured.CRM_PHKL_PersonMobilePhoneMask__c;
             pageResult.callAttemptOwner = voiceCalls[0].UserId;
             pageResult.relatedCaseList = relatedCases;
        } catch (Exception e) {
            pageResult.pageSuccess = false;
            pageResult.pageErrorMessage = 'Error: ' + e.getMessage();
            CRMGlobalLogManager.addApexErrorLog('pageInit: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
        }
        return pageResult;
    }

    /**
     * @method processingWrapUp
     * @description The main methods of Processing
     * @param voiceCallId
     * @param wrapUpData
     * @return WrapUpResult
     */
    @AuraEnabled
    public static WrapUpResult processingWrapUp(String voiceCallId, String wrapUpData) {

        WrapUpResult processingResult = new WrapUpResult();

        WrapUpWrapper wrapUpDataDone = (WrapUpWrapper)JSON.deserialize(wrapUpData, WrapUpWrapper.class);

        // check validation:
        if (wrapUpDataDone.wrapUpBodys == null || wrapUpDataDone.wrapUpBodys.isEmpty()) {
            processingResult.wrapUpSuccess = false;
            processingResult.wrapUpErrorMessage = 'Please Input Wrap Up information';
            return processingResult;
        }

        try {

            // select voice call
            List<VoiceCall> voiceCalls = [SELECT Id, CRM_Global_InteractionDateTime__c, CRM_Global_InteractionLink__c FROM VoiceCall WHERE Id = :voiceCallId];
            if (voiceCalls.size() == 0) {
                processingResult.wrapUpSuccess = false;
                processingResult.wrapUpErrorMessage = 'Can not Found the Voice Call';
                return processingResult;
            }

            // select all related enquiry cases
            List<String> caseIds = new List<String>();
            for (WrapUpBodyWrapper wrapUpOneBody : wrapUpDataDone.wrapUpBodys) {
                caseIds.addAll(wrapUpOneBody.relatedCaseIds);
            }
            caseIds = new List<String>(new Set<String>(caseIds));
            Map<String, Case> caseMaps = new Map<String, Case>([SELECT Id, CRM_Global_TotalCallAttempts__c, CRM_Global_TotalOwnerCallAttempts__c, CRM_Global_Policy__c,
                                                CRM_Global_Suspicious__c, CRM_Global_UR__c, CRM_Global_SMS__c, CRM_Global_Email__c, CRM_Global_Form__c
                                                 FROM Case WHERE Id IN :caseIds]);

            processingWrapUpDataBase(voiceCallId, wrapUpDataDone, voiceCalls, caseMaps);
        } catch (Exception e) {
            processingResult.wrapUpSuccess = false;
            processingResult.wrapUpErrorMessage = 'Error: ' + e.getMessage();
            CRMGlobalLogManager.addApexErrorLog('processingWrapUp: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
        }
        return processingResult;
    }

    /**
     * @method processingWrapUpDataBase
     * @description The main methods of Processing DML
     * @param voiceCallId
     * @param wrapUpDataDone
     * @param voiceCalls
     * @param caseMaps
     */
    private static void processingWrapUpDataBase(String voiceCallId, WrapUpWrapper wrapUpDataDone, List<VoiceCall> voiceCalls, Map<String, Case> caseMaps) {
        try {
            // make the wrap up (case associated item) data
            List<CRM_Global_CaseAssociatedItem__c> wrapUpItems = new List<CRM_Global_CaseAssociatedItem__c>();
            for (WrapUpBodyWrapper wrapUpBodyItem : wrapUpDataDone.wrapUpBodys) {
                for (String caseId : wrapUpBodyItem.relatedCaseIds) {
                    wrapUpItems.add(new CRM_Global_CaseAssociatedItem__c(
                        CRM_Global_Case__c = caseId,
                        CRM_Global_RelatedPolicy__c = caseMaps.containsKey(caseId) ? caseMaps.get(caseId).CRM_Global_Policy__c : null,
                        CRM_Global_VoiceCall__c = voiceCallId,

                        CRM_Global_CallerIdentity__c = wrapUpDataDone.callerIdentity,
                        CRM_Global_AttemptRecordType__c = wrapUpDataDone.attemptRecordType,
                        CRM_Global_CallAttemptOwner__c = wrapUpDataDone.callAttemptOwner,
                        CRM_Global_ContactNo__c = wrapUpDataDone.contactNo,

                        CRM_Global_CallAttemptResult__c = wrapUpBodyItem.callAttemptResult,
                        CRM_Global_CommentRemarks__c = wrapUpBodyItem.remark,
                        CRM_Global_Suspicious__c = wrapUpBodyItem.suspicious,
                        CRM_Global_UR__c = wrapUpBodyItem.ur,

                        CRM_Global_InteractionDateTime__c = voiceCalls[0].CRM_Global_InteractionDateTime__c,
                        CRM_Global_InteractionLink__c = voiceCalls[0].CRM_Global_InteractionLink__c
                    ));
                    if (caseMaps.containsKey(caseId)) {
                        caseMaps.get(caseId).CRM_Global_Suspicious__c = wrapUpBodyItem.suspicious;
                        caseMaps.get(caseId).CRM_Global_UR__c = wrapUpBodyItem.ur;
                        caseMaps.get(caseId).CRM_Global_SMS__c = wrapUpBodyItem.sms;
                        caseMaps.get(caseId).CRM_Global_Email__c = wrapUpBodyItem.email;
                        caseMaps.get(caseId).CRM_Global_Form__c = wrapUpBodyItem.form;

                        if (caseMaps.get(caseId).CRM_Global_TotalOwnerCallAttempts__c == null) {
                            caseMaps.get(caseId).CRM_Global_TotalOwnerCallAttempts__c = 0;
                        }
                        if (caseMaps.get(caseId).CRM_Global_TotalCallAttempts__c == null) {
                            caseMaps.get(caseId).CRM_Global_TotalCallAttempts__c = 0;
                        }

                        if (wrapUpDataDone.callerIdentity == 'Policy Owner') {
                            caseMaps.get(caseId).CRM_Global_TotalOwnerCallAttempts__c += 1;
                        }
                        caseMaps.get(caseId).CRM_Global_TotalCallAttempts__c += 1;
                    }
                }
                
            }

            // insert wrap up list
            if (Schema.sObjectType.CRM_Global_CaseAssociatedItem__c.isCreateable()) {
                Database.insert(wrapUpItems, false);
            }

            // update case (UR&Suspicious and SMS&Email&Form and Attmpt Number)
            Database.update(caseMaps.values(), false);
        } catch (Exception e) {
            CRMGlobalLogManager.addApexErrorLog('processingWrapUpDataBase: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString(), e);
            throw e;
        }
    }
  

}