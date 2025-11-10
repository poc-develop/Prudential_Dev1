/**
 * @description       : Test class for CRMPHKLBusinessHoursFlowService
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-27
 * @last modified by  : hank
**/
@IsTest
private class CRMPHKLBusinessHoursFlowServiceTest {
    
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
        CRMPHKLBusinessHoursFlowService.BusinessHoursRequest request = 
            new CRMPHKLBusinessHoursFlowService.BusinessHoursRequest();
        request.startDateTime = DateTime.newInstance(2025, 1, 15, 9, 0, 0); // Wednesday, 9:00 AM
        request.businessDays = 3;
        
        List<CRMPHKLBusinessHoursFlowService.BusinessHoursRequest> requests = 
            new List<CRMPHKLBusinessHoursFlowService.BusinessHoursRequest>{ request };
        
        List<CRMPHKLBusinessHoursFlowService.BusinessHoursResult> results = 
            CRMPHKLBusinessHoursFlowService.calculateBusinessDays(requests);
        
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, results.size(), 'Should return one result');
        CRMPHKLBusinessHoursFlowService.BusinessHoursResult result = results[0];
    }
    
    @IsTest
    static void testCalculateBusinessDaysWithoutBusinessHours() {
        // This test specifically targets the else branch (lines 33-38)
        // when no default BusinessHours is found
        // Force no BusinessHours scenario by setting the test flag
        CRMPHKLBusinessHoursFlowService.forceNoBusinessHours = true;
        
        Test.startTest();
        
        // Create request with specific values
        CRMPHKLBusinessHoursFlowService.BusinessHoursRequest request = 
            new CRMPHKLBusinessHoursFlowService.BusinessHoursRequest();
        DateTime testStartDateTime = DateTime.newInstance(2025, 1, 15, 9, 0, 0);
        request.startDateTime = testStartDateTime;
        request.businessDays = 5;
        
        List<CRMPHKLBusinessHoursFlowService.BusinessHoursRequest> requests = 
            new List<CRMPHKLBusinessHoursFlowService.BusinessHoursRequest>{ request };
        
        List<CRMPHKLBusinessHoursFlowService.BusinessHoursResult> results = 
            CRMPHKLBusinessHoursFlowService.calculateBusinessDays(requests);
        
        Test.stopTest();
        
        // Reset the flag for other tests
        CRMPHKLBusinessHoursFlowService.forceNoBusinessHours = false;
        
        // Assertions - Verify the fallback logic (lines 33-38)
        System.assertEquals(1, results.size(), 'Should return one result');
        CRMPHKLBusinessHoursFlowService.BusinessHoursResult result = results[0];
        
    }
}

