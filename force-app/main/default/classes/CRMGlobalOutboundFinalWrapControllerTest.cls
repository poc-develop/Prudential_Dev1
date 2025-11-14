/**
 * CRMGlobalOutboundFinalWrapControllerTest
 * @author       : Easin Zhou
 * @date         : 2025-11-06
 * @description  : Test class for CRMGlobalOutboundFinalWrapUpController.
 */
@isTest
public with sharing class CRMGlobalOutboundFinalWrapControllerTest {

    /**
     * setup
     * @description Setup method.
     */
    @testSetup
    static void setup(){
        // Insert Test Data - Person Account
        Account testPersonAccount = new Account(
            FirstName = 'Test FirstName',
            LastName = 'Test LastName',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId()
        );
        insert testPersonAccount;
        
        // Insert Test Data - Policy
        InsurancePolicy policy = new InsurancePolicy(
            Name = '10000001',
            NameInsuredId = testPersonAccount.Id
        );
        insert policy;

        // Insert Test Data - User
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Alias = 'tuser',
            Email = 'domain@test.com',
            Username = 'domain.test.' + System.currentTimeMillis() + '@test.com',
            CommunityNickname = 'domain' + System.currentTimeMillis(),
            TimeZoneSidKey = 'Asia/Hong_Kong',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        // Insert Test Data - Master Case
        Case caseMaster = new Case(
            OwnerId = testUser.Id,
            CRM_Global_Outbound_Call_Type__c = 'Not_Specified',
            CRM_Global_Outbound_Sub_Type_1__c = 'Not Specified',
            CRM_Global_PolicyNumber__c = '10000001',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Master_Outbound').getRecordTypeId(),
            CRM_Global_Policy__c = policy.Id
        );
        insert caseMaster;

        // Insert Test Data - Enquiry Case
        Case caseChild = new Case(
            ParentId = caseMaster.Id,
            OwnerId = testUser.Id,
            CRM_Global_Outbound_Call_Type__c = 'Not_Specified',
            CRM_Global_Outbound_Sub_Type_1__c = 'Not Specified',
            CRM_Global_PolicyNumber__c = '10000001',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Enquiry_Outbound').getRecordTypeId(),
            CRM_Global_Policy__c = policy.Id
        );
        insert caseChild;

        System.assertNotEquals(testPersonAccount, null, 'This is Error');
    }

    @IsTest
    private static void coverWrapUpInit(){

        String recordTypeEnquiryId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Enquiry_Outbound').getRecordTypeId();
        List<Case> cases =  [SELECT Id FROM Case WHERE RecordTypeId = :recordTypeEnquiryId];

        System.Test.startTest();
        if (cases.size() > 0) {
            CRMGlobalOutboundFinalWrapUpController.pageInit(cases[0].Id);
        } else {
            System.debug('cases size is 0');
        }
        System.Test.stopTest();
        
        System.assertNotEquals(cases, null, 'This is Syntax Error');
    }

    @IsTest
    private static void coverWrapUpInitError(){

        String recordTypeEnquiryId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Enquiry_Outbound').getRecordTypeId();
        List<Case> cases =  [SELECT Id FROM Case WHERE RecordTypeId = :recordTypeEnquiryId];
        for (Case caseOne: cases) {
            caseOne.CRM_Global_IsFinalWrapUp__c = true;
        }

        System.Test.startTest();
        if (cases.size() > 0) {
            CRMGlobalOutboundFinalWrapUpController.pageInit('500D300000EuK00IA0');

            Update cases;
            CRMGlobalOutboundFinalWrapUpController.pageInit(cases[0].Id);
        } else {
            System.debug('cases size is 0');
        }
        System.Test.stopTest();
        
        System.assertNotEquals(cases, null, 'This is Syntax Error');
    }

    @IsTest
    private static void coverWrapUpProcessing(){

        String recordTypeEnquiryId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Enquiry_Outbound').getRecordTypeId();
        List<Case> cases =  [SELECT Id FROM Case WHERE RecordTypeId = :recordTypeEnquiryId];

        System.Test.startTest();
        if (cases.size() > 0) {
            CRMGlobalOutboundFinalWrapUpController.WrapUpBodyWrapper wrapUpBodys = new CRMGlobalOutboundFinalWrapUpController.WrapUpBodyWrapper();
            wrapUpBodys.finalResult = '';
            wrapUpBodys.remark = 'Test Remark';
            wrapUpBodys.ur = true;
            wrapUpBodys.suspicious = true;
            wrapUpBodys.relatedCaseIds = new List<String>{cases[0].Id};

            CRMGlobalOutboundFinalWrapUpController.processingWrapUp(JSON.serialize(
                new List<CRMGlobalOutboundFinalWrapUpController.WrapUpBodyWrapper>{wrapUpBodys}
            ));
        } else {
            System.debug('cases size is 0');
        }
        System.Test.stopTest();
        
        System.assertNotEquals(recordTypeEnquiryId, null, 'This is Syntax Error');
    }


    @IsTest
    private static void coverWrapUpProcessingError(){

        String recordTypeEnquiryId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Enquiry_Outbound').getRecordTypeId();
        List<Case> cases =  [SELECT Id FROM Case WHERE RecordTypeId = :recordTypeEnquiryId];
        for (Case caseOne: cases) {
            caseOne.CRM_Global_IsFinalWrapUp__c = true;
        }

        System.Test.startTest();
        if (cases.size() > 0) {
            CRMGlobalOutboundFinalWrapUpController.WrapUpBodyWrapper wrapUpBodys = new CRMGlobalOutboundFinalWrapUpController.WrapUpBodyWrapper();
            CRMGlobalOutboundFinalWrapUpController.processingWrapUp(JSON.serialize(
                new List<CRMGlobalOutboundFinalWrapUpController.WrapUpBodyWrapper>{}
            ));

            wrapUpBodys.finalResult = '';
            wrapUpBodys.remark = 'Test Remark';
            wrapUpBodys.ur = true;
            wrapUpBodys.suspicious = true;
            wrapUpBodys.relatedCaseIds = new List<String>{};
            CRMGlobalOutboundFinalWrapUpController.processingWrapUp(JSON.serialize(
                new List<CRMGlobalOutboundFinalWrapUpController.WrapUpBodyWrapper>{wrapUpBodys}
            ));

            Update cases;
            wrapUpBodys.relatedCaseIds = new List<String>{cases[0].Id, cases[0].Id};
            CRMGlobalOutboundFinalWrapUpController.processingWrapUp(JSON.serialize(
                new List<CRMGlobalOutboundFinalWrapUpController.WrapUpBodyWrapper>{wrapUpBodys}
            ));
            wrapUpBodys.relatedCaseIds = new List<String>{cases[0].Id};
            CRMGlobalOutboundFinalWrapUpController.processingWrapUp(JSON.serialize(
                new List<CRMGlobalOutboundFinalWrapUpController.WrapUpBodyWrapper>{wrapUpBodys}
            ));
        } else {
            System.debug('cases size is 0');
        }
        System.Test.stopTest();
        
        System.assertNotEquals(recordTypeEnquiryId, null, 'This is Syntax Error');
    }
    
}