public with sharing class CRMPHKLCreateRequestCaseController {
    // 新增方法获取选项列表
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getPicklistValues(List<String> fieldNames) {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        
        for(String fieldName : fieldNames) {
            List<String> parts = fieldName.split('\\.');
            String objectName = parts[0];
            String fieldApiName = parts[1];
            
            List<Map<String, String>> options = new List<Map<String, String>>();
            for(Schema.PicklistEntry entry : Schema.getGlobalDescribe()
                .get(objectName)
                .getDescribe()
                .fields.getMap()
                .get(fieldApiName)
                .getDescribe()
                .getPicklistValues()) {
                    
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
            
            result.put(fieldName.replace('.', '_'), options);
        }
        
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<User> searchUsers(String searchTerm) {
        if (String.isBlank(searchTerm)) {
            return new List<User>();
        }
        searchTerm = '%' + searchTerm + '%';
        return [SELECT Id, Name, Email FROM User WHERE Name LIKE :searchTerm AND IsActive = true LIMIT 10];
    }

    @AuraEnabled(cacheable=true)
    public static String getDueDatetime(String requestType, String caseStatus) {
        if (String.isBlank(requestType) || String.isBlank(caseStatus)) {
            return '';
        }
        Datetime now = Datetime.now();
        Datetime dueDateTime = CRMGlobalCaseTATService.getTATDueDate(requestType, caseStatus, now);
        return dueDateTime != null ? dueDateTime.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'') : '';
    }
    
    /**
     * 创建Request记录类型的Case记录
     * @param requestData 请求数据包装类
     * @return 创建结果包装类
     */
    @AuraEnabled(cacheable=false)
    public static CreateResult createRequestCase(String requestDataJsonStr) {
        try {
            if (!Schema.SObjectType.Case.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create cases');
            }

            RequestDataWrapper requestData = new RequestDataWrapper();

            System.debug('requestDataJsonStr: ' + requestDataJsonStr);
            // 验证输入参数
            if (String.isBlank(requestDataJsonStr)) {
                throw new AuraHandledException('Request data cannot be empty');
            }else {
                requestData = (RequestDataWrapper)JSON.deserialize(requestDataJsonStr, RequestDataWrapper.class);
            }
            
            // 验证必填字段
            // if (String.isBlank(requestData.requestSummary)) {
            //     throw new AuraHandledException('Request Summary is required');
            // }
            
            // 创建新的Case记录
            Case newCase = new Case();
            
            // 设置记录类型为Request
            Id requestRecordTypeId = getRequestRecordTypeId();
            if (requestRecordTypeId != null) {
                newCase.RecordTypeId = requestRecordTypeId;
            }
            
            // 设置Case字段
            if (String.isNotBlank(requestData.status)) {
                newCase.Status = requestData.status;
            }else{
                newCase.Status = 'New';
            }
            
            newCase.Priority = 'Medium';
            
            // 设置自定义字段（根据实际字段API名称调整）
            if (String.isNotBlank(requestData.requestType)) {
                newCase.CRM_Global_RequestCaseType__c = requestData.requestType;
                if (requestData.requestType == 'Locate Payment') {
                    if (String.isNotBlank(requestData.policyNumber)) {
                        newCase.CRM_Global_PolicyNumber__c = requestData.policyNumber;
                    }
                    if (String.isNotBlank(requestData.nameOfAssured)) {
                        newCase.CRM_Global_NameofAssured__c = requestData.nameOfAssured;
                    }
                    if (String.isNotBlank(requestData.refundChannel)) {
                        newCase.CRM_Global_RefundChannel__c = requestData.refundChannel;
                    }
                    if (String.isNotBlank(requestData.amount)) {
                        newCase.CRM_Global_Amount__c = Decimal.valueOf(requestData.amount);
                    }
                    if (String.isNotBlank(requestData.refundDate)) {
                        newCase.CRM_Global_RefundDate__c = Date.valueOf(requestData.refundDate);
                    }
                }
            }

            if (String.isNotBlank(requestData.requestEnquiryCase)) {
                newCase.ParentId = requestData.requestEnquiryCase;
            }

            if (String.isNotBlank(requestData.relatedRequest)) {
                newCase.CRM_Glabal_RelatedRequest__c = requestData.relatedRequest;
            }
            
            if (String.isNotBlank(requestData.copyTo)) {
                newCase.CRM_Global_CopyTo__c = requestData.copyTo;
            }

            if (String.isNotBlank(requestData.recipient1)) {
                newCase.CRM_Global_Recipient_1__c = requestData.recipient1;
                newCase.OwnerId = requestData.recipient1;
                newCase.Status = '1st Round Processing';
            }

            if (String.isNotBlank(requestData.recipient1Department)) {
                newCase.CRM_Global_AssignedDepartment_1__c = requestData.recipient1Department;
            }

            if (String.isNotBlank(requestData.recipient1External)) {
                newCase.CRM_Global_Recipient_1_External__c = requestData.recipient1External;
            }

            if (String.isNotBlank(requestData.dueDate1)) {
                newCase.CRM_Global_TAT_DueDate_1__c = (DateTime)JSON.deserialize(requestData.dueDate1, DateTime.class);
            }

            if (String.isNotBlank(requestData.requestSummary1)) {
                newCase.CRM_Global_RequestSummary_1__c = requestData.requestSummary1;
            }

            
            newCase.CRM_Global_AutoProceed__c = requestData.autoProceed;
            
            if (String.isNotBlank(requestData.recipient2)) {
                newCase.CRM_Global_Recipient_2__c = requestData.recipient2;
            }

            if (String.isNotBlank(requestData.recipient2Department)) {
                newCase.CRM_Global_AssignedDepartment_2__c = requestData.recipient2Department;
            }

            if (String.isNotBlank(requestData.recipient2External)) {
                newCase.CRM_Global_Recipient_2_External__c = requestData.recipient2External;
            }

            if (String.isNotBlank(requestData.dueDate2)) {
                newCase.CRM_Global_TAT_DueDate_2__c = (DateTime)JSON.deserialize(requestData.dueDate2, DateTime.class);
            }

            if (String.isNotBlank(requestData.requestSummary2)) {
                newCase.CRM_Global_RequestSummary_2__c = requestData.requestSummary2;
            }
            
            // 插入Case记录
            insert newCase;
            
            // 返回成功结果
            return new CreateResult(true, 'Request case created successfully', newCase.Id, newCase.CaseNumber);
            
        } catch (Exception e) {
            System.debug('Error creating request case: ' + e.getMessage() + ' ' + e.getStackTraceString() + ' ' + e.getLineNumber());
            // 返回失败结果
            return new CreateResult(false, 'Failed to create request case: ' + e.getMessage() + ' ' + e.getStackTraceString() + ' ' + e.getLineNumber(), null, null);
        }
    }
    
    /**
     * 获取Request记录类型ID
     * @return Request记录类型ID
     */
    private static Id getRequestRecordTypeId() {
        try {
            RecordType requestRecordType = [
                SELECT Id 
                FROM RecordType 
                WHERE SObjectType = 'Case' 
                AND Name = 'Request' 
                AND IsActive = true 
                LIMIT 1
            ];
            return requestRecordType.Id;
        } catch (QueryException e) {
            System.debug('Request record type not found: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * 根据Case Number查找Case记录
     * @param caseNumber Case编号
     * @return Case记录
     */
    private static Case findCaseByNumber(String caseNumber) {
        try {
            Case foundCase = [
                SELECT Id, CaseNumber 
                FROM Case 
                WHERE CaseNumber = :caseNumber 
                LIMIT 1
            ];
            return foundCase;
        } catch (QueryException e) {
            System.debug('Case not found with number: ' + caseNumber);
            return null;
        }
    }
    
    /**
     * 创建结果包装类
     */
    public class CreateResult {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String message;
        @AuraEnabled public String caseId;
        @AuraEnabled public String caseNumber;
        
        public CreateResult(Boolean isSuccess, String message, String caseId, String caseNumber) {
            this.isSuccess = isSuccess;
            this.message = message;
            this.caseId = caseId;
            this.caseNumber = caseNumber;
        }
    }
    
    /**
     * 请求数据包装类
     */
    public class RequestDataWrapper {
        @AuraEnabled public String requestType;
        @AuraEnabled public String requestEnquiryCase;
        @AuraEnabled public String relatedRequest;
        @AuraEnabled public String status;
        @AuraEnabled public String copyTo;
        @AuraEnabled public String recipient1;
        @AuraEnabled public String recipient1Department;
        @AuraEnabled public String recipient1External;
        @AuraEnabled public String requestSummary1;
        @AuraEnabled public String dueDate1;
        @AuraEnabled public Boolean autoProceed;
        @AuraEnabled public String recipient2;
        @AuraEnabled public String recipient2Department;
        @AuraEnabled public String recipient2External;
        @AuraEnabled public String requestSummary2;
        @AuraEnabled public String dueDate2;
        @AuraEnabled public String policyNumber;
        @AuraEnabled public String nameOfAssured;
        @AuraEnabled public String refundChannel;
        @AuraEnabled public String refundDate;
        @AuraEnabled public String amount;
    }
}