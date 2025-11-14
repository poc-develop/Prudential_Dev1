/**
 * CRMGlobalOutboundFinalWrapUpController
 * @author       : Easin Zhou
 * @date         : 2025-11-05
 * @description  : Used for Final Wrap Up of Outbound Enquiry Case.
 */
public with sharing class CRMGlobalOutboundFinalWrapUpController {

    /**
     * @description Wrap Up Body Wrappers
     */
    public class WrapUpBodyWrapper {
        @AuraEnabled public String finalResult { get; set; }
        @AuraEnabled public String remark { get; set; }
        @AuraEnabled public Boolean ur { get; set; }
        @AuraEnabled public Boolean suspicious { get; set; }
        @AuraEnabled public List<String> relatedCaseIds { get; set; }

        /**
         * @description constructor
         */
        public WrapUpBodyWrapper() {
            this.finalResult = '';
            this.remark = '';
            this.ur = false;
            this.suspicious = false;
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
        @AuraEnabled public String caseSubType { get; set; }
        @AuraEnabled public String policyNumber { get; set; }
        @AuraEnabled public List<Case> relatedCaseList { get; set; }
        
        /**
         * @description constructor
         */
        public PageInitResult() {
            this.pageSuccess = true;
            this.pageErrorMessage = '';
            this.caseNumber = '';
            this.caseSubType = '';
            this.policyNumber = '';
            this.relatedCaseList = new List<Case>();
        }
    }


    /**
     * @method pageInit
     * @description The main methods of Page Initial Data
     * @param caseId
     * @return PageInitResult
     */
    @AuraEnabled(cacheable=true)
    public static PageInitResult pageInit(String caseId) {

        PageInitResult pageResult = new PageInitResult();
        try {

            List<Case> relatedCases = new List<Case>();
            if (!Schema.sObjectType.Case.isAccessible()) {
                pageResult.pageSuccess = false;
                pageResult.pageErrorMessage = 'No permission to use case';
                return pageResult;
            }
            List<Case> cases = [SELECT Id, CaseNumber, ParentId, CRM_Global_Outbound_Sub_Type_1__c, CRM_Global_PolicyNumber__c
                                FROM Case WHERE Id = :caseId];
            if (cases.size() == 0) {
                pageResult.pageSuccess = false;
                pageResult.pageErrorMessage = 'Can not Found the Case';
                return pageResult;
            }
            relatedCases = [SELECT Id, CaseNumber, CRM_Global_Outbound_Call_Type__c, 
                            CRM_Global_Policy__r.CRM_Global_ProductCode__c,
                            CRM_Global_Outbound_Sub_Type_1__c, CRM_Global_PolicyNumber__c,
                            CRM_Global_Policy__r.Name
                            FROM Case 
                            WHERE ParentId = :cases[0].ParentId AND CRM_Global_IsFinalWrapUp__c = false];
            if (relatedCases.size() == 0) {
                pageResult.pageSuccess = false;
                pageResult.pageErrorMessage = 'Can not find cases that requires final wrap up';
                return pageResult;
            }

             pageResult.caseNumber = cases[0].caseNumber;
             pageResult.caseSubType = cases[0].CRM_Global_Outbound_Sub_Type_1__c;
             pageResult.policyNumber = cases[0].CRM_Global_PolicyNumber__c;
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
     * @param wrapUpData
     * @return WrapUpResult
     */
    @AuraEnabled
    public static WrapUpResult processingWrapUp(String wrapUpData) {

        WrapUpResult processingResult = new WrapUpResult();

        List<WrapUpBodyWrapper> wrapUpDataDone = (List<WrapUpBodyWrapper>)JSON.deserialize(wrapUpData, List<WrapUpBodyWrapper>.class);

        // check validation:
        if (wrapUpDataDone == null || wrapUpDataDone.isEmpty()) {
            processingResult.wrapUpSuccess = false;
            processingResult.wrapUpErrorMessage = 'Please Input Final Wrap Up information';
            return processingResult;
        }

        try {
            // select all related enquiry cases
            List<String> caseIds = new List<String>();
            for (WrapUpBodyWrapper wrapUpOneBody : wrapUpDataDone) {
                caseIds.addAll(wrapUpOneBody.relatedCaseIds);
            }
            List<String> caseIdsDedup = new List<String>(new Set<String>(caseIds));
            if (caseIdsDedup.size() < caseIds.size()) {
                processingResult.wrapUpSuccess = false;
                processingResult.wrapUpErrorMessage = 'Cannot repeatedly select the same case for wrap up';
                return processingResult;
            }

            Map<String, Case> caseMaps = new Map<String, Case>([SELECT Id, CRM_Global_Policy__c, 
                                                CRM_Global_Suspicious__c, CRM_Global_UR__c, 
                                                CRM_Global_Outbound_Channel__c, CRM_Global_Outbound_Call_Type__c,
                                                CRM_Global_Outbound_Sub_Type_1__c, 
                                                CRM_Global_IsFinalWrapUp__c, CRM_Global_FinalResult__c
                                                FROM Case 
                                                WHERE Id IN :caseIdsDedup AND CRM_Global_IsFinalWrapUp__c = false]);
            if (caseMaps.keySet().size() < caseIdsDedup.size()) {
                processingResult.wrapUpSuccess = false;
                processingResult.wrapUpErrorMessage = 'Selected a abnormal case or cases that has already been wrapped up, Please Refresh web page';
                return processingResult;
            }

            processingWrapUpDataBase(wrapUpDataDone, caseMaps);
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
     * @param wrapUpDataDone
     * @param caseMaps
     */
    private static void processingWrapUpDataBase(List<WrapUpBodyWrapper> wrapUpDataDone, Map<String, Case> caseMaps) {
        try {
            // make the wrap up (case associated item) data
            List<CRM_Global_CaseAssociatedItem__c> wrapUpItems = new List<CRM_Global_CaseAssociatedItem__c>();
            Map<String, CRM_Global_OutBoundAutoTriggerSending__mdt> autoTriggerMap = getAutoTriggerMap();
            for (WrapUpBodyWrapper wrapUpBodyItem : wrapUpDataDone) {
                for (String caseId : wrapUpBodyItem.relatedCaseIds) {
                    wrapUpItems.add(new CRM_Global_CaseAssociatedItem__c(
                        CRM_Global_Case__c = caseId,
                        CRM_Global_RelatedPolicy__c = caseMaps.containsKey(caseId) ? caseMaps.get(caseId).CRM_Global_Policy__c : null,
                        CRM_Global_CommentRemarks__c = wrapUpBodyItem.remark,
                        CRM_Global_Suspicious__c = wrapUpBodyItem.suspicious,
                        CRM_Global_UR__c = wrapUpBodyItem.ur
                    ));
                    if (caseMaps.containsKey(caseId)) {
                        caseMaps.get(caseId).CRM_Global_Suspicious__c = wrapUpBodyItem.suspicious;
                        caseMaps.get(caseId).CRM_Global_UR__c = wrapUpBodyItem.ur;
                        caseMaps.get(caseId).CRM_Global_FinalResult__c = wrapUpBodyItem.finalResult;
                        caseMaps.get(caseId).CRM_Global_IsFinalWrapUp__c = true;

                        // for sms and letter
                        makeAutoTriggerForCase(caseMaps.get(caseId), autoTriggerMap);
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


    /*
     * @method getAutoTriggerMap
     * @description get the condition of Auto Trigger SMS/Letter.
     * @return Map<String, CRM_Global_OutBoundAutoTriggerSending__mdt>
     */
    private static Map<String, CRM_Global_OutBoundAutoTriggerSending__mdt> getAutoTriggerMap() {
        Map<String, CRM_Global_OutBoundAutoTriggerSending__mdt> autoTriggerMap = new Map<String, CRM_Global_OutBoundAutoTriggerSending__mdt>();
        if (!Schema.sObjectType.CRM_Global_OutBoundAutoTriggerSending__mdt.isAccessible()) {
            return autoTriggerMap;
        }
        for (CRM_Global_OutBoundAutoTriggerSending__mdt autoTrigger : [SELECT Id, CRM_Global_Channel__c, CRM_Global_CallType__c,
                                                                    CRM_Global_SubType_1__c, CRM_Global_FinalResult__c, CRM_Global_Letter__c,
                                                                    CRM_Global_SMS__c, DeveloperName
                                                                    FROM CRM_Global_OutBoundAutoTriggerSending__mdt]) {

            autoTriggerMap.put(
                autoTrigger.CRM_Global_Channel__c + '#'
                    + autoTrigger.CRM_Global_CallType__c + '#'
                    + autoTrigger.CRM_Global_SubType_1__c + '#'
                    + autoTrigger.CRM_Global_FinalResult__c,
                autoTrigger
            );
        }
        return autoTriggerMap;
    }


    /*
     * @method makeAutoTriggerForCase
     * @description make Auto Trigger Flag For Case.
     * @param caseChecking
     * @param autoTriggerMap
     */
    private static void makeAutoTriggerForCase(Case caseChecking, Map<String, CRM_Global_OutBoundAutoTriggerSending__mdt> autoTriggerMap) {
        String autoTriggerKey = caseChecking.CRM_Global_Outbound_Channel__c + '#'
                            + caseChecking.CRM_Global_Outbound_Call_Type__c + '#'
                            + caseChecking.CRM_Global_Outbound_Sub_Type_1__c + '#'
                            + caseChecking.CRM_Global_FinalResult__c;
        if (autoTriggerMap.containsKey(autoTriggerKey)) {
            if (autoTriggerMap.get(autoTriggerKey).CRM_Global_SMS__c) {
                caseChecking.CRM_Global_PendingSMS__c = true;
            }
            if (autoTriggerMap.get(autoTriggerKey).CRM_Global_Letter__c) {
                caseChecking.CRM_Global_PendingLetter__c = true;
            }
        }

    }
  

}