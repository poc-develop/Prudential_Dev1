/**
 * @description a class for lead data parameters
 * Lead Management
 */
public with sharing class CRMPHKLLeadDataParams implements CRMGlobalIntegratable {

    //Implemented from CRMGlobalIntegratable
    public String apiConfigKey { get; set; }

    //Collected from UI
    public String countryCode { get; set; }
    public String phoneNumber { get; set; }
    public Boolean walkIn { get; set; }
    public String lastName { get; set; }
    public Date leadDate { get; set; }
    public String campaignId { get; set; }

    //Not specified
    public String salutation { get; set; }
    public String firstName { get; set; }
    public String gender { get; set; }
    public String language { get; set; }
    public String email { get; set; }
    public String optOutStatus { get; set; }
    public String leadPartnerId { get; set; }
    public String interestedProduct { get; set; }
    public String existingCustomerIndicator { get; set; }
    public String preferredContactTime { get; set; }
    public String otherLeadComments { get; set; }
    public String referredAgentCode { get; set; }
    public String clientCode { get; set; }
    public String action { get; set; }


    /**
     * @description default constructor
     */
    public CRMPHKLLeadDataParams() {
        this.leadDate = Date.today();
    }

    /**
     * @description fullParameters constructor
     * @param countryCode
     * @param Phone
     * @param walkIn
     * @param lastName
     * @param leadDate
     */
    public CRMPHKLLeadDataParams(String countryCode, String phoneNumber, Boolean walkIn, String lastName, Date leadDate) {
        this.countryCode = countryCode;
        this.phoneNumber = phoneNumber;
        this.walkIn = walkIn;
        this.lastName = lastName;
        this.leadDate = leadDate != null ? leadDate : Date.today();

        CRM_PHKL_LeadCustomConfig__mdt config = CRM_PHKL_LeadCustomConfig__mdt.getInstance(this.walkIn ? 'Walk_In_Lead' : 'Non_Walk_In_Lead');
        this.campaignId = determineCampaignId(config) != null ? determineCampaignId(config) : (this.walkIn ? 'MKT_20201201_01' : 'MKT_20201201_02');
        this.apiConfigKey = determineApiConfigKey(config);
    }

    /**
     * @description set campaign id based on walkIn flag
     */
    private static String determineCampaignId (CRM_PHKL_LeadCustomConfig__mdt config) {
        if (config != null) {
            return config.CampaignId__c;
        } else {
            return null;
        }
    }

    private static String determineApiConfigKey (CRM_PHKL_LeadCustomConfig__mdt config) {
        if (config != null) {
            return config.ApiConfigKey__c;
        } else {
            return null;
        }
    }

    /**
     * @description Interface method implementation
     * @return String apiConfigKey value
     */
    public String getApiConfigKey() {
        return this.apiConfigKey;
    } 

    public String serializeToJson() {
        Map<String, Object> jsonMap = new Map<String, Object>();

        if (this.countryCode != null) { jsonMap.put('countryCode', this.countryCode); }
        if (this.phoneNumber != null) { jsonMap.put('phoneNumber', this.phoneNumber); }
        if (this.walkIn != null) { jsonMap.put('walkIn', this.walkIn); }
        if (this.leadDate != null) { jsonMap.put('leadDate', this.leadDate); }
        if (this.campaignId != null) { jsonMap.put('campaignId', this.campaignId); }

        //if (this.lastName != null) { jsonMap.put('lastName', this.lastName); }        
        //API required first name instead of last name
        if (this.lastName != null && this.firstName == null) { 
            jsonMap.put('lastName', '');
            jsonMap.put('firstName', this.lastName); 
        }

        if (this.lastName != null && this.firstName != null) { 
            jsonMap.put('lastName', this.lastName);
            jsonMap.put('firstName', this.firstName); 
        }

        //handle other fields
        jsonMap.put('salutation', this.salutation != null ? this.salutation : 'Mr.');
        //jsonMap.put('firstName', this.firstName != null ? this.firstName : 'T');
        jsonMap.put('gender', this.gender != null ? this.gender : '');
        jsonMap.put('language', this.language != null ? this.language : 'YUE');
        jsonMap.put('email', this.email != null ? this.email : 'dummy@dummy.com');
        jsonMap.put('optOutStatus', this.optOutStatus != null ? this.optOutStatus : 'N');
        jsonMap.put('leadPartnerId', this.leadPartnerId != null ? this.leadPartnerId : '');
        jsonMap.put('interestedProduct', this.interestedProduct != null ? this.interestedProduct : '');
        jsonMap.put('existingCustomerIndicator', this.existingCustomerIndicator != null ? this.existingCustomerIndicator : 'N');
        jsonMap.put('preferredContactTime', this.preferredContactTime != null ? this.preferredContactTime : '09:00 - 12:00');
        jsonMap.put('otherLeadComments', this.otherLeadComments != null ? this.otherLeadComments : '');
        jsonMap.put('referredAgentCode', this.referredAgentCode != null ? this.referredAgentCode : 'Test Remarks');
        jsonMap.put('clientCode', this.clientCode != null ? this.clientCode : '');
        jsonMap.put('action', this.action != null ? this.action : 'CONTACT_REQUEST');

        return JSON.serialize(jsonMap);
    }


    /**
     * @description Interface method implementation - deserializeFromJson
     */
    public void deserializeFromJson(String serializedData) {
        try {
 
            Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(serializedData);
            
            if (jsonMap.containsKey('countryCode')) {
                this.countryCode = (String)jsonMap.get('countryCode');
            }
            if (jsonMap.containsKey('phoneNumber')) {
                this.phoneNumber = (String)jsonMap.get('phoneNumber');
            }
            if (jsonMap.containsKey('walkIn')) {
                this.walkIn = (Boolean)jsonMap.get('walkIn');
            }
            if (jsonMap.containsKey('lastName')) {
                this.lastName = (String)jsonMap.get('lastName');
            }
            if (jsonMap.containsKey('leadDate')) {
                String leadDateStr = (String)jsonMap.get('leadDate');
                this.leadDate = Date.valueOf(leadDateStr);
            }
            if (jsonMap.containsKey('campaignId')) {
                this.campaignId = (String)jsonMap.get('campaignId');
            }
 
            if (jsonMap.containsKey('salutation')) {
                this.salutation = (String)jsonMap.get('salutation');
            }
            if (jsonMap.containsKey('firstName')) {
                this.firstName = (String)jsonMap.get('firstName');
            }
            if (jsonMap.containsKey('gender')) {
                this.gender = (String)jsonMap.get('gender');
            }
            if (jsonMap.containsKey('language')) {
                this.language = (String)jsonMap.get('language');
            }
            if (jsonMap.containsKey('email')) {
                this.email = (String)jsonMap.get('email');
            }
            if (jsonMap.containsKey('optOutStatus')) {
                this.optOutStatus = (String)jsonMap.get('optOutStatus');
            }
            if (jsonMap.containsKey('leadPartnerId')) {
                this.leadPartnerId = (String)jsonMap.get('leadPartnerId');
            }
            if (jsonMap.containsKey('interestedProduct')) {
                this.interestedProduct = (String)jsonMap.get('interestedProduct');
            }
            if (jsonMap.containsKey('existingCustomerIndicator')) {
                this.existingCustomerIndicator = (String)jsonMap.get('existingCustomerIndicator');
            }
            if (jsonMap.containsKey('preferredContactTime')) {
                this.preferredContactTime = (String)jsonMap.get('preferredContactTime');
            }
            if (jsonMap.containsKey('otherLeadComments')) {
                this.otherLeadComments = (String)jsonMap.get('otherLeadComments');
            }
            if (jsonMap.containsKey('referredAgentCode')) {
                this.referredAgentCode = (String)jsonMap.get('referredAgentCode');
            }
            if (jsonMap.containsKey('clientCode')) {
                this.clientCode = (String)jsonMap.get('clientCode');
            }
            if (jsonMap.containsKey('action')) {
                this.action = (String)jsonMap.get('action');
            }
            
        } catch (Exception e) {
            System.debug('Error deserializing from JSON: ' + e.getMessage());
            throw new CRMPHKLLeadDataParamsException('Failed to deserialize from JSON: ' + e.getMessage());
        }
    }

    /**
     * @description  reconstruct
     */
    public static CRMPHKLLeadDataParams reconstruct(String serializedData, String apiConfigKey) {
        CRMPHKLLeadDataParams leadData = new CRMPHKLLeadDataParams();
        leadData.apiConfigKey = apiConfigKey;
        leadData.deserializeFromJson(serializedData);
        return leadData;
    }
    
    /**
     * @description Internal Exception class for Lead Data Params
     */
    public class CRMPHKLLeadDataParamsException extends Exception {}
}