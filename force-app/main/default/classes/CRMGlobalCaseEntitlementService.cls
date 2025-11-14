/**
 * @description       : 
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-11-14
 * @last modified by  : Franco
**/
public without sharing class CRMGlobalCaseEntitlementService {

    private static final Id CUSTOMER_RT_ID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
    private static final String CASE_ENTITLEMENT_ACCOUNT_SSID = 'DummyAccountForCaseEntitlement';
    private static final String REQUEST_CASE_ENTITLEMENT_PROCESS_NAME = 'Request Case Entitlement Process';
    private static final String REQUEST_CASE_ENTITLEMENT_NAME = 'Request Case Entitlement';
    private static Account caseEntitlementAccount = null;
    private static SlaProcess requestCaseEntitlementProcess = null;
    private static Entitlement requestCaseEntitlement = null;

    static {
        for(Account a : [SELECT Id FROM Account WHERE FinServ__SourceSystemId__c = :CASE_ENTITLEMENT_ACCOUNT_SSID LIMIT 1]) {
            caseEntitlementAccount = a;
        }
        for(SlaProcess sla : [SELECT Id FROM SlaProcess WHERE SobjectType = 'Case' AND Name = :REQUEST_CASE_ENTITLEMENT_PROCESS_NAME LIMIT 1]) {
            requestCaseEntitlementProcess = sla;
        }
        for(Entitlement entitlement : [SELECT Id FROM Entitlement WHERE Name = :REQUEST_CASE_ENTITLEMENT_NAME LIMIT 1]) {
            requestCaseEntitlement = entitlement;
        }
    }

    public static Entitlement getRequestCaseEntitlement() {
        if(requestCaseEntitlement == null) {
            requestCaseEntitlement = createRequestCaseEntitlement();
        }
        return requestCaseEntitlement;
    }

    private static Entitlement createRequestCaseEntitlement() {
        if(caseEntitlementAccount == null) {
            caseEntitlementAccount = createDummyAccountForCaseEntitlement();
        }
        Entitlement entitlement = new Entitlement(
            Name = REQUEST_CASE_ENTITLEMENT_NAME,
            AccountId = caseEntitlementAccount.Id,
            SlaProcessId = requestCaseEntitlementProcess.Id,
            StartDate = Date.today(),
            EndDate = Date.today().addYears(20)
        );
        Database.insert(entitlement, AccessLevel.SYSTEM_MODE);
        return entitlement;
    }

    private static Account createDummyAccountForCaseEntitlement() {
        Account dummyAccount = new Account(
            LastName = CASE_ENTITLEMENT_ACCOUNT_SSID, 
            FinServ__SourceSystemId__c = CASE_ENTITLEMENT_ACCOUNT_SSID,
            RecordTypeId = CUSTOMER_RT_ID
        );
        Database.upsert(dummyAccount, Account.FinServ__SourceSystemId__c, false, AccessLevel.SYSTEM_MODE);
        return dummyAccount;
    }
}