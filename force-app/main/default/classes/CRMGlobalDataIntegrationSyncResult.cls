/**
 * @description       : Data Integration Sync Result for LWC
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-19
 * @last modified by  : Franco
**/
public with sharing class CRMGlobalDataIntegrationSyncResult {

    /** @description Represents success or failure of the sync process */
    @AuraEnabled
    public Boolean isSuccess { get; set; }

    /** @description Message to be displayed to the user */
    @AuraEnabled
    public String message { get; set; }

    /** @description Additional data related to the sync process */
    @AuraEnabled
    public Object data { get; set; }

    /**
     * @description Constructor to initialize the CRMGlobalDataIntegrationSyncResult object
     * @param isSuccess 
     * @param message 
     * @param data 
     */
    public CRMGlobalDataIntegrationSyncResult(Boolean isSuccess, String message, Object data) {
        this.isSuccess = isSuccess;
        this.message = message;
        this.data = data;
    }
}