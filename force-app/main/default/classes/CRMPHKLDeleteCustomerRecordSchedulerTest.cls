/**
 * @description       : Test class for CRMPHKLDeleteCustomerRecordScheduler
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-11-06
 * @last modified by  : Franco
**/
@isTest
private class CRMPHKLDeleteCustomerRecordSchedulerTest {

    /**
     * Creates test data:
     * - 5 old Accounts (should be deleted)
     * - 5 new Accounts (should be kept)
     * - 5 old Contacts (should be deleted)
     * - 5 new Contacts (should be kept)
     */
    @testSetup
    static void setupData() {
        Id accountRTId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND IsPersonType = false LIMIT 1].Id;
        List<Account> accountsToInsert = new List<Account>();
        List<Contact> contactsToInsert = new List<Contact>();

        // 1. Create all records in memory
        for (Integer i = 0; i < 5; i++) {
            accountsToInsert.add(new Account(Name = 'Old Account ' + i, RecordTypeId = accountRTId));
            contactsToInsert.add(new Contact(LastName = 'Old Contact ' + i));
        }
        for (Integer i = 0; i < 5; i++) {
            accountsToInsert.add(new Account(Name = 'New Account ' + i, RecordTypeId = accountRTId));
            contactsToInsert.add(new Contact(LastName = 'New Contact ' + i));
        }
        
        // 2. Insert all records
        insert accountsToInsert;
        insert contactsToInsert;

        // 3. Set CreatedDate for OLD records
        // This must be done AFTER insertion, one by one.
        Datetime oldDateTime = Datetime.now().addDays(-2);
        
        List<Account> oldAccounts = [SELECT Id FROM Account WHERE Name LIKE 'Old Account%'];
        for (Account a : oldAccounts) {
            Test.setCreatedDate(a.Id, oldDateTime);
        }
        List<Contact> oldContacts = [SELECT Id FROM Contact WHERE LastName LIKE 'Old Contact%'];
        for (Contact c : oldContacts) {
            Test.setCreatedDate(c.Id, oldDateTime);
        }

        // Note: 'New' records will keep their 'today' CreatedDate by default.

        // Verify setup
        System.assertEquals(10, [SELECT COUNT() FROM Account]);
    }

    /**
     * Tests the Schedulable's execute method and the resulting batch deletion.
     */
    @isTest
    static void testSchedulerAndBatchDeletes() {
        Test.startTest();
        
        // Directly call the execute method
        CRMPHKLDeleteCustomerRecordScheduler scheduler = new CRMPHKLDeleteCustomerRecordScheduler();
        scheduler.execute(null);
        
        Test.stopTest();

        // --- Verification ---

        // 1. Check that 3 batch jobs were queued (one for Account, one for Contact)
        Integer batchJobsQueued = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'BatchApex'];
        System.assertEquals(2, batchJobsQueued, 'Should have queued 2 batch jobs.');

        // 2. Check that old records were deleted
        Integer remainingAccounts = [SELECT COUNT() FROM Account];
        Integer remainingContacts = [SELECT COUNT() FROM Contact];
        
        System.assertEquals(5, remainingAccounts, 'Only the 5 new Accounts should remain.');
        System.assertEquals(5, remainingContacts, 'Only the 5 new Contacts should remain.');

        // 3. Double-check that the *correct* records remain
        Integer newAccounts = [SELECT COUNT() FROM Account WHERE Name LIKE 'New Account%'];
        System.assertEquals(5, newAccounts, 'The remaining accounts should be the new ones.');
    }

    /**
     * Tests the System.schedule syntax to ensure the job can be scheduled.
     */
    @isTest
    static void testSystemSchedule() {
        Test.startTest();
        
        // Schedule the job
        String cronExp = '0 0 2 * * ?'; 
        String jobName = 'Test Daily Old Data Deletion';
        System.schedule(jobName, cronExp, new CRMPHKLDeleteCustomerRecordScheduler());
        
        Test.stopTest();

        // --- Verification ---
        // Check that the CronTrigger was created successfully
        Integer scheduledJobs = [SELECT COUNT() FROM CronTrigger WHERE CronExpression = :cronExp];
        System.assertEquals(1, scheduledJobs, 'The job should be scheduled.');
    }
}