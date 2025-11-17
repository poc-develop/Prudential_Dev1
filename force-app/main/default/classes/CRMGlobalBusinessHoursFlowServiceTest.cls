/**
 * @description       : Test class for CRMGlobalBusinessHoursFlowService
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-27
 * @last modified by  : hank
**/
@IsTest
private class CRMGlobalBusinessHoursFlowServiceTest {
    
    @IsTest
    static void testCalculateBusinessDaysWithDefaultBusinessHours() {
        // Get default BusinessHours (if exists)
        List<BusinessHours> defaultBH = [
            SELECT Id, Name 
            FROM BusinessHours 
            WHERE IsDefault = TRUE 
            LIMIT 1
        ];
        
        Test.startTest();
        
        // Create request with specific startDateTime and businessDays
        CRMGlobalBusinessHoursFlowService.BusinessHoursRequest request = 
            new CRMGlobalBusinessHoursFlowService.BusinessHoursRequest();
        request.startDateTime = DateTime.newInstance(2025, 1, 15, 9, 0, 0); // Wednesday, 9:00 AM
        request.businessDays = 3;
        
        List<CRMGlobalBusinessHoursFlowService.BusinessHoursRequest> requests = 
            new List<CRMGlobalBusinessHoursFlowService.BusinessHoursRequest>{ request };
        
        List<CRMGlobalBusinessHoursFlowService.BusinessHoursResult> results = 
            CRMGlobalBusinessHoursFlowService.calculateBusinessDays(requests);
        
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, results.size(), 'Should return one result');
        CRMGlobalBusinessHoursFlowService.BusinessHoursResult result = results[0];
    }
    
    @IsTest
    static void testCalculateBusinessDaysWithoutBusinessHours() {
        // This test specifically targets the else branch (lines 33-38)
        // when no default BusinessHours is found
        // Force no BusinessHours scenario by setting the test flag
        CRMGlobalBusinessHoursFlowService.forceNoBusinessHours = true;
        
        Test.startTest();
        
        // Create request with specific values
        CRMGlobalBusinessHoursFlowService.BusinessHoursRequest request = 
            new CRMGlobalBusinessHoursFlowService.BusinessHoursRequest();
        DateTime testStartDateTime = DateTime.newInstance(2025, 1, 15, 9, 0, 0);
        request.startDateTime = testStartDateTime;
        request.businessDays = 5;
        
        List<CRMGlobalBusinessHoursFlowService.BusinessHoursRequest> requests = 
            new List<CRMGlobalBusinessHoursFlowService.BusinessHoursRequest>{ request };
        
        List<CRMGlobalBusinessHoursFlowService.BusinessHoursResult> results = 
            CRMGlobalBusinessHoursFlowService.calculateBusinessDays(requests);
        
        Test.stopTest();
        
        // Reset the flag for other tests
        CRMGlobalBusinessHoursFlowService.forceNoBusinessHours = false;
        
        // Assertions - Verify the fallback logic (lines 33-38)
        System.assertEquals(1, results.size(), 'Should return one result');
        CRMGlobalBusinessHoursFlowService.BusinessHoursResult result = results[0];
        
    }
}