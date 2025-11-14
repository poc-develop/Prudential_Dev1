/**
 * @author Hassan
 * @date 2025/7/23
 * @description delete old logs daily
 * @param days ：days to retain logs
 * @param filterTime ：start time to delete logs, is calculated by the @param days
 * @param objectAPI ：CRM_Global_ApexLog__c/CRM_Global_Webservice_Call_Log__c
 * System.schedule('CRMGlobalDeleteOldLogsBatch', '0 30 0 * * ?', new CRMGlobalDeleteOldLogsBatch());
 */
public without sharing class CRMGlobalDeleteOldLogsBatch implements Schedulable, Database.Batchable<SObject>{
    private final String query;

    public CRMGlobalDeleteOldLogsBatch(String query) {
        this.query = query;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, list<sObject> scope) {
        Database.delete(scope, false, AccessLevel.SYSTEM_MODE);
    }

    public void finish(Database.BatchableContext BC) {
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed,
                                   TotalJobItems, CreatedBy.Email
                            FROM AsyncApexJob
                            WHERE Id = :bc.getJobId()];
        CRMGlobalLogManager.addApexInfoLog('Batch Job ' + job.Id + ' finished.');
    }

    public void execute(SchedulableContext sc) {
        for(CRM_Global_Housekeeping_Config__mdt housekeeping : [SELECT Object_API_Name__c, Duration_Days__c FROM CRM_Global_Housekeeping_Config__mdt]) {
            Integer days = housekeeping.Duration_Days__c.intValue();
            String query = 'SELECT Id FROM ' + housekeeping.Object_API_Name__c + ' WHERE CreatedDate < N_DAYS_AGO:' + days;
            Database.executeBatch(new CRMGlobalDeleteOldLogsBatch(query), 200);
        }
    }
}