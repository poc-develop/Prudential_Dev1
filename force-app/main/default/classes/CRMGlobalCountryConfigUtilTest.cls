/**
 * @description       : Test class for CRMGlobalCountryConfigUtil
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-11
 * @last modified by  : Franco
**/
@IsTest
private class CRMGlobalCountryConfigUtilTest {

    @IsTest
    static void testGetCountry() {
        Test.startTest();
        try {
            // Since the org already has one CRM_Global_CountryConfig__mdt record configured, we expect it to be returned
            String firstCall = CRMGlobalCountryConfigUtil.getCountry();
            String secondCall = CRMGlobalCountryConfigUtil.getCountry();

            System.assertEquals(firstCall, secondCall, 'Country value should be cached and consistent');
        } catch(Exception e) {
            // Handle the exception for no country configured
            System.assertEquals(e.getMessage(), 'No Country_Config__mdt found for this org.', 'Exception message should be consistent');
        }
        Test.stopTest();
    }
}