/**
 * @description       : Utility class to retrieve country configuration.
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-11
 * @last modified by  : Franco
**/
public with sharing class CRMGlobalCountryConfigUtil {

    private static String country;

    /**
     * @description Retrieves the country configuration from the CRM_Global_CountryConfig__mdt custom metadata type.
     * @return The country as a String.
     * @throws CRMGlobalCountryNotConfiguredException if no country configuration is found.
     */
    public static String getCountry() {
        if (country == null) {
            List<CRM_Global_CountryConfig__mdt> configs = CRM_Global_CountryConfig__mdt.getAll().values();
            if (!configs.isEmpty()) {
                country = configs[0].Country__c;
            } else {
                throw new CRMGlobalCountryNotConfiguredException('No Country_Config__mdt found for this org.');
            }
        }
        return country;
    }

    /**
     * @description Custom exception class for country configuration errors.
     */
    public class CRMGlobalCountryNotConfiguredException extends Exception {}
}