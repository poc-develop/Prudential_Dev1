/**
 * CRMGLobalOutboundAutoSendingQueue
 * @author       : Easin
 * @date         : 2025-11-07
 * @description  : Queue for Outbound Auto Sending.
 */
public class CRMGLobalOutboundAutoSendingQueue implements Queueable, Database.AllowsCallouts {
    /**
     * @description case Ids.
     */
    private List<String> caseIds;

    /**
     * @description remain Case Ids.
     */
    private List<String> remainCaseIds;

    /**
     * @description current Case Ids.
     */
    private List<String> currentCaseIds;

    /**
     * @description interaction History Logs.
     */
    private List<Task> interactionHistoryLogs;

    /**
     * @description batch Size.
     */
    private Integer batchSize = 8;

    /**
     * @description max Attempt.
     */
    private Integer maxAttempt = 3;

    /**
     * @description constructor
     * @param caseIds
     */
    public CRMGLobalOutboundAutoSendingQueue(List<String> caseIds) {
        this.caseIds = new List<String>(new Set<String>(caseIds));
        this.currentCaseIds = new List<String>();
        this.remainCaseIds = new List<String>();
        this.interactionHistoryLogs = new List<Task>();
    }

    /**
     * @description constructor
     * @param caseIds
     * @param batchSize
     */
    public CRMGLobalOutboundAutoSendingQueue(List<String> caseIds, Integer batchSize) {
        this.caseIds = new List<String>(new Set<String>(caseIds));
        this.currentCaseIds = new List<String>();
        this.remainCaseIds = new List<String>();
        this.interactionHistoryLogs = new List<Task>();

        this.batchSize = batchSize;
    }

    /**
     * @description execute
     * @param context
     */
    public void execute(QueueableContext context) {
        if (caseIds.isEmpty()) {
            return;
        }

        if (caseIds.size() > batchSize) {
            for (Integer i = 0; i < caseIds.size(); i++) {
                if (i < batchSize) {
                    currentCaseIds.add(caseIds[i]);
                } else {
                    remainCaseIds.add(caseIds[i]);
                }
            }
        } else {
            currentCaseIds = caseIds; 
        }


        // Select case list to handle
        Map<String, Case> currentCaseMap = new Map<String, Case>([
            SELECT Id, CRM_Global_PendingLetter__c, CRM_Global_PendingSMS__c, CaseNumber, Account.PersonContactId,
            CRM_Global_AttemptSMS__c, CRM_Global_AttemptLetter__c, Account.PersonMobilePhone
            FROM Case WHERE Id IN :currentCaseIds
        ]);

        // Batch prepare Data
        List<Case> pendingSmsList = new List<Case>();
        List<Case> pendingLetterList = new List<Case>();

        for (Case c : currentCaseMap.values()) {
            if (c.CRM_Global_PendingSMS__c && (c.CRM_Global_AttemptSMS__c == null || c.CRM_Global_AttemptSMS__c <= maxAttempt)) {
                pendingSmsList.add(c);
            }
            if (c.CRM_Global_PendingLetter__c && (c.CRM_Global_AttemptLetter__c == null || c.CRM_Global_AttemptLetter__c <= maxAttempt)) {
                pendingLetterList.add(c);
            }
        }

        // Callout to send SMS or Letter
        if (!pendingSmsList.isEmpty()) {
            sendSmsBatch(pendingSmsList, currentCaseMap);
        }
        if (!pendingLetterList.isEmpty()) {
            sendLetterBatch(pendingLetterList, currentCaseMap);
        }

        // Update Case
        if (currentCaseMap.values().size() > 0) {
            Database.update(currentCaseMap.values(), false);
        }
        // Insert Intraction History Log (Task)
        if (interactionHistoryLogs.size() > 0) {
            Database.insert(interactionHistoryLogs, false);
        }

        // Next handle Queueable
        if (remainCaseIds != null && remainCaseIds.size() > 0) {
            System.enqueueJob(new CRMGLobalOutboundAutoSendingQueue(remainCaseIds, batchSize));
        }
    }


    /**
     * @description send Sms Batch
     * @param context
     * @param currentCaseMap
     */
    private void sendSmsBatch(List<Case> pendingSmsList, Map<String, Case> currentCaseMap) {

        String templateContent = '';

        for (Case pendingSmsCase : pendingSmsList) {
            // todo...Send SMS
            // todo...Send SMS
            System.debug(LoggingLevel.INFO, 'sendSmsBatch: ' + pendingSmsCase.CaseNumber);

            String recipientNumber = currentCaseMap.get(pendingSmsCase.Id).Account.PersonMobilePhone;
            if (String.isNotBlank(recipientNumber) && String.isNotBlank(templateContent)) {
                CRMGlobalSendSmsService.sendSms(recipientNumber, templateContent, '');
            }

            // Update Pending Flag
            currentCaseMap.get(pendingSmsCase.Id).CRM_Global_PendingSMS__c = false;

        }
        

    }


    /**
     * @description send Sms Batch
     * @param context
     * @param currentCaseMap
     */
    private void sendLetterBatch(List<Case> pendingLetterList, Map<String, Case> currentCaseMap) {

        for (Case pendingLetterCase : pendingLetterList) {
            // todo...Send Letter
            // todo...Send Letter
            System.debug(LoggingLevel.INFO, 'sendLetterBatch: ' + pendingLetterCase.CaseNumber);

            // Update Pending Flag
            currentCaseMap.get(pendingLetterCase.Id).CRM_Global_PendingLetter__c = false;

            // make Interaction Log
            interactionHistoryLogs.add(new Task(
                RecordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_LetterHistory').getRecordTypeId(),
                Status = 'Completed',
                Subject = 'Send Letter',
                WhoId = pendingLetterCase.Account.PersonContactId,
                ActivityDate = System.today(),
                WhatId = pendingLetterCase.Id
            ));

        }

    }

}