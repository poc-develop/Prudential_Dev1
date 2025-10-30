/**
 * @description       : Batch job to sync Enquiry data from external API
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-28
 * @last modified by  : hank
**/
public class CRMPHKLEnquirySyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
    // 统计信息
    public Integer processedCount = 0;
    public Integer successCount = 0;
    public Integer failureCount = 0;
    public List<String> errorMessages = new List<String>();
    
    // API配置名称（在 Custom Metadata 中配置）
    private static final String API_CONFIG_NAME = 'Enquiry_Sync_API';
    
    /**
     * Start: 返回空查询（我们不需要查询记录，只需要触发API调用）
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // 返回一个空的查询，只是为了启动批处理
        // 实际处理在 execute 中完成
        return Database.getQueryLocator([SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1]);
    }
    
    /**
     * Execute: 调用API并处理返回数据
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        try {
            // 1. 调用API获取数据
            CRMPHKLEnquiryAPIResponse apiResponse = callEnquiryAPI();
            
            if (apiResponse == null || apiResponse.ReturnCode != '000000') {
                String errorMsg = 'API call failed: ' + 
                    (apiResponse != null ? apiResponse.ReturnCode : 'No response');
                errorMessages.add(errorMsg);
                CRMGlobalLogManager.addApexErrorLog(errorMsg, null);
                return;
            }
            
            // 2. 处理返回的数据
            if (apiResponse.Results != null && !apiResponse.Results.isEmpty()) {
                processEnquiryData(apiResponse.Results);
            }
            
        } catch (Exception e) {
            failureCount++;
            String errorMsg = 'Batch execute error: ' + e.getMessage();
            errorMessages.add(errorMsg);
            System.debug(LoggingLevel.ERROR, errorMsg + '\n' + e.getStackTraceString());
            CRMGlobalLogManager.addApexErrorLog(errorMsg, e);
        }
    }
    
    /**
     * Finish: 完成后的处理和日志记录
     */
    public void finish(Database.BatchableContext bc) {
        String summary = '=== Enquiry Sync Batch Summary ===\n';
        summary += 'Processed: ' + processedCount + ' records\n';
        summary += 'Success: ' + successCount + ' records\n';
        summary += 'Failed: ' + failureCount + ' records\n';
        
        if (!errorMessages.isEmpty()) {
            summary += '\nErrors:\n';
            summary += String.join(errorMessages, '\n');
            CRMGlobalLogManager.addApexWarnLog(summary);
        } else {
            CRMGlobalLogManager.addApexInfoLog(summary);
        }
        
        CRMGlobalLogManager.saveAndFlushLogs();
        
        System.debug(summary);
    }
    
    /**
     * 调用外部API获取Enquiry数据
     */
    private CRMPHKLEnquiryAPIResponse callEnquiryAPI() {
        try {
            // 使用现有的 DataIntegration 框架
            CRM_Global_DataIntegration_Config__mdt config = 
                CRMGlobalDataIntegrationController.getIntegrationConfig(API_CONFIG_NAME);
            
            if (config == null) {
                throw new CRMGlobalDataIntegrationException(
                    'API config not found: ' + API_CONFIG_NAME
                );
            }
            
            // 创建配置包装器（不需要 recordId）
            CRMGlobalDataIntegrationConfigWrapper configWrapper = 
                new CRMGlobalDataIntegrationConfigWrapper(config, null);
            
            // 调用API
            HttpResponse response = CRMGlobalDataIntegrationAPIService.callExternalApi(configWrapper);
            
            // 解析响应
            if (response != null && response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                String responseBody = response.getBody();
                return (CRMPHKLEnquiryAPIResponse) JSON.deserialize(
                    responseBody, 
                    CRMPHKLEnquiryAPIResponse.class
                );
            }
            
            return null;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'API call error: ' + e.getMessage());
            CRMGlobalLogManager.addApexErrorLog('Enquiry API call failed', e);
            throw e;
        }
    }
    
    /**
     * 处理Enquiry数据 - 创建或更新记录
     */
    private void processEnquiryData(List<CRMPHKLEnquiryData> enquiryList) {
        // 收集所有 enquiryId
        Set<String> enquiryIds = new Set<String>();
        for (CRMPHKLEnquiryData enquiry : enquiryList) {
            if (String.isNotBlank(enquiry.enquiryId)) {
                enquiryIds.add(enquiry.enquiryId);
            }
        }
        
        // 查询已存在的记录（假设你有一个 Enquiry__c 对象）
        Map<String, Enquiry__c> existingEnquiriesMap = new Map<String, Enquiry__c>();
        for (Enquiry__c enq : [
            SELECT Id, Enquiry_Id__c, Enquiry_Status__c, Last_Updated_Date__c
            FROM Enquiry__c
            WHERE Enquiry_Id__c IN :enquiryIds
        ]) {
            existingEnquiriesMap.put(enq.Enquiry_Id__c, enq);
        }
        
        // 准备要插入或更新的记录
        List<Enquiry__c> recordsToUpsert = new List<Enquiry__c>();
        
        for (CRMPHKLEnquiryData enquiry : enquiryList) {
            try {
                processedCount++;
                
                Enquiry__c record;
                if (existingEnquiriesMap.containsKey(enquiry.enquiryId)) {
                    // 更新现有记录
                    record = existingEnquiriesMap.get(enquiry.enquiryId);
                } else {
                    // 创建新记录
                    record = new Enquiry__c();
                    record.Enquiry_Id__c = enquiry.enquiryId;
                }
                
                // 映射字段
                mapEnquiryFields(record, enquiry);
                
                recordsToUpsert.add(record);
                
            } catch (Exception e) {
                failureCount++;
                String errorMsg = 'Error processing enquiry ' + enquiry.enquiryId + ': ' + e.getMessage();
                errorMessages.add(errorMsg);
                System.debug(LoggingLevel.ERROR, errorMsg);
            }
        }
        
        // 批量 Upsert
        if (!recordsToUpsert.isEmpty()) {
            try {
                Database.UpsertResult[] results = Database.upsert(
                    recordsToUpsert, 
                    Enquiry__c.Enquiry_Id__c, 
                    false
                );
                
                // 处理结果
                for (Integer i = 0; i < results.size(); i++) {
                    if (results[i].isSuccess()) {
                        successCount++;
                    } else {
                        failureCount++;
                        String errorMsg = 'Upsert failed for enquiry: ';
                        for (Database.Error err : results[i].getErrors()) {
                            errorMsg += err.getMessage() + '; ';
                        }
                        errorMessages.add(errorMsg);
                    }
                }
            } catch (Exception e) {
                failureCount += recordsToUpsert.size();
                String errorMsg = 'Batch upsert error: ' + e.getMessage();
                errorMessages.add(errorMsg);
                CRMGlobalLogManager.addApexErrorLog(errorMsg, e);
            }
        }
    }
    
    /**
     * 映射API字段到Salesforce对象字段
     */
    private void mapEnquiryFields(Enquiry__c record, CRMPHKLEnquiryData enquiry) {
        // 基本字段
        record.Enquiry_Status__c = enquiry.enquiryStatus;
        record.Enquiry_Type__c = enquiry.enquiryType;
        record.Policy_Number__c = enquiry.polNo;
        record.Client_Code__c = enquiry.clientCd;
        record.Agent_Code__c = enquiry.agentCd;
        record.Agent_Name__c = enquiry.agentName;
        record.Agent_Email__c = enquiry.agentEmail;
        
        // 问题和回复
        record.Enquiry_Question__c = enquiry.enquiryQuestion;
        record.Enquiry_Details__c = enquiry.enquiryDetails;
        record.Enquiry_Reply__c = enquiry.enquiryReply;
        
        // 分类信息
        record.Source__c = enquiry.source;
        record.Division__c = enquiry.division;
        record.Wrap_Up_Category__c = enquiry.wrapUpCategory;
        record.Wrap_Up_Item__c = enquiry.wrapUpItem;
        record.SLA_Type__c = enquiry.slaType;
        
        // 评分和服务级别
        record.Rating__c = enquiry.rating;
        record.Service_Level__c = enquiry.serviceLevel;
        
        // 日期字段
        if (String.isNotBlank(enquiry.createDt)) {
            record.Create_Date__c = parseDatetime(enquiry.createDt);
        }
        if (String.isNotBlank(enquiry.lastUpdDt)) {
            record.Last_Updated_Date__c = parseDatetime(enquiry.lastUpdDt);
        }
        if (String.isNotBlank(enquiry.firstReplyDt)) {
            record.First_Reply_Date__c = parseDatetime(enquiry.firstReplyDt);
        }
        if (String.isNotBlank(enquiry.targetReplyDt)) {
            record.Target_Reply_Date__c = parseDatetime(enquiry.targetReplyDt);
        }
        if (String.isNotBlank(enquiry.lastAssignDt)) {
            record.Last_Assign_Date__c = parseDatetime(enquiry.lastAssignDt);
        }
        
        // 其他字段
        record.Policy_Owner__c = enquiry.polOwner;
        record.Handling_Time__c = enquiry.handlingTime;
        record.Agent_Class__c = enquiry.agentClass;
        record.Agent_Dist_Chan__c = enquiry.agentDistChan;
        record.Designation_Code__c = enquiry.dsgnCd;
        record.Last_Updated_User__c = enquiry.lastUpdUsr;
    }
    
    /**
     * 解析日期时间字符串 (ISO 8601格式)
     * 例如: "2025-06-10T09:37:14+08:00"
     */
    private DateTime parseDatetime(String dateTimeStr) {
        try {
            // 移除时区信息（Salesforce会自动处理）
            String cleanStr = dateTimeStr.substringBefore('+').substringBefore('-', dateTimeStr.lastIndexOf('-'));
            return DateTime.valueOfGmt(cleanStr.replace('T', ' '));
        } catch (Exception e) {
            System.debug('Error parsing datetime: ' + dateTimeStr + ' - ' + e.getMessage());
            return null;
        }
    }
    
    // ============ 内部类：API响应结构 ============
    
    public class CRMPHKLEnquiryAPIResponse {
        public String Type;
        public String ReturnCode;
        public String LastAccessedUrl;
        public String Caller;
        public String ApiName;
        public List<CRMPHKLEnquiryData> Results;
        public Integer HttpResponseCode;
        public String MessageID;
    }
    
    public class CRMPHKLEnquiryData {
        public String enquiryId;
        public String enquiryStatus;
        public String enquiryType;
        public String enquiryQuestion;
        public String enquiryDetails;
        public String enquiryReply;
        public String polNo;
        public String polOwner;
        public String clientCd;
        public String agentCd;
        public String agentName;
        public String agentEmail;
        public String agentClass;
        public String agentDistChan;
        public String source;
        public String division;
        public String dsgnCd;
        public String wrapUpCategory;
        public String wrapUpItem;
        public String slaType;
        public String serviceLevel;
        public Integer rating;
        public String handlingTime;
        public String createDt;
        public String lastUpdDt;
        public String firstReplyDt;
        public String targetReplyDt;
        public String lastAssignDt;
        public String lastWrapUpDt;
        public String cutoffDate;
        public String lastUpdUsr;
    }
}
