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

    public static String searchQueue(String searchTerm) {
        if (String.isBlank(searchTerm)) {
            return '';
        }
        Group queue = [SELECT Id FROM Group where DeveloperName =: searchTerm LIMIT 1];
        if (queue != null) {
            return queue.Id;
        } else {
            return '';
        }
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

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getCurrentUser() {
        Map<String, String> currentUserInfo = new Map<String, String>();
        User currentUser = [SELECT Id, Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        currentUserInfo.put('userId', currentUser.Id);
        currentUserInfo.put('userName', currentUser.Name);
        return currentUserInfo;
    }

    /**
     * 根据RequestType查询Custom Metadata获取Recipient信息
     * @param requestType Request类型
     * @return 包含recipient1, recipient1QueueName, recipient2, recipient2QueueName的Map
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getRecipientsByRequestType(String requestType) {
        Map<String, String> result = new Map<String, String>();
        
        if (String.isBlank(requestType)) {
            return result;
        }
        
        try {
            List<CRM_Global_CaseTATSetting__mdt> settings = [
                SELECT CRM_Global_Recipient_1_Queue_Label__c,
                       CRM_Global_Recipient_1_Queue_Name__c,
                       CRM_Global_Recipient_2_Queue_Label__c,
                       CRM_Global_Recipient_2_Queue_Name__c
                FROM CRM_Global_CaseTATSetting__mdt
                WHERE CRM_Global_RequestType__c = :requestType
                LIMIT 1
            ];
            
            if (!settings.isEmpty()) {
                CRM_Global_CaseTATSetting__mdt setting = settings[0];
                if (String.isNotBlank(setting.CRM_Global_Recipient_1_Queue_Label__c)) {
                    result.put('recipient1', setting.CRM_Global_Recipient_1_Queue_Label__c);
                }
                if (String.isNotBlank(setting.CRM_Global_Recipient_1_Queue_Name__c)) {
                    result.put('recipient1QueueName', setting.CRM_Global_Recipient_1_Queue_Name__c);
                }
                if (String.isNotBlank(setting.CRM_Global_Recipient_2_Queue_Label__c)) {
                    result.put('recipient2', setting.CRM_Global_Recipient_2_Queue_Label__c);
                }
                if (String.isNotBlank(setting.CRM_Global_Recipient_2_Queue_Name__c)) {
                    result.put('recipient2QueueName', setting.CRM_Global_Recipient_2_Queue_Name__c);
                }
            }
        } catch (Exception e) {
            System.debug('Error querying Custom Metadata: ' + e.getMessage());
        }
        
        return result;
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
                // Locate Payment / Payout Status
                if (requestData.requestType == 'Locate Payment' || requestData.requestType == 'Payout Status') {
                    if (String.isNotBlank(requestData.policyNumber)) {
                        newCase.CRM_Global_PolicyNumber__c = requestData.policyNumber;
                    }
                    if (String.isNotBlank(requestData.nameOfAssured)) {
                        newCase.CRM_Global_NameofAssured__c = requestData.nameOfAssured;
                    }
                    if (String.isNotBlank(requestData.requestSummary)) {
                        newCase.CRM_Global_RequestSummary__c = requestData.requestSummary;
                    }
                    if (String.isNotBlank(requestData.refundChannel)) {
                        newCase.CRM_Global_RefundChannel__c = requestData.refundChannel;
                    }
                    if (String.isNotBlank(requestData.channelOthers)) {
                        newCase.CRM_Global_ChannelOthers__c = requestData.channelOthers;
                    }
                    if (String.isNotBlank(requestData.amount)) {
                        newCase.CRM_Global_Amount__c = Decimal.valueOf(requestData.amount);
                    }
                    if (String.isNotBlank(requestData.refundDate)) {
                        newCase.CRM_Global_RefundDate__c = Date.valueOf(requestData.refundDate);
                    }
                }

                // Issue Letter / Issue Email fields mapping
                if (requestData.requestType == 'Issue Letter' || requestData.requestType == 'Issue Email') {
                    if (String.isNotBlank(requestData.letterType)) {
                        newCase.CRM_Global_LetterType__c = requestData.letterType;
                    }
                    if (String.isNotBlank(requestData.letterLanguage)) {
                        newCase.CRM_Global_LetterLanguage__c = requestData.letterLanguage;
                    }
                    if (String.isNotBlank(requestData.undersignedName)) {
                        newCase.CRM_Global_UndersignedName__c = requestData.undersignedName;
                    }
                    if (String.isNotBlank(requestData.undersignedTitle)) {
                        newCase.CRM_Global_UndersignedTitle__c = requestData.undersignedTitle;
                    }
                    if (String.isNotBlank(requestData.deliveryMethod)) {
                        newCase.CRM_Global_DeliveryMethod__c = requestData.deliveryMethod;
                    }
                    if (String.isNotBlank(requestData.reviewedBy)) {
                        newCase.CRM_Global_ReviewedBy__c = requestData.reviewedBy;
                    }
                    if (String.isNotBlank(requestData.specificDeadline)) {
                        newCase.CRM_Global_SpecificDeadline__c = Date.valueOf(requestData.specificDeadline);
                    }
                    if (String.isNotBlank(requestData.caseBackground)) {
                        newCase.CRM_Global_CaseBackground__c = requestData.caseBackground;
                    }
                    if (String.isNotBlank(requestData.investigationResult)) {
                        newCase.CRM_Global_InvestigationResult__c = requestData.investigationResult;
                    }
                    if (String.isNotBlank(requestData.pointToBeIncludedInLetters)) {
                        newCase.CRM_Global_PointToBeIncludedInTheLetters__c = requestData.pointToBeIncludedInLetters;
                    }
                    if (String.isNotBlank(requestData.pointToBeIncludedInEmail)) {
                        newCase.CRM_Global_PointToBeIncludedInTheEmail__c = requestData.pointToBeIncludedInEmail;
                    }
                    if (String.isNotBlank(requestData.emailAddress)) {
                        newCase.CRM_Global_EmailAddress__c = requestData.emailAddress;
                    }
                }

                // ACT Quotation / ACT Quotation & Client Letter
                if (requestData.requestType == 'ACT Quotation' || requestData.requestType == 'ACT Quotation & Client Letter') {
                    if (String.isNotBlank(requestData.followUpRequestNewRequest)) {
                        newCase.CRM_Global_FollowUpRequestNewRequest__c = requestData.followUpRequestNewRequest;
                    }
                    if (String.isNotBlank(requestData.requestSummary)) {
                        newCase.CRM_Global_RequestSummary__c = requestData.requestSummary;
                    }
                    if (String.isNotBlank(requestData.effectiveDate)) {
                        newCase.CRM_Global_EffectiveDate__c = Date.valueOf(requestData.effectiveDate);
                    }
                    if (String.isNotBlank(requestData.policyNumber)) {
                        newCase.CRM_Global_PolicyNumber__c = requestData.policyNumber;
                    }
                    if (String.isNotBlank(requestData.productPlan)) {
                        newCase.CRM_Global_ProductPlan__c = requestData.productPlan;
                    }
                }

                // Stop Cheque
                if (requestData.requestType == 'Stop and Reissue Cheque') {
                    if (String.isNotBlank(requestData.policyNumber)) {
                        newCase.CRM_Global_PolicyNumber__c = requestData.policyNumber;
                    }
                    if (String.isNotBlank(requestData.chequeNumber)) {
                        newCase.CRM_Global_ChequeNumber__c =  requestData.chequeNumber;
                    }
                }

                // PA Request
                if (requestData.requestType == 'PA Request') {
                    if (String.isNotBlank(requestData.policyNumber)) {
                        newCase.CRM_Global_PolicyNumber__c = requestData.policyNumber;
                    }
                    if (String.isNotBlank(requestData.policyOwner)) {
                        newCase.CRM_Global_PolicyOwnerText__c = requestData.policyOwner;
                    }
                    if (String.isNotBlank(requestData.requestSummary)) {
                        newCase.CRM_Global_RequestSummary__c = requestData.requestSummary;
                    }
                    if (String.isNotBlank(requestData.caseSummaryAllegations)) {
                        newCase.CRM_Global_CaseSummaryAllegations__c = requestData.caseSummaryAllegations;
                    }
                    if (String.isNotBlank(requestData.CDComplaintRefNo)) {
                        newCase.CRM_Global_CDComplaintRefNo__c = requestData.CDComplaintRefNo;
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
                newCase.Status = '1st Round Processing';
                newCase.CRM_Global_Case_Recipient_1_Text__c = requestData.recipient1;
                if (requestData.requestType == 'Follow Up' || requestData.requestType == 'Chaser' || requestData.requestType == 'Request Approval'){
                    newCase.CRM_Global_Case_Recipient_1_Id__c = requestData.recipient1QueueName;
                }else {
                    newCase.CRM_Global_Case_Recipient_1_Id__c = searchQueue(requestData.recipient1QueueName);
                }
                newCase.OwnerId = newCase.CRM_Global_Case_Recipient_1_Id__c;
            }

            if (String.isNotBlank(requestData.recipient1Department)) {
                newCase.CRM_Global_AssignedDepartment_1__c = requestData.recipient1Department;
            }

            if (String.isNotBlank(requestData.recipient1External)) {
                newCase.CRM_Global_Recipient_1_External__c = requestData.recipient1External;
            }

            if (String.isNotBlank(requestData.dueDate1)) {
                Datetime tatDueDate1 = parseIsoDatetime(requestData.dueDate1, 'Due Date 1');
                if (tatDueDate1 != null) {
                    // newCase.CRM_Global_TAT_DueDate_1__c = tatDueDate1;
                    // System.debug('duedate1====>' + newCase.CRM_Global_TAT_DueDate_1__c);
                }
            }

            if (String.isNotBlank(requestData.requestSummary1)) {
                newCase.CRM_Global_RequestSummary_1__c = requestData.requestSummary1;
            }

            
            newCase.CRM_Global_AutoProceed__c = requestData.autoProceed;
            
            if (String.isNotBlank(requestData.recipient2)) {
                newCase.CRM_Global_Case_Recipient_2_Text__c = requestData.recipient2;
                if (requestData.requestType == 'Request Coupons'){
                    newCase.CRM_Global_Case_Recipient_2_Id__c = requestData.recipient2QueueName;
                }else {
                    newCase.CRM_Global_Case_Recipient_2_Id__c = searchQueue(requestData.recipient2QueueName);
                }
            }

            if (String.isNotBlank(requestData.recipient2Department)) {
                newCase.CRM_Global_AssignedDepartment_2__c = requestData.recipient2Department;
            }

            if (String.isNotBlank(requestData.recipient2External)) {
                newCase.CRM_Global_Recipient_2_External__c = requestData.recipient2External;
            }

            if (String.isNotBlank(requestData.dueDate2)) {
                Datetime tatDueDate2 = parseIsoDatetime(requestData.dueDate2, 'Due Date 2');
                if (tatDueDate2 != null) {
                    // newCase.CRM_Global_TAT_DueDate_2__c = tatDueDate2;
                }
            }

            if (String.isNotBlank(requestData.requestSummary2)) {
                newCase.CRM_Global_RequestSummary_2__c = requestData.requestSummary2;
            }
            
            if (requestData.saveAsDraft) {
                newCase.Status = 'Draft';
            }

            Entitlement entitlement = CRMGlobalCaseEntitlementService.getRequestCaseEntitlement();
            if (entitlement != null) {
                newCase.EntitlementId = entitlement.Id;
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
     * Safely parse ISO 8601 datetime strings coming from the UI.
     */
    private static Datetime parseIsoDatetime(String rawValue, String fieldLabel) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        String valueToParse = rawValue.trim();
        if (valueToParse.startsWith('"') && valueToParse.endsWith('"') && valueToParse.length() >= 2) {
            valueToParse = valueToParse.substring(1, valueToParse.length() - 1);
        }
        try {
            String jsonValue = JSON.serialize(valueToParse);
            return (Datetime)JSON.deserialize(jsonValue, Datetime.class);
        } catch (Exception ex) {
            throw new AuraHandledException(fieldLabel + ' is invalid: ' + ex.getMessage());
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
        @AuraEnabled public String recipient1QueueName;
        @AuraEnabled public String recipient1Department;
        @AuraEnabled public String recipient1External;
        @AuraEnabled public String requestSummary1;
        @AuraEnabled public String dueDate1;
        @AuraEnabled public Boolean autoProceed;
        @AuraEnabled public Boolean saveAsDraft;
        @AuraEnabled public String recipient2;
        @AuraEnabled public String recipient2QueueName;
        @AuraEnabled public String recipient2Department;
        @AuraEnabled public String recipient2External;
        @AuraEnabled public String requestSummary2;
        @AuraEnabled public String dueDate2;
        @AuraEnabled public String policyNumber;
        @AuraEnabled public String chequeNumber;
        @AuraEnabled public String nameOfAssured;
        @AuraEnabled public String requestSummary;
        @AuraEnabled public String refundChannel;
        @AuraEnabled public String channelOthers;
        @AuraEnabled public String refundDate;
        @AuraEnabled public String amount;
        // Issue Letter / Issue Email fields
        @AuraEnabled public String letterType;
        @AuraEnabled public String letterLanguage;
        @AuraEnabled public String undersignedName;
        @AuraEnabled public String undersignedTitle;
        @AuraEnabled public String deliveryMethod;
        @AuraEnabled public String reviewedBy;
        @AuraEnabled public String specificDeadline;
        @AuraEnabled public String caseBackground;
        @AuraEnabled public String investigationResult;
        @AuraEnabled public String pointToBeIncludedInLetters;
        @AuraEnabled public String pointToBeIncludedInEmail;
        @AuraEnabled public String emailAddress;
        // Request to ACT fields
        @AuraEnabled public String followUpRequestNewRequest;
        @AuraEnabled public String effectiveDate;
        @AuraEnabled public String productPlan;
        @AuraEnabled public String policyOwner;
        @AuraEnabled public String caseSummaryAllegations;
        @AuraEnabled public String CDComplaintRefNo;
    }
}