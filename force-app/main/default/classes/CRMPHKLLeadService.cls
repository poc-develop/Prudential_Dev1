/**
 * @description Lead service
 * Lead Management
 */
public with sharing class CRMPHKLLeadService implements CRMPHKLSObjectServiceInterface {
    
    private Lead consolidatedLeadData;
    private CRMPHKLLeadDataParams LeadData;
    //private String serializedData;
    //private String apiConfigKey;

    private CRMGlobalCommonAPIServiceInterface apiService;
    private Boolean shouldCallApi = true;

    public CRMPHKLLeadService() {
        this.apiService = null;
        this.shouldCallApi = true;
    }

    public CRMPHKLLeadService(CRMGlobalCommonAPIServiceInterface apiService) {
        this.apiService = apiService;
        this.shouldCallApi = true;
    }

    public CRMPHKLLeadService(CRMGlobalCommonAPIServiceInterface apiService, Boolean shouldCallApi) {
        this.apiService = apiService;
        this.shouldCallApi = shouldCallApi;
    }

    public void collectLeadData(CRMPHKLLeadDataParams leadData) {
        this.LeadData = leadData;
        //this.serializedData = leadData.serializeToJson();
        //this.apiConfigKey = leadData.getApiConfigKey();
        this.consolidatedLeadData = createLeadFromData();
    }

    /**
     * @descrtion insert Lead data
     */
    public Database.SaveResult insertRecord(SObject record) {
        if (record instanceof Lead) {
            return Database.insert(record);
        }
        throw new TypeException('Only Lead records are supported');
    }

    /**
     * @description process Lead data
     */
    public Boolean processData() {
        Boolean isLeadSuccess = false;
        //Boolean isApiCallSuccess = false;

        try {
            if (consolidatedLeadData != null) {
                Database.SaveResult result = insertRecord(consolidatedLeadData);
                isLeadSuccess = result.isSuccess();

                if(isLeadSuccess && this.shouldCallApi && this.LeadData != null) {
                    String serializedData = this.LeadData.serializeToJson();
                    String apiConfigKey = this.LeadData.getApiConfigKey();
                    callExternalApiForLead(serializedData, apiConfigKey, result.getId());
                }
                return isLeadSuccess;
            }
            return true;
        } catch (Exception e) {
            System.debug('Error in CRMPHKLLeadService->processData(): ' + e.getMessage() + ' - ' + e.getStackTraceString());
            return isLeadSuccess;
        }
    }

    private Lead createLeadFromData() {
        if (this.LeadData == null) return null;

        Lead newLead = new Lead();
        newLead.LastName = this.LeadData.lastName;
        newLead.Phone = this.LeadData.phoneNumber;
        newLead.CRM_PHKL_Country_Code__c = this.LeadData.countryCode;
        newLead.CRM_PHKL_Is_Walk_In__c = this.LeadData.walkIn;
        newLead.CRM_PHKL_Lead_Date__c = this.LeadData.leadDate;
        newLead.CRM_PHKL_Campaign_Id__c = this.LeadData.campaignId;
        
        newLead.Status = 'New';
        newLead.Company = 'Default_Company';

        return newLead;
    }


    @Future(callout=true)
    private static void callExternalApiForLead(String serializedData, String apiConfigKey, String leadId) {
        try {
            CRMPHKLLeadDataParams leadData = CRMPHKLLeadDataParams.reconstruct(serializedData, apiConfigKey);
            CRMGlobalCommonAPIService apiService = new CRMGlobalCommonAPIService(leadData);
            HttpResponse response = apiService.callExternalApi();

            if (response != null && response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                system.debug(LoggingLevel.INFO, 'External API call successful for lead Id: ' + leadId);
                updateLeadApiStatus(leadId, 'Success', response.getStatusCode(), response.getBody());
            } else {
                system.debug(LoggingLevel.INFO, 'External API call failed for lead ID: ' + leadId);
                updateLeadApiStatus(leadId, 'Failed', response != null ? response.getStatusCode() : 500, response.getBody());
            }
        } catch (Exception e) {
            System.debug('Async API call exception for lead ID: ' + leadId + ': ' + e.getMessage());
            CRMGlobalLogManager.addApexErrorLog('API call failed for lead: ' + e.getMessage(), e);
            updateLeadApiStatus(leadId, 'Error', 500, e.getMessage());
        }
    }

    /**
     * @description 更新Lead的API调用状态
     */
    private static void updateLeadApiStatus(String leadId, String status, Integer statusCode, String responseBody) {
        try {
            Lead leadToUpdate = new Lead(
                Id = leadId,
                CRM_PHKL_API_Call_Status__c = status,
                CRM_PHKL_API_Response_Code__c = statusCode.toString(),
                CRM_PHKL_API_Response_Body__c = responseBody,
                CRM_PHKL_Last_API_Call_DateTime__c = System.now()
            );
            update leadToUpdate;
        } catch (Exception e) {
            System.debug('Failed to update lead API status: ' + e.getMessage());
        }
    }
}