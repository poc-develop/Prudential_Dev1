/**
 * @description       : Invocable methods for Flow to work with BusinessHours
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-27
 * @last modified by  : hank
**/
public without sharing class CRMPHKLBusinessHoursFlowService {
     /**
     * 计算从当前时间起N个工作日后的日期时间
     * 供 Flow 调用
     */
    @InvocableMethod(
        label='Calculate Business Days' 
        description='Calculate date time after specified business days'
        category='Business Hours'
    )
    public static List<BusinessHoursResult> calculateBusinessDays(List<BusinessHoursRequest> requests) {
        List<BusinessHoursResult> results = new List<BusinessHoursResult>();
        
        // 获取默认 BusinessHours
        BusinessHours bh = getDefaultBusinessHours();
        
        for (BusinessHoursRequest request : requests) {
            BusinessHoursResult result = new BusinessHoursResult();
            DateTime startDateTime = request.startDateTime != null ? request.startDateTime : System.now();
            Integer days = request.businessDays != null ? request.businessDays : 5;
            if (bh != null) {
                // 计算工作日（假设每天8小时工作制）
                Long milliseconds = Integer.valueOf(days) * 8 * 60 * 60 * 1000;
                result.resultDateTime = BusinessHours.add(bh.Id, startDateTime, milliseconds);
                result.isSuccess = true;
            } else {
                // 如果没有配置 BusinessHours，使用自然日
                result.resultDateTime = startDateTime.addDays(days);
                result.isSuccess = false;
                result.errorMessage = 'No default BusinessHours found, using calendar days';
            }
            results.add(result);
        }
        
        return results;
    }
    
    /**
     * 获取默认 BusinessHours
     */
    private static BusinessHours getDefaultBusinessHours() {
        List<BusinessHours> bhList = [
            SELECT Id, Name 
            FROM BusinessHours 
            WHERE IsDefault = TRUE 
            LIMIT 1
        ];
        return bhList.isEmpty() ? null : bhList[0];
    }
    
    // ============ 内部类：请求和响应包装器 ============
    
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