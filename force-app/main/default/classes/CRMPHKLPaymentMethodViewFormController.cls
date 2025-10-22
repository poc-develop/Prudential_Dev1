public with sharing class CRMPHKLPaymentMethodViewFormController {
    @AuraEnabled(cacheable=true)
    public static Map<String,String> policyMethodAndAccountId(Id insurancePolicyId) {
        if (insurancePolicyId == null) {
            return null;
        }

        Map<String,String> result = new Map<String,String>();

        // Query minimal fields; limit to 1 by oldest CreatedDate
        List<FinServ__PolicyPaymentMethod__c> methods = [
            SELECT Id,FinServ__FinancialAccount__c
            FROM FinServ__PolicyPaymentMethod__c
            WHERE FinServ__InsurancePolicy__c = :insurancePolicyId
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        result.put('policyPaymentMethodRecordId',methods.isEmpty() ? null : methods[0].Id);
        result.put('financialAccountRecordId',methods.isEmpty() ? null : methods[0].FinServ__FinancialAccount__c);

        return result;
    }
}