/**
 * @description       : Batchable class to delete customer related data
 * @author            : Vincent
 * @group             : 
 * @last modified on  : 2025-11-06
 * @last modified by  : Franco
**/
global class CRMGlobalDeleteCustomerRecordBatch implements Database.Batchable<sObject>, Database.Stateful {

    private final String query;
    private Integer failedRecordCount = 0;

    /**
     * Constructor accepts the SOQL query string to identify records for deletion.
     * @param q The SOQL query (e.g., 'SELECT Id FROM Claim WHERE CreatedDate < YESTERDAY')
     */
    public CRMGlobalDeleteCustomerRecordBatch(String q) {
        this.query = q;
    }

    /**
     * Start method: Returns a QueryLocator for the records to be processed.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }

    /**
     * Execute method: Deletes the records passed in the 'scope'.
     * Uses partial success (allowPartialDML = false) to prevent one bad
     * record from failing the whole chunk.
     */
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        Database.DeleteResult[] deleteResults = Database.delete(scope, false);

        // Iterate over results to log any failures
        for (Database.DeleteResult dr : deleteResults) {
            if (!dr.isSuccess()) {
                failedRecordCount++;
                // Log the error for debugging
                Database.Error err = dr.getErrors()[0];
                CRMGlobalLogManager.addApexErrorLog('Failed to delete record. ID: ' + dr.getId() + '. Error: ' + err.getStatusCode() + ': ' + err.getMessage(), null);
                System.debug(LoggingLevel.INFO, 'Failed to delete record. ID: ' + dr.getId() + '. Error: ' + err.getStatusCode() + ': ' + err.getMessage());
            }
        }
    }

    /**
     * Finish method: Called after all batches are processed.
     * Good place for sending a summary email or logging completion.
     */
    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed,
                                   TotalJobItems, CreatedBy.Email
                            FROM AsyncApexJob
                            WHERE Id = :bc.getJobId()];
		CRMGlobalLogManager.addApexInfoLog('Batch Job ' + job.Id + ' finished.');
        if(failedRecordCount > 0) {
            CRMGlobalLogManager.addApexErrorLog('Processed ' + job.TotalJobItems + ' records with ' + failedRecordCount + ' failures.', null);
        }
        System.debug(LoggingLevel.INFO, 'Batch Job ' + job.Id + ' finished.');
        System.debug(LoggingLevel.INFO, 'Processed ' + job.TotalJobItems + ' records with ' + failedRecordCount + ' failures.');
		CRMGlobalLogManager.saveAndFlushLogs();
        // You could add an email notification here if failedRecordCount > 0
        // Example:
        // if (failedRecordCount > 0) {
        //     Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        //     mail.setToAddresses(new String[] { job.CreatedBy.Email });
        //     mail.setSubject('Record Deletion Batch Failed for ' + query);
        //     mail.setPlainTextBody('The batch job ' + job.Id + ' finished with ' + 
        //                           failedRecordCount + ' failed deletions.');
        //     Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        // }
    }    
    
}