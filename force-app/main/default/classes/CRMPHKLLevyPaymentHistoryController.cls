/**
 * @description       : Controller for the Levy Payment History Page
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-11-11
 * @last modified by  : Franco
**/
public without sharing class CRMPHKLLevyPaymentHistoryController {

    /**
     * @description Get FieldSet Columns
     * @return  `List<Map<String, String>>`
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getFieldSetColumns() {
        List<Map<String, String>> result = new List<Map<String, String>>();

        for (Schema.FieldSetMember f : SObjectType.FinServ__FinancialAccountTransaction__c.FieldSets.CRM_PHKL_Levy_Payment_History_Field_Set.getFields()) {
            Map<String, String> col = new Map<String, String>();
            col.put('fieldName', f.getFieldPath());
            col.put('label', f.getLabel());

            Schema.SObjectField fieldRef = FinServ__FinancialAccountTransaction__c.SObjectType.getDescribe().fields.getMap().get(f.getFieldPath());
            String dataType = fieldRef.getDescribe().getType().name();

            col.put('type', dataType);
            result.add(col);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPolicyYearOptions(Id policyId) {
        List<Map<String, String>> result = new List<Map<String, String>>();

        InsurancePolicyCoverage policyCoverage = [SELECT Id, CRM_Global_PolicyCommencingInceptDate__c, CRM_Global_PolicyAnniversaryNextAVYDate__c 
                                                    FROM InsurancePolicyCoverage WHERE InsurancePolicyId = :policyId LIMIT 1];
        if (policyCoverage == null || policyCoverage.CRM_Global_PolicyCommencingInceptDate__c == null || policyCoverage.CRM_Global_PolicyAnniversaryNextAVYDate__c == null) {
            return result;
        }

        Date startDate = policyCoverage.CRM_Global_PolicyCommencingInceptDate__c;
        Date endDate = policyCoverage.CRM_Global_PolicyAnniversaryNextAVYDate__c;

        while (startDate < endDate) {
            Date rangeStart = startDate;
            Date rangeEnd = startDate.addYears(1).addDays(-1);

            if (rangeEnd >= endDate) {
                rangeEnd = endDate.addDays(-1);
            }

            result.add(new Map<String, String>{
                'label' => rangeStart.format() + ' - ' + rangeEnd.format(),
                'value' => rangeStart.day() + '/' + rangeStart.month() + '/' + rangeStart.year()
            });

            startDate = startDate.addYears(1);
        }

        return result;
    }

    /**
     * @description Sync Transactions
     * @param policyId 
     * @param selectedYear 
     */
    @AuraEnabled(cacheable=false)
    public static void syncTransactions(Id policyId, String selectedYear) {
        System.debug('selectedYear: ' + selectedYear);
        if (String.isBlank(selectedYear)) {
            return;
        }
        CRM_Global_DataIntegration_Config__mdt config = CRMGlobalDataIntegrationController.getIntegrationConfig('Prulife_getLevyPaymentHistory_Policy');
        if(config != null) {
            syncWithConfig(policyId, selectedYear, config);
        }
    }

    @TestVisible
    private static void syncWithConfig(Id policyId, String selectedYear, CRM_Global_DataIntegration_Config__mdt config) {
        config.Request_Body__c = '{"fi_pol_no": "{{{Name}}}", "fi_pol_year":"' + selectedYear + '"}';
        CRMGlobalDataIntegrationConfigWrapper configWrapper = new CRMGlobalDataIntegrationConfigWrapper(config, policyId);

        HttpResponse response = CRMGlobalDataIntegrationAPIService.callExternalApi(configWrapper);
        Object responseData = CRMGlobalDataIntegrationAPIService.parseApiResponse(configWrapper, response);
        CRMGlobalDataIntegrationService.processAndUpsertRecords(responseData, configWrapper);
    }

    /**
     * @description Get Transactions
     * @param policyId 
     * @param selectedYear 
     * @return  `List<FinServ__FinancialAccountTransaction__c>`
     */
    @AuraEnabled(cacheable=true)
    public static List<FinServ__FinancialAccountTransaction__c> getTransactions(Id policyId, String selectedYear) {
        List<String> fields = new List<String>();
        for (Schema.FieldSetMember f : SObjectType.FinServ__FinancialAccountTransaction__c.FieldSets.CRM_PHKL_Levy_Payment_History_Field_Set.getFields()) {
            fields.add(f.getFieldPath());
        }
        if (!fields.contains('Id')) {
            fields.add('Id');
        }

        String soql = 'SELECT ' + String.join(fields, ',') 
                    + ' FROM FinServ__FinancialAccountTransaction__c '
                    + ' WHERE FinServ__InsurancePolicy__c = :policyId AND RecordType.DeveloperName = \'Levy_Payment_History\'';
        return Database.query(soql);
    }
}