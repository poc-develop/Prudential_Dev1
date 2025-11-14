/**
 * @description       : Delete Customer Record Scheduler
 * @author            : Vincent
 * @group             : 
 * @last modified on  : 2025-11-08
 * @last modified by  : Franco
**/
global class CRMPHKLDeleteCustomerRecordScheduler implements Schedulable {
    /**
     * Schedulable class to run the data deletion jobs.
     * This class loops through a predefined list of SObjects and
     * executes a DeleteRecordsBatch job for each one.
     */
     // Schedulable execute method.
    
    public void execute(SchedulableContext sc) {
        // List of all SObjects to clean
		List<String> objectsToClean;

        if (Test.isRunningTest()) {
            // FOR TESTING: Use standard, safe-to-create objects
            objectsToClean = new List<String>{'Account', 'Contact'};
        } else {
            // FOR PRODUCTION: The real list of objects to clean
            objectsToClean = new List<String>{
                'InsurancePolicyCoverage',
                // 'InsurancePolicyCvrBenefit__c',
                'Producer',
                'CRM_Global_InsPolicyAddress__c',
                'ContactPointAddress',
                'FinServ__PolicyPaymentMethod__c',
                'FinServ__FinancialAccount__c',
                'Claim',
                // 'ClaimComment__c',
                // 'ClaimItem',
                'InsurancePolicyTransaction',
                'FinServ__FinancialAccountTransaction__c'
                // 'ClaimCoverage'
            };
        }

        // Define the cutoff date: CreatedDate < TODAY() - 1
        // This means any record created *before* yesterday.
        // E.g., If today is Nov 4th, this date is Nov 3rd.
        // The query will be < '2025-11-03T00:00:00Z'
        Date deleteBeforeDate = Date.today().addDays(-1);

        for (String objName : objectsToClean) {
            try {
                // Construct the query for this object
                String query = 'SELECT Id FROM ' + objName + ' WHERE CreatedDate < N_DAYS_AGO:1';

                // Create and execute a new batch job for this query
                CRMGlobalDeleteCustomerRecordBatch batchJob = new CRMGlobalDeleteCustomerRecordBatch(query);
                ID batchJobId = Database.executeBatch(batchJob);
                CRMGlobalLogManager.addApexInfoLog('Enqueued CRMGlobalDeleteCustomerRecordBatch for object: ' + objName + ', batchJobId: ' + batchJobId);
                System.debug(LoggingLevel.INFO, 'Enqueued CRMGlobalDeleteCustomerRecordBatch for object: ' + objName);

            } catch (Exception e) {
                // Catch any errors (e.g., object doesn't exist, query is invalid)
                CRMGlobalLogManager.addApexErrorLog('Error enqueuing batch for ' + objName + ': ' + e.getMessage(), e);
                System.debug(LoggingLevel.INFO, 'Error enqueuing batch for ' + objName + ': ' + e.getMessage());
            } finally {
                CRMGlobalLogManager.saveAndFlushLogs();
            }
        }
    }
}