/**
 * @description       : Controller class for managing CRM global alerts functionality
 * @author            : Mark
 * @group             : 
 * @last modified on  : 08-31-2025
 * @last modified by  : Mark
**/
public with sharing class CRMGlobalAlertController {
     /**
     * @description : Retrieves active alert tasks associated with a specific account
     * @param accountId The ID of the account to retrieve alerts for
     * @return List<Task> List of active alert tasks matching the criteria
     */
    @AuraEnabled(cacheable=true)
    public static List<Task> getAlerts(Id accountId) {
        // Validate Task object read permission
        if (!Schema.SObjectType.Task.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view tasks');
        }

        // Validate required fields access
        if (!Schema.SObjectType.Task.fields.Status.isAccessible() ||
            !Schema.SObjectType.Task.fields.ActivityDate.isAccessible() ||
            !Schema.SObjectType.Task.fields.Description.isAccessible() ||
            !Schema.SObjectType.Task.fields.Subject.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view all alert fields');
        }

        // Get Record Type ID for CRM Global Alert tasks
        Id alertRecordTypeId = getValidAlertRecordTypeId();
        
        // Return empty list if accountId is null
        if (accountId == null) {
            return new List<Task>();
        }

        // Query using USER_MODE to enforce FLS and sharing rules
        return [
            SELECT Id, Status, ActivityDate, Description, Subject 
            FROM Task 
            WHERE WhatId = :accountId 
              AND RecordTypeId = :alertRecordTypeId 
              AND Status = 'Active'
            WITH USER_MODE
            ORDER BY ActivityDate ASC
        ];
    }
    
    /**
     * @description :  Marks a specific alert task as inactive (dismisses the alert)
     * @param taskId The ID of the task to dismiss
     */
    @AuraEnabled(cacheable=false)
    public static void dismissTask(Id taskId) {
        // Validate Task object update permission
        if (!Schema.SObjectType.Task.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update tasks');
        }

        // Validate Status field update permission
        if (!Schema.SObjectType.Task.fields.Status.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update task status');
        }

        // Validate taskId is not null
        if (taskId == null) {
            throw new AuraHandledException('Task ID cannot be null');
        }

        Task t = new Task(Id = taskId, Status = 'Inactive');

        Database.SaveResult sr = Database.update(t, /* allOrNone */ false);
        if (!sr.isSuccess()) {
            throw new AuraHandledException('Failed to dismiss alert: ');
        }
    }
    
    /**
     * @description : Retrieves the Record Type ID for a Task record type using its developer name
     * @param developerName The developer name of the record type to retrieve
     * @return String The ID of the matching record type, or null if not found
     */
    @AuraEnabled(cacheable=true)
    public static String getRecordTypeId(String developerName) {
        // Validate RecordType object read permission
        if (!Schema.SObjectType.RecordType.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view record types');
        }

        // Return null if developer name is blank
        if (String.isBlank(developerName)) {
            return null;
        }
        
        // Query using USER_MODE to enforce security
        List<RecordType> recordTypes = [
            SELECT Id 
            FROM RecordType 
            WHERE DeveloperName = :developerName 
            AND SObjectType = 'Task'
            WITH USER_MODE
            LIMIT 1
        ];
    
        
        if (recordTypes.size() > 0) {
            return recordTypes[0].Id;
        } else {
            return null; 
        }
            
    }

    /**
     * @description :  Helper method to get valid alert record type ID with security checks
     * @return Id The ID of the valid alert record type
     * @throws AuraHandledException If the alert record type is not found or inaccessible
     */
    private static Id getValidAlertRecordTypeId() {
        // Reuse existing method with security checks
        String rtId = getRecordTypeId('CRM_GLOBAL_Alert_Task');
        
        if (rtId == null) {
            throw new AuraHandledException('Alert record type not found or inaccessible');
        }
        
        return rtId;
    }
}