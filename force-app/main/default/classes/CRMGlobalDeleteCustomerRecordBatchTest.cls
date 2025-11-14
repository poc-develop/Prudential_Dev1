/**
 * Test class for CRMGlobalDeleteCustomerRecordBatch.
 * This class tests:
 * 1. The batch job successfully deletes records matching the criteria.
 */
@isTest
private class CRMGlobalDeleteCustomerRecordBatchTest {

    /**
     * Creates test data:
     * - 5 old Accounts (should be deleted)
     * - 5 new Accounts (should be kept)
     */
    @testSetup
    static void setupData() {
        Id accountRTId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND IsPersonType = false LIMIT 1].Id;
        List<Account> oldAccountsToInsert = new List<Account>();
        List<Account> newAccountsToInsert = new List<Account>();

        // 1. Create all records in memory
        for (Integer i = 0; i < 5; i++) {
            oldAccountsToInsert.add(new Account(Name = 'Old Account ' + i, RecordTypeId = accountRTId));
            newAccountsToInsert.add(new Account(Name = 'New Account ' + i, RecordTypeId = accountRTId));
        }
        
        // 2. Insert all records
        insert oldAccountsToInsert;
        insert newAccountsToInsert;

        // 3. Set CreatedDate for OLD records
        // This must be done AFTER insertion, one by one.
        Datetime oldDateTime = Datetime.now().addDays(-2);
        
        List<Account> oldAccounts = [SELECT Id FROM Account WHERE Name LIKE 'Old Account%'];
        for (Account a : oldAccounts) {
            Test.setCreatedDate(a.Id, oldDateTime);
        }
    }

    /**
     * Tests the Batchable's execute method and the resulting batch deletion.
     */
    @isTest
    static void testBatchDeletes() {
        Test.startTest();
        
        // Directly call the execute method
        String query = 'SELECT Id FROM Account ' + ' WHERE CreatedDate < N_DAYS_AGO:1';
        CRMGlobalDeleteCustomerRecordBatch batchJob = new CRMGlobalDeleteCustomerRecordBatch(query);
        Database.executeBatch(batchJob);
        
        Test.stopTest();

        // --- Verification ---

        // 2. Check that old records were deleted
        Integer remainingNewAccounts = [SELECT COUNT() FROM Account WHERE Name LIKE 'New Account%'];
        Integer remainingOldAccounts = [SELECT COUNT() FROM Account WHERE Name LIKE 'Old Account%'];
        
        System.assertEquals(5, remainingNewAccounts, 'Only the 5 new Accounts should remain.');
        System.assertEquals(0, remainingOldAccounts, 'Old Accounts has been deleted.');
    }
}