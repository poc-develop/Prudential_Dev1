/**
 * @description       : Scheduler for Enquiry Data Sync
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-28
 * @last modified by  : hank
**/
public without sharing class CRMGlobalEnquiryScheduler implements Schedulable {
    
    /**
     * Scheduler entry point
     */
    public void execute(SchedulableContext sc) {
        // Start batch job
        CRMGlobalEnquirySyncBatch batch = new CRMGlobalEnquirySyncBatch();
        Database.executeBatch(batch, 200);
    }
}