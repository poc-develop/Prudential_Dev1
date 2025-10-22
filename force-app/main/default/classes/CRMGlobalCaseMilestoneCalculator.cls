/**
 * @description       : Calculate a dynamic time trigger for a milestone based on the milestone type, the properties of the case.
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-09-18
 * @last modified by  : Franco
**/
global with sharing class CRMGlobalCaseMilestoneCalculator implements Support.MilestoneTriggerTimeCalculator {

    private static final String RECORDTYPE_REQUEST = 'Request';
    private static final String STATUS_FIRST_ROUND_PROCESSING = '1st Round Processing';
    private static final String STATUS_SECOND_ROUND_PROCESSING = '2nd Round Processing';

    /**
     * @description : Calculate the Milestone Trigger Time based on Case Status and TAT Due Dates.
     * @param caseId 
     * @param milestoneTypeId 
     * @return  `Integer`
     */
    global Integer calculateMilestoneTriggerTime(String caseId, String milestoneTypeId) {

        List<Case> cases = [
            SELECT Id, Status, LastModifiedDate, CRM_Global_TAT_DueDate_1__c, CRM_Global_TAT_DueDate_2__c 
            FROM CASE
            WHERE Id = :caseId
            AND RecordType.DeveloperName = :RECORDTYPE_REQUEST
            AND (
                  (Status = :STATUS_FIRST_ROUND_PROCESSING AND CRM_Global_TAT_DueDate_1__c != NULL)
               OR (Status = :STATUS_SECOND_ROUND_PROCESSING AND CRM_Global_TAT_DueDate_2__c != NULL)
            )
        ];
        if(cases.isEmpty()) {
            return null;
        }
        Case updatedCase = cases[0];

        if(updatedCase.Status == STATUS_FIRST_ROUND_PROCESSING && updatedCase.CRM_Global_TAT_DueDate_1__c > updatedCase.LastModifiedDate) {
            BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = TRUE];
            Long diffInMilliSeconds = BusinessHours.diff(bh.Id, updatedCase.LastModifiedDate, updatedCase.CRM_Global_TAT_DueDate_1__c);
            return Integer.valueOf(diffInMilliSeconds / (1000 * 60));
        } else if(updatedCase.Status == STATUS_SECOND_ROUND_PROCESSING && updatedCase.CRM_Global_TAT_DueDate_2__c > updatedCase.LastModifiedDate) {
            BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = TRUE];
            Long diffInMilliSeconds = BusinessHours.diff(bh.Id, updatedCase.LastModifiedDate, updatedCase.CRM_Global_TAT_DueDate_2__c);
            return Integer.valueOf(diffInMilliSeconds / (1000 * 60));
        }
        return null;
    }

}