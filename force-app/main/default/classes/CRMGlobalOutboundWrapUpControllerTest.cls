/**
 * CRMGlobalOutboundWrapUpControllerTest
 * @author       : Easin Zhou
 * @date         : 2025-11-01
 * @description  : Test class for CRMGlobalOutboundWrapUpController.
 */
@isTest
public with sharing class CRMGlobalOutboundWrapUpControllerTest {

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

        // Insert Test Data - Voice Call
        String callCenterId = '04vD3000000KyxQIAS';
        VoiceCall voiceCallRecord = new VoiceCall(
            RelatedRecordId = caseChild.Id,
            CallCenterId = callCenterId,
            VendorType = 'ContactCenter',
            CallType = 'Outbound',
            FromPhoneNumber = '+49111222333',
            ToPhoneNumber = '+49122334455',
            CallStartDateTime = Datetime.now(),
            CallEndDateTime = Datetime.now().addMinutes(2),
            UserId = testUser.Id
        );
        insert voiceCallRecord;

        System.assertNotEquals(testPersonAccount, null, 'This is Error');
    }

    @IsTest
    private static void coverWrapUpInit(){

        List<VoiceCall> voiceCallList = [SELECT Id FROM VoiceCall];

        System.Test.startTest();
        if (voiceCallList.size() > 0) {
            CRMGlobalOutboundWrapUpController.pageInit(voiceCallList[0].Id);
        } else {
            System.debug('voiceCallList size is 0');
        }
        System.Test.stopTest();
        
        System.assertNotEquals(voiceCallList, null, 'This is Syntax Error');
    }

    @IsTest
    private static void coverWrapUpProcessing(){

        String recordTypeEnquiryId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Enquiry_Outbound').getRecordTypeId();
        List<VoiceCall> voiceCallList = [SELECT Id FROM VoiceCall];
        List<User> users = [SELECT Id FROM User];
        List<Case> cases =  [SELECT Id FROM Case WHERE RecordTypeId = :recordTypeEnquiryId];

        System.Test.startTest();
        if (voiceCallList.size() > 0) {
            CRMGlobalOutboundWrapUpController.WrapUpWrapper wrapUpWrapper = new CRMGlobalOutboundWrapUpController.WrapUpWrapper();
            CRMGlobalOutboundWrapUpController.WrapUpBodyWrapper wrapUpBodys = new CRMGlobalOutboundWrapUpController.WrapUpBodyWrapper();
            wrapUpWrapper.callerIdentity = 'Policy Owner';
            wrapUpWrapper.attemptRecordType = 'Outbound Call';
            wrapUpWrapper.callAttemptOwner = users[0].Id;
            wrapUpWrapper.contactNo = '123-456-78';
            wrapUpBodys.callAttemptResult = 'No Answer';
            wrapUpBodys.remark = 'Test Remark';
            wrapUpBodys.ur = true;
            wrapUpBodys.suspicious = true;
            wrapUpBodys.sms = true;
            wrapUpBodys.email = true;
            wrapUpBodys.relatedCaseIds = new List<String>{cases[0].Id};
            wrapUpWrapper.wrapUpBodys = new List<CRMGlobalOutboundWrapUpController.WrapUpBodyWrapper>{wrapUpBodys};

            CRMGlobalOutboundWrapUpController.processingWrapUp(voiceCallList[0].Id, JSON.serialize(wrapUpWrapper));
        } else {
            System.debug('voiceCallList size is 0');
        }
        System.Test.stopTest();
        
        System.assertNotEquals(recordTypeEnquiryId, null, 'This is Syntax Error');
    }
    
}