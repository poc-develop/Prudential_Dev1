/**
 * @description       : Test class for CRMGlobalCustomerProfileController
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-10
 * @last modified by  : Franco
**/
@IsTest
private class CRMGlobalCustomerProfileControllerTest {

    @TestSetup
    static void setupData() {
        Id customerRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();

        // Insert a test Account with a known client code
        Account acc = new Account(
            LastName = 'Existing Customer',
            FinServ__CustomerID__c = 'CLIENT123',
            RecordTypeId = customerRTId
        );
        insert acc;
    }

    @IsTest
    static void testGetAccountIdByClientCode_Found() {
        // Existing Account should be found
        Test.startTest();
        Id accId = CRMGlobalCustomerProfileController.getAccountIdByClientCode('CLIENT123');
        Test.stopTest();

        System.assertNotEquals(null, accId, 'Account Id should not be null');
        Account found = [SELECT Id, FinServ__CustomerID__c FROM Account WHERE Id = :accId];
        System.assertEquals('CLIENT123', found.FinServ__CustomerID__c, 'Client Code should match');
    }

    @IsTest
    static void testGetAccountIdByClientCode_NotFound() {
        // Nonexistent client code should create a dummy account
        String newCode = 'NEWCLIENT456';
        Test.startTest();
        Id dummyId = CRMGlobalCustomerProfileController.getAccountIdByClientCode(newCode);
        Test.stopTest();

        System.assertNotEquals(null, dummyId, 'Dummy account should be created');
        Account dummy = [SELECT Id, FinServ__CustomerID__c, LastName FROM Account WHERE Id = :dummyId];
        System.assertEquals(newCode, dummy.FinServ__CustomerID__c, 'Dummy account should have matching client code');
        System.assertEquals('Dummy Account', dummy.LastName, 'Dummy account should have default last name');
    }

    @IsTest
    static void testGetAccountIdByClientCode_InsertFailure() {
        // Simulate failure by mocking Database.insert failure via invalid field
        Test.startTest();
        String clientCode = 'too_loong_client_code';
        for(Integer i = 0; i < 255; i++) {
            clientCode += 'a';
        }
        Id result = CRMGlobalCustomerProfileController.getAccountIdByClientCode(clientCode);
        Test.stopTest();

        System.assertEquals(null, result, 'Method should return null if insert fails');
    }
}