/**
 * @description       : Test class for CRMGlobalAlertController
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-16
 * @last modified by  : Franco
**/
@isTest
public class CRMGlobalAlertControllerTest {
    private static Account testAccount;
    private static Task testAlertTask;
    private static Id alertRTId;
    
    @TestSetup
    private static void setupTestData() {
        Id paRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
        testAccount = new Account(LastName = 'Test Account', RecordTypeId = paRTId);
        insert testAccount;
        
        alertRTId = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Alert_Task').getRecordTypeId();
        testAlertTask = new Task(
            WhatId = testAccount.Id,
            RecordTypeId = alertRTId,
            Status = 'Active',
            Subject = 'Test Alert'
        );
        insert testAlertTask;
        
    }
    
    @isTest
    static void testGetAlertsSuccess() {
        setupTestData();
        Test.startTest();
        List<Task> result = CRMGlobalAlertController.getAlerts(testAccount.Id);
        Test.stopTest();
        System.assertEquals(1, result.size(),'Expected 1 alert to be returned');
        System.assertEquals(testAlertTask.Id, result[0].Id,'Alert ID should match');
    }

    @isTest
    static void testGetAlertsNoMatchingData() {
        setupTestData();
        Test.startTest();
        List<Task> result = CRMGlobalAlertController.getAlerts(null);
        Test.stopTest();
        System.assertEquals(0, result.size(),'No matching data should return an empty list');
    }

    @isTest
    static void testDismissTaskSuccess() {
        setupTestData();
        Test.startTest();
        CRMGlobalAlertController.dismissTask(testAlertTask.Id);
        Test.stopTest();
        Task updatedTask = [SELECT Id, Status FROM Task WHERE Id = :testAlertTask.Id LIMIT 1];
        System.assertEquals('Inactive', updatedTask.Status,'Task status should be Inactive after dismissal');
    }

    @IsTest
    static void testGetRecordTypeIdFoundAndNotFound() {
        setupTestData();

        Test.startTest();
        String found = CRMGlobalAlertController.getRecordTypeId('CRM_GLOBAL_Alert_Task');
        String notFound = CRMGlobalAlertController.getRecordTypeId('NON_EXISTING_RT');
        String blank = CRMGlobalAlertController.getRecordTypeId('');
        Test.stopTest();

        System.assertEquals(alertRTId, found, 'Should return the created record type Id');
        System.assertEquals(null, notFound, 'Should return null when not found');
        System.assertEquals(null, blank, 'Should return null when developer name is blank');
    }
    @IsTest
    static void testDismissTaskNullIdThrows() {
        setupTestData();
        try {
            Test.startTest();
            CRMGlobalAlertController.dismissTask(null);
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException for null Task Id');
        } catch (AuraHandledException e) {
            String msg = String.valueOf(e.getMessage());
            Boolean ok = msg.contains('Task ID cannot be null') || msg.contains('Script-thrown exception');
            System.assert(ok, 'Unexpected error message: ' + msg);
        }
    }

}