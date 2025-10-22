@IsTest
private class CRMPHKLPaymentMethodViewFormCtrlTest {

    // Utility to create minimal Insurance Policy and related Payment Method + Financial Account
    // private static Id createData(Boolean createPaymentMethod) {
    //     // Create an Account and a Contact to satisfy common FinServ lookups if needed
    //     Account acc = new Account(Name = 'Test Household');
    //     insert acc;

    //     // Create a minimal Insurance Policy record
    //     // Using generic SObject in case FinServ managed fields vary by org setup
    //     SObject policy = (SObject) Schema.getGlobalDescribe().get('FinServ__InsurancePolicy__c').newSObject();
    //     // Required fields can vary by org; set common ones defensively if present
    //     if (policy.getSObjectType().getDescribe().fields.getMap().containsKey('Name')) {
    //         policy.put('Name', 'Test Policy');
    //     }
    //     if (policy.getSObjectType().getDescribe().fields.getMap().containsKey('FinServ__PrimaryOwner__c')) {
    //         // Set to Account if allowed, else ignore
    //         policy.put('FinServ__PrimaryOwner__c', acc.Id);
    //     }
    //     insert policy;

    //     if (createPaymentMethod) {
    //         // Create a Financial Account (minimal)
    //         SObject finAcct = (SObject) Schema.getGlobalDescribe().get('FinServ__FinancialAccount__c').newSObject();
    //         if (finAcct.getSObjectType().getDescribe().fields.getMap().containsKey('Name')) {
    //             finAcct.put('Name', 'Test Financial Account');
    //         }
    //         insert finAcct;

    //         // Create Policy Payment Method tied to the policy and financial account
    //         SObject ppm = (SObject) Schema.getGlobalDescribe().get('FinServ__PolicyPaymentMethod__c').newSObject();
    //         ppm.put('FinServ__InsurancePolicy__c', (Id)policy.get('Id'));
    //         ppm.put('FinServ__FinancialAccount__c', (Id)finAcct.get('Id'));
    //         insert ppm;
    //     }

    //     return (Id) policy.get('Id');
    // }

    // @IsTest
    // static void policyMethodAndAccountId_returnsNullWhenNullId() {
    //     Test.startTest();
    //     Map<String,String> result = CRMPHKLPaymentMethodViewFormController.policyMethodAndAccountId(null);
    //     Test.stopTest();

    //     System.assertEquals(null, result, 'Expected null when insurancePolicyId is null');
    // }

    // @IsTest
    // static void policyMethodAndAccountId_returnsNullsWhenNoPaymentMethod() {
    //     Id policyId = createData(false);

    //     Test.startTest();
    //     Map<String,String> result = CRMPHKLPaymentMethodViewFormController.policyMethodAndAccountId(policyId);
    //     Test.stopTest();

    //     System.assertNotEquals(null, result, 'Result map should be initialized');
    //     System.assertEquals(null, result.get('policyPaymentMethodRecordId'), 'No PPM should return null Id');
    //     System.assertEquals(null, result.get('financialAccountRecordId'), 'No Financial Account should return null Id');
    // }

    // @IsTest
    // static void policyMethodAndAccountId_returnsOldestPaymentMethod() {
    //     // Create initial data with one payment method
    //     Id policyId = createData(true);

    //     // Create a second, newer Payment Method for the same policy to ensure ORDER BY ASC picks the oldest
    //     // Create another financial account
    //     SObject finAcct2 = (SObject) Schema.getGlobalDescribe().get('FinServ__FinancialAccount__c').newSObject();
    //     if (finAcct2.getSObjectType().getDescribe().fields.getMap().containsKey('Name')) {
    //         finAcct2.put('Name', 'Test Financial Account 2');
    //     }
    //     insert finAcct2;

    //     // Create a short delay to ensure CreatedDate ordering difference (not strictly necessary in tests, but safe)
    //     // In tests, CreatedDate cannot be directly controlled; insertion order is sufficient.
    //     SObject ppmNewer = (SObject) Schema.getGlobalDescribe().get('FinServ__PolicyPaymentMethod__c').newSObject();
    //     ppmNewer.put('FinServ__InsurancePolicy__c', policyId);
    //     ppmNewer.put('FinServ__FinancialAccount__c', (Id)finAcct2.get('Id'));
    //     insert ppmNewer;

    //     // Query records to determine the oldest for assertion
    //     List<SObject> allPpms = Database.query('SELECT Id, CreatedDate, FinServ__FinancialAccount__c FROM FinServ__PolicyPaymentMethod__c WHERE FinServ__InsurancePolicy__c = :policyId ORDER BY CreatedDate ASC');
    //     System.assert(allPpms.size() >= 2, 'Expected at least two payment methods');

    //     Id oldestPpmId = (Id) allPpms[0].get('Id');
    //     Id oldestFinAcctId = (Id) allPpms[0].get('FinServ__FinancialAccount__c');

    //     Test.startTest();
    //     Map<String,String> result = CRMPHKLPaymentMethodViewFormController.policyMethodAndAccountId(policyId);
    //     Test.stopTest();

    //     System.assertNotEquals(null, result, 'Result map should not be null');
    //     System.assertEquals((String)oldestPpmId, result.get('policyPaymentMethodRecordId'), 'Should return the oldest PolicyPaymentMethod');
    //     System.assertEquals((String)oldestFinAcctId, result.get('financialAccountRecordId'), 'Should return Financial Account from the oldest PPM');
    // }
}