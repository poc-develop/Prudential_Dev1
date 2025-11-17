/**
 * @description       : Invocable methods for Flow to work with BusinessHours
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-27
 * @last modified by  : hank
**/
public without sharing class CRMGlobalBusinessHoursFlowService {
    
    // Test visible variable to allow test classes to override BusinessHours lookup
    // Set to true in tests to simulate no BusinessHours scenario
    @TestVisible
    private static Boolean forceNoBusinessHours = false;
    
    /**
     * Calculate date time after N business days from current time
     * Invocable method for Flow
     */
    @InvocableMethod(
        label='Calculate Business Days' 
        description='Calculate date time after specified business days'
        category='Business Hours'
    )
    public static List<BusinessHoursResult> calculateBusinessDays(List<BusinessHoursRequest> requests) {
        List<BusinessHoursResult> results = new List<BusinessHoursResult>();
        
        // Get default BusinessHours
        BusinessHours bh = getDefaultBusinessHours();
        
        for (BusinessHoursRequest request : requests) {
            BusinessHoursResult result = new BusinessHoursResult();
            DateTime startDateTime = request.startDateTime != null ? request.startDateTime : System.now();
            Integer days = request.businessDays != null ? request.businessDays : 5;
            if (bh != null) {
                // Calculate business days (assuming 8 hours per day)
                Long milliseconds = Integer.valueOf(days) * 8 * 60 * 60 * 1000;
                result.resultDateTime = BusinessHours.add(bh.Id, startDateTime, milliseconds);
                result.isSuccess = true;
            } else {
                // If BusinessHours is not configured, use calendar days
                result.resultDateTime = startDateTime.addDays(days);
                result.isSuccess = false;
                result.errorMessage = 'No default BusinessHours found, using calendar days';
            }
            results.add(result);
        }
        
        return results;
    }
    
    /**
     * Get default BusinessHours
     */
    @TestVisible
    private static BusinessHours getDefaultBusinessHours() {
        // Allow test classes to force no BusinessHours scenario
        if (Test.isRunningTest() && forceNoBusinessHours) {
            return null;
        }
        
        List<BusinessHours> bhList = [
            SELECT Id, Name 
            FROM BusinessHours 
            WHERE IsDefault = TRUE 
            LIMIT 1
        ];
        return bhList.isEmpty() ? null : bhList[0];
    }
    
    // ============ Inner Classes: Request and Response Wrappers ============
    
    public class BusinessHoursRequest {
        @InvocableVariable(label='Start Date Time' description='Starting date time (default: now)' required=false)
        public DateTime startDateTime;
        
        @InvocableVariable(label='Business Days' description='Number of business days to add (default: 5)' required=false)
        public Integer businessDays;
    }
    
    public class BusinessHoursResult {
        @InvocableVariable(label='Result Date Time' description='Calculated date time')
        public DateTime resultDateTime;
        
        @InvocableVariable(label='Is Success' description='Whether calculation was successful')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Error Message' description='Error message if failed')
        public String errorMessage;
    }
}