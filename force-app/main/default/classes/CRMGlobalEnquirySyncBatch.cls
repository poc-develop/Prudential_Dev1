/**
 * @description       : Batch job to sync Enquiry data from external API
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-28
 * @last modified by  : hank
**/
public without sharing class CRMGlobalEnquirySyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
    // Statistics
    public Integer processedCount = 0;
    public Integer successCount = 0;
    public Integer failureCount = 0;
    public List<String> errorMessages = new List<String>();
    public static List<RecordType> caseRecordTypes = [SELECT Id,DeveloperName FROM RecordType WHERE SObjectType = 'Case' AND isActive = true];
    
    // Configuration key for storing last sync time
    private static final String LAST_SYNC_TIME_KEY = 'CRMGlobalEnquiryLastSyncTime';
    
    // Store current sync time (to be saved in finish method)
    private DateTime currentSyncTime;
    
    /**
     * Start: Returns a minimal query (we don't need to query records, just trigger API call)
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM User WHERE Id = \'' + UserInfo.getUserId() + '\' LIMIT 1';
        Database.QueryLocator ql = Database.getQueryLocator(query);
        return ql;
    }
    
    /**
     * Execute: Call API and process returned data
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        try {
            System.debug(LoggingLevel.INFO, '=== Execute Started ===');
            System.debug(LoggingLevel.INFO, 'Batch Job Id: ' + bc.getJobId());
            System.debug(LoggingLevel.INFO, 'Scope size: ' + scope.size());
            
            // Store current sync time for saving in finish method
            currentSyncTime = DateTime.now();
            
            // 1. Call API to get data using service class
            CRMGlobalEnquirySyncService.CRMGlobalEnquiryAPIResponse apiResponse = CRMGlobalEnquirySyncService.callEnquiryAPI(null);
            
            // 2. Process returned data using service class
            if (apiResponse != null && apiResponse.results != null && !apiResponse.results.isEmpty()) {
                CRMGlobalEnquirySyncService.CRMGlobalEnquiryProcessResult processResult = CRMGlobalEnquirySyncService.processEnquiryData(apiResponse.results);
                
                // Update statistics
                processedCount += processResult.processedCount;
                successCount += processResult.successCount;
                failureCount += processResult.failureCount;
                if (processResult.errorMessages != null && !processResult.errorMessages.isEmpty()) {
                    errorMessages.addAll(processResult.errorMessages);
                }
            }
            
        } catch (Exception e) {
            failureCount++;
            String errorMsg = 'Batch execute error: ' + e.getMessage();
            errorMessages.add(errorMsg);
            System.debug(LoggingLevel.ERROR, errorMsg + '\n' + e.getStackTraceString());
            CRMGlobalLogManager.addApexErrorLog(errorMsg, e);
        }
    }
    
    /**
     * Finish: Post-processing and logging
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, '=== Batch Finish Method Called ===');
        System.debug(LoggingLevel.INFO, 'Batch Job Id: ' + bc.getJobId());
        
        String summary = '=== Enquiry Sync Batch Summary ===\n';
        summary += 'Processed: ' + processedCount + ' records\n';
        summary += 'Success: ' + successCount + ' records\n';
        summary += 'Failed: ' + failureCount + ' records\n';
        
        if (!errorMessages.isEmpty()) {
            summary += '\nErrors:\n';
            summary += String.join(errorMessages, '\n');
            CRMGlobalLogManager.addApexWarnLog(summary);
        } else {
            CRMGlobalLogManager.addApexInfoLog(summary);
        }
        
        // Save current sync time only if batch was successful (no errors or errors are acceptable)
        // if (currentSyncTime != null) {
            // CRMGlobalEnquirySyncService.saveLastSyncTime(currentSyncTime);
            // System.debug(LoggingLevel.INFO, 'Last sync time saved: ' + CRMGlobalEnquirySyncService.formatDateTimeForAPI(currentSyncTime));
        // }
        
        CRMGlobalLogManager.saveAndFlushLogs();
        
        System.debug(summary);
    }
}
