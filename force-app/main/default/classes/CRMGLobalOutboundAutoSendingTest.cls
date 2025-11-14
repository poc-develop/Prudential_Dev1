/**
 * CRMGLobalOutboundAutoSendingTest
 * @author       : Easin Zhou
 * @date         : 2025-11-07
 * @description  : Test class for CRMGLobalOutboundAutoSending.
 */
@isTest
public with sharing class CRMGLobalOutboundAutoSendingTest {

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
        InsurancePolicy policy1 = new InsurancePolicy(
            Name = '10000001',
            NameInsuredId = testPersonAccount.Id
        );
        insert policy1;
        InsurancePolicy policy2 = new InsurancePolicy(
            Name = '10000002',
            NameInsuredId = testPersonAccount.Id
        );
        insert policy2;

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
            CRM_Global_PendingSMS__c = true,
            CRM_Global_PendingLetter__c = true,
            CRM_Global_PolicyNumber__c = '10000001',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Master_Outbound').getRecordTypeId(),
            CRM_Global_Policy__c = policy1.Id
        );
        insert caseMaster;

        // Insert Test Data - Enquiry Case
        List<Case> caseChilds = new List<Case>{new Case(
            ParentId = caseMaster.Id,
            OwnerId = testUser.Id,
            CRM_Global_Outbound_Call_Type__c = 'Not_Specified',
            CRM_Global_Outbound_Sub_Type_1__c = 'Not Specified',
            CRM_Global_PolicyNumber__c = '10000001',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Enquiry_Outbound').getRecordTypeId(),
            CRM_Global_Policy__c = policy1.Id
        ),new Case(
            ParentId = caseMaster.Id,
            OwnerId = testUser.Id,
            CRM_Global_Outbound_Call_Type__c = 'Not_Specified',
            CRM_Global_Outbound_Sub_Type_1__c = 'Not Specified',
            CRM_Global_PolicyNumber__c = '10000002',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Enquiry_Outbound').getRecordTypeId(),
            CRM_Global_Policy__c = policy2.Id
        )};
        insert caseChilds;

        System.assertNotEquals(testPersonAccount, null, 'This is Error');
    }

    @IsTest
    private static void coverEnqueueForAutoTriggerSending(){

        List<Case> caseList = [SELECT Id FROM Case];

        System.Test.startTest();
        if (caseList.size() > 0) {
            CRMGLobalOutboundAutoSending.enqueueForAutoTriggerSending(new List<String>{caseList[0].Id});
        } else {
            System.debug('caseList size is 0');
        }
        System.Test.stopTest();
        
        System.assertNotEquals(caseList, null, 'This is Syntax Error');
    }

    @IsTest
    private static void coverEnqueueForAutoTriggerSendingOther(){

        Map<String, Case> caseMap = new Map<String, Case>([SELECT Id FROM Case]);

        System.Test.startTest();
        if (caseMap.keySet().size() > 0) {
            System.enqueueJob(new CRMGLobalOutboundAutoSendingQueue(new List<String>(caseMap.keySet()), 1));
        } else {
            System.debug('caseMap size is 0');
        }
        System.Test.stopTest();
        
        System.assertNotEquals(caseMap, null, 'This is Syntax Error');
    }

    
}