/**
 * @description       : Test class for CRMPHKLInsurancePolicyCoverageController
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-16
 * @last modified by  : Franco
**/
@isTest
private class CRMPHKLInsurancePolicyCoverageConTest {

    @TestSetup
    static void setupTestData() {
        // Create test Account
        Id paRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
        Account testAccount = new Account(
            LastName = 'Test Account',
            RecordTypeId = paRTId
        );
        insert testAccount;

        // Create test Insurance Policy
        Id polRTId = Schema.SObjectType.InsurancePolicy.getRecordTypeInfosByDeveloperName().get('Life').getRecordTypeId();
        InsurancePolicy testPolicy = new InsurancePolicy(
            Name = 'Test Policy',
            RecordTypeId = polRTId,
            NameInsuredId = testAccount.Id
        );
        insert testPolicy;

        // Create test Insurance Policy Coverage records
        List<InsurancePolicyCoverage> testCoverages = new List<InsurancePolicyCoverage>();
        for (Integer i = 1; i <= 3; i++) {
            testCoverages.add(new InsurancePolicyCoverage(
                InsurancePolicyId = testPolicy.Id
            ));
        }
        insert testCoverages;
    }

    @isTest
    static void testGetFirstCoverageId_Success() {
        // Get test data
        InsurancePolicy testPolicy = [SELECT Id FROM InsurancePolicy LIMIT 1];
        
        Test.startTest();
        Id firstCoverageId = CRMPHKLInsurancePolicyCoverageController.getFirstCoverageId(testPolicy.Id);
        Test.stopTest();
        
        // Verify that the first coverage ID is returned
        System.assertNotEquals(null, firstCoverageId, 'First coverage ID should not be null');
    }

    @isTest
    static void testGetFirstCoverageId_NullInput() {
        Test.startTest();
        Id result = CRMPHKLInsurancePolicyCoverageController.getFirstCoverageId(null);
        Test.stopTest();
        
        System.assertEquals(null, result, 'Should return null when input is null');
    }

    @isTest
    static void testGetFirstCoverageId_NoCoverages() {
        // Create a policy without coverages
        Id paRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
        Account testAccount = new Account(LastName = 'Test Account No Coverage', RecordTypeId = paRTId);
        insert testAccount;
        
        Id polRTId = Schema.SObjectType.InsurancePolicy.getRecordTypeInfosByDeveloperName().get('Life').getRecordTypeId();
        InsurancePolicy testPolicy = new InsurancePolicy(
            Name = 'Test Policy No Coverage',
            RecordTypeId = polRTId,
            NameInsuredId = testAccount.Id
        );
        insert testPolicy;
        
        Test.startTest();
        Id result = CRMPHKLInsurancePolicyCoverageController.getFirstCoverageId(testPolicy.Id);
        Test.stopTest();
        
        System.assertEquals(null, result, 'Should return null when no coverages exist');
    }

    @isTest
    static void testGetDetailFieldsetFields_DefaultFieldSet() {
        Test.startTest();
        List<String> fieldApiNames = CRMPHKLInsurancePolicyCoverageController.getDetailFieldsetFields(null);
        Test.stopTest();
        
        // Verify that we get some fields back (assuming the default field set exists)
        System.assertNotEquals(null, fieldApiNames, 'Field list should not be null');
    }

    @isTest
    static void testGetDetailFieldsetFields_EmptyString() {
        Test.startTest();
        List<String> fieldApiNames = CRMPHKLInsurancePolicyCoverageController.getDetailFieldsetFields('');
        Test.stopTest();
        
        // Should default to Insurance_Policy_Coverage_Detail_Fields
        System.assertNotEquals(null, fieldApiNames, 'Field list should not be null');
    }

    @isTest
    static void testGetDetailFieldsetFields_BlankString() {
        Test.startTest();
        List<String> fieldApiNames = CRMPHKLInsurancePolicyCoverageController.getDetailFieldsetFields('   ');
        Test.stopTest();
        
        // Should default to Insurance_Policy_Coverage_Detail_Fields
        System.assertNotEquals(null, fieldApiNames, 'Field list should not be null');
    }

    @isTest
    static void testGetDetailFieldsetFields_NonExistentFieldSet() {
        Test.startTest();
        List<String> fieldApiNames = CRMPHKLInsurancePolicyCoverageController.getDetailFieldsetFields('NonExistentFieldSet');
        Test.stopTest();
        
        // Should return empty list for non-existent field set
        System.assertEquals(0, fieldApiNames.size(), 'Should return empty list for non-existent field set');
    }

    @isTest
    static void testGetDetailFieldsetFields_ValidFieldSet() {
        Test.startTest();
        List<String> fieldApiNames = CRMPHKLInsurancePolicyCoverageController.getDetailFieldsetFields('Insurance_Policy_Coverage_Detail_Fields');
        Test.stopTest();
        
        System.assertNotEquals(null, fieldApiNames, 'Field list should not be null');
    }
}