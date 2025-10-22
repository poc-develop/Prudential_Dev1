/**
 * CRMGlobalExcelParserController
 * @author       : Easin Zhou
 * @date         : 2025-10-14
 * @description  : Used for processing Excel file uploads.
 */
public with sharing class CRMGlobalExcelParserController {
    
    /**
     * @description Transfer processing results
     */
    public class ProcessingResult {
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer successfulRecords { get; set; }
        @AuraEnabled public Integer failedRecords { get; set; }
        @AuraEnabled public List<String> recordIds { get; set; }
        
        /**
         * @description constructor
         */
        public ProcessingResult() {
            this.recordIds = new List<String>();
            this.successfulRecords = 0;
            this.failedRecords = 0;
            this.totalRecords = 0;
        }
    }
    
    /**
     * @description Excel Record
     */
    public class ExcelRecord {
        @AuraEnabled public String sheetName { get; set; }
        @AuraEnabled public Integer rowNumber { get; set; }
        @AuraEnabled public Map<String, Object> data { get; set; }
        @AuraEnabled public String originalData { get; set; }
    }
    
    /**
     * @description Wrapper of Excel Record
     */
    public class ExcelDataWrapper {
        @AuraEnabled public String fileName { get; set; }
        @AuraEnabled public String uploadDate { get; set; }
        @AuraEnabled public Integer totalSheets { get; set; }
        @AuraEnabled public List<ExcelRecord> records { get; set; }
    }
    
    /**
     * @method parseExcelAndSaveRecords
     * @description The main methods of Parse Excel and Save Records
     * @param recordsData
     * @param fileName
     * @param callType
     * @param targetObject
     * @param channel
     * @param subType
     * @return ProcessingResult
     */
    @AuraEnabled
    public static ProcessingResult parseExcelAndSaveRecords(String recordsData, String fileName, String callType, String targetObject, String channel, String subType) {
        ProcessingResult result = new ProcessingResult();
        
        try {
            // 使用JSON.deserializeUntyped先检查数据结构
            Map<String, Object> untypedMap = (Map<String, Object>) JSON.deserializeUntyped(recordsData);
            
            // 手动构建ExcelDataWrapper对象
            ExcelDataWrapper wrapper = new ExcelDataWrapper();
            wrapper.fileName = (String) untypedMap.get('fileName');
            wrapper.uploadDate = (String) untypedMap.get('uploadDate');
            wrapper.totalSheets = (Integer) untypedMap.get('totalSheets');
            
            // 处理records数组
            List<Object> recordsList = (List<Object>) untypedMap.get('records');
            wrapper.records = new List<ExcelRecord>();
            
            if (recordsList != null) {
                for (Object recordObj : recordsList) {
                    Map<String, Object> recordMap = (Map<String, Object>) recordObj;
                    ExcelRecord record = new ExcelRecord();
                    record.sheetName = (String) recordMap.get('sheetName');
                    record.rowNumber = (Integer) recordMap.get('rowNumber');
                    record.originalData = (String) recordMap.get('originalData');
                    
                    // 处理data字段
                    Map<String, Object> dataMap = (Map<String, Object>) recordMap.get('data');
                    record.data = new Map<String, Object>();
                    
                    if (dataMap != null) {
                        for (String key : dataMap.keySet()) {
                            record.data.put(key, dataMap.get(key));
                        }
                    }
                    
                    wrapper.records.add(record);
                }
            }
            
            result.totalRecords = wrapper.records.size();
            
            if (result.totalRecords == 0) {
                return result;
            }
            
            // ============ 新增逻辑开始 ============
            List<Database.SaveResult> saveResults = saveJobWithRaw(fileName, callType, targetObject, wrapper.records, channel, subType);
            
            // 统计处理结果
            for (Database.SaveResult sr : saveResults) {
                if (sr.isSuccess()) {
                    result.successfulRecords++;
                    result.recordIds.add(sr.getId());
                } else {
                    result.failedRecords++;
                    // 记录错误信息（可选）
                    for(Database.Error err : sr.getErrors()) {
                        System.debug('Error: ' + err.getMessage());
                    }
                }
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Process Excel data failed: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
        }
        
        return result;
    }

    /**
     * @method saveJobWithRaw
     * @description Save Job With Raw
     * @param fileName
     * @param callType
     * @param targetObject
     * @param wrapperRecords
     * @param channel
     * @param subType
     * @return List<Database.SaveResult>
     */
    public static List<Database.SaveResult> saveJobWithRaw(String fileName, String callType, String targetObject, List<ExcelRecord> wrapperRecords, String channel, String subType) {
        List<CRM_GLOBAL_Raw_Data_Staging__c> recordsToInsert = new List<CRM_GLOBAL_Raw_Data_Staging__c>();
        List<Database.SaveResult> saveResults = new List<Database.SaveResult>();
        try {
            // 1. 创建CRM_GLOBAL_Data_Ingestion_Job__c主记录
            CRM_GLOBAL_Data_Ingestion_Job__c job = new CRM_GLOBAL_Data_Ingestion_Job__c();
            job.CRM_GLOBAL_SubmittedSource__c = fileName;
            job.CRM_Global_Call_Type__c = callType;
            job.CRM_GLOBAL_Status__c = 'Processing';
            job.CRM_GLOBAL_StartTime__c = Datetime.now();
            job.CRM_GLOBAL_TotalRecords__c = wrapperRecords.size();
            job.CRM_Global_TargetObject__c = targetObject;
            job.CRM_Global_Sub_Type_1__c = subType;
            job.CRM_Global_Channel__c = channel;

            // 插入主记录
            insert job;

            // 2. 创建CRM_GLOBAL_Raw_Data_Staging__c子记录
            for (ExcelRecord excelRecord : wrapperRecords) {
                CRM_GLOBAL_Raw_Data_Staging__c stagingRecord = new CRM_GLOBAL_Raw_Data_Staging__c();
                stagingRecord.CRM_GLOBAL_DataIngestionJob__c = job.Id; // 关联到主记录
                stagingRecord.CRM_GLOBAL_RawJSONData__c = excelRecord.originalData;
                stagingRecord.CRM_GLOBAL_ProcessingStatus__c = 'Pending'; // 设置默认状态
                stagingRecord.CRM_GLOBAL_ProcessingAttempts__c = 0;
                
                // 可选：生成外部ID（使用文件名+工作表名+行号）
                stagingRecord.CRM_GLOBAL_ExternalId__c = fileName + '_' + 
                                            excelRecord.sheetName + '_' + 
                                            excelRecord.rowNumber;
                
                recordsToInsert.add(stagingRecord);
            }

            // 批量插入所有子记录
            saveResults = Database.insert(recordsToInsert, false);
        } catch (Exception e) {
            throw new AuraHandledException('Process Excel data failed: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
        }
        return saveResults;
    }
    
    /**
     * @method validateJson
     * @description validate Json
     * @param jsonData
     * @return Boolean
     */
    @AuraEnabled
    public static Boolean validateJson(String jsonData) {
        try {
            Object result = JSON.deserializeUntyped(jsonData);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}