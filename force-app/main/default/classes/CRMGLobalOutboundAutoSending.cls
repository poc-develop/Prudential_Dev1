/**
 * CRMGLobalOutboundAutoSending
 * @author       : Easin
 * @date         : 2025-11-07
 * @description  : Queue for Auto Trigger Sending.
 */
public with sharing class CRMGLobalOutboundAutoSending {
    
    /**
     * @description Run Queue Job To Auto Trigger Sending
     * @param caseIds
     */
    @InvocableMethod(label = 'Run Queue Job To Auto Trigger Sending')
    public static void enqueueForAutoTriggerSending(List<String> caseIds){
        if (caseIds.size() > 0) {
            System.enqueueJob(new CRMGLobalOutboundAutoSendingQueue(caseIds));
        }
    }

}