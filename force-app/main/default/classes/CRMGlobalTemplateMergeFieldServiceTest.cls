/**
 * @description       : Test class for CRMGlobalTemplateMergeFieldService
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-16
 * @last modified by  : Franco
**/
@IsTest
private class CRMGlobalTemplateMergeFieldServiceTest {

    @TestSetup
    static void setupTestData() {
        Id paRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
        Account testAccount = new Account(LastName = 'Test Account', RecordTypeId = paRTId);
        insert testAccount;

        Id polRTId = Schema.SObjectType.InsurancePolicy.getRecordTypeInfosByDeveloperName().get('Life').getRecordTypeId();
        InsurancePolicy policy = new InsurancePolicy(
            Name = '123456', 
            RecordTypeId = polRTId,
            NameInsuredId = testAccount.Id
        );
        insert policy;

    }

    @IsTest
    static void testHasMergeFields() {
        // Case 1: template with merge field
        System.assertEquals(true, CRMGlobalTemplateMergeFieldService.hasMergeFields('Hello {{{Name}}}'));
        
        // Case 2: template without merge field
        System.assertEquals(false, CRMGlobalTemplateMergeFieldService.hasMergeFields('Hello Name'));
        
        // Case 3: blank template
        System.assertEquals(false, CRMGlobalTemplateMergeFieldService.hasMergeFields(''));
    }

    @IsTest
    static void testGetMergeFieldsFromTemplate() {
        String template = 'Dear {{{Name}}}, your Account is {{{Account.Name}}}, email: {{{Email}}}';
        Set<String> fields = CRMGlobalTemplateMergeFieldService.getMergeFieldsFromTemplate(template);
        
        System.assertEquals(3, fields.size());
        System.assert(fields.contains('Name'));
        System.assert(fields.contains('Account.Name'));
        System.assert(fields.contains('Email'));
        
        // Case: blank template
        Set<String> empty = CRMGlobalTemplateMergeFieldService.getMergeFieldsFromTemplate('');
        System.assertEquals(0, empty.size());
    }

    @IsTest
    static void testMergeTemplateWithoutRelationship() {
        Account acc = [SELECT Id, Name FROM Account WHERE LastName = 'Test Account' LIMIT 1];
        
        String template = 'Hello {{{Name}}}, your Id is {{{Id}}}';
        String result = CRMGlobalTemplateMergeFieldService.mergeTemplate(template, acc, false);
        
        System.assert(result.contains('Test Account'));
    }

    @IsTest
    static void testMergeTemplateWithRelationship() {
        
        InsurancePolicy policy = [SELECT Id, Name, NameInsured.Name FROM InsurancePolicy WHERE Name = '123456' LIMIT 1];
        
        String template = 'Dear {{{NameInsured.Name}}}, your Policy Number is {{{Name}}}';
        String result = CRMGlobalTemplateMergeFieldService.mergeTemplate(template, policy, false);
        
        System.assert(result.contains('123456'));
        System.assert(result.contains('Test Account'));
    }

    @IsTest
    static void testMergeTemplateWithUrlEncode() {
        Account acc = new Account(Name = 'Test & Encode');

        String template = 'Account name: {{{Name}}}';
        String result = CRMGlobalTemplateMergeFieldService.mergeTemplate(template, acc, true);
        
        System.assert(result.contains('%26')); // URL encoded "&"
    }

    @IsTest
    static void testMergeTemplateEdgeCases() {
        // Case 1: null record
        String template = 'Hello {{{Name}}}';
        String result = CRMGlobalTemplateMergeFieldService.mergeTemplate(template, null, false);
        System.assertEquals('Hello {{{Name}}}', result);

        // Case 2: blank template
        result = CRMGlobalTemplateMergeFieldService.mergeTemplate('', new Account(Name='Test'), false);
        System.assertEquals('', result);
    }
}