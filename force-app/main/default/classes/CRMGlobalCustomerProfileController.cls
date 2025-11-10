/**
 * @description       : Controller class for CRMGlobalCustomerProfile LWC
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-31
 * @last modified by  : Franco
**/
public with sharing class CRMGlobalCustomerProfileController {

    /**
     * @description Get Account Id by Client Code, when account not found, create a dummy account with the client code
     * @param clientCode 
     * @return  `Id`
     */
    @AuraEnabled(cacheable=false)
    public static Id getAccountIdByClientCode(String clientCode) {
        Id customerRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
        String query = 'SELECT Id FROM Account WHERE (FinServ__CustomerID__c != null AND FinServ__CustomerID__c = :clientCode) OR (CRM_Global_IDNumber__pc != null AND CRM_Global_IDNumber__pc = :clientCode AND FinServ__SourceSystemId__c LIKE \'DMTM%\') limit 1';
        List<Account> accounts = Database.query(query, AccessLevel.SYSTEM_MODE);
        if(accounts.size() > 0) {
            return accounts[0].Id;
        }
        System.debug(LoggingLevel.INFO, 'No account found for client code: ' + clientCode);
        Account dummyAccount = new Account(LastName = '-', RecordTypeId = customerRTId, FinServ__CustomerID__c = clientCode);
        Database.SaveResult saveResult = Database.insert(dummyAccount, false, AccessLevel.SYSTEM_MODE);
        if (saveResult.isSuccess()) {
            System.debug(LoggingLevel.INFO, 'Successfully created an dummy account. Account ID: ' + saveResult.getId());
            return saveResult.getId();
        } else {
            for(Database.Error err : saveResult.getErrors()) {
                System.debug(LoggingLevel.ERROR, 'Error creating dummy account: ' + err.getMessage());
            }
        }
        return null;
    }
}