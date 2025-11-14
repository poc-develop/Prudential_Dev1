@isTest
public class CrmGlobalDataIngestionHandlerIncTest {

    @isTest
    static void testInit() {
        CRM_Global_Data_Ingestion_Job__c job = new CRM_Global_Data_Ingestion_Job__c();
        insert job;

        List<CRM_Global_Raw_Data_Staging__c> rawDataList = new List<CRM_Global_Raw_Data_Staging__c>();
        rawDataList.add(new CRM_Global_Raw_Data_Staging__c(
            CRM_Global_DataIngestionJob__c = job.Id,
            CRM_Global_RawJSONData__c = '{"Incident ID": "TEST-001", "Incident Description": "Test Desc", "Status": "New"}'
        ));

        Map<String, List<String>> errorMap = new Map<String, List<String>>();

        CrmGlobalDataIngestionHandlerIncident handler = new CrmGlobalDataIngestionHandlerIncident();
        handler.init(job, rawDataList, errorMap);

        System.assertNotEquals(null, handler.incidentList, 'incidentList应初始化');
        System.assertNotEquals(null, handler.rawDataIdList, 'rawDataIdList应初始化');
    }

    @isTest
    static void testValidateRawData_Success() {
        CRM_Global_Data_Ingestion_Job__c job = new CRM_Global_Data_Ingestion_Job__c();
        insert job;

        CRM_Global_Raw_Data_Staging__c rawData = new CRM_Global_Raw_Data_Staging__c(
            CRM_Global_DataIngestionJob__c = job.Id,
            CRM_Global_RawJSONData__c = '{"Incident ID": "TEST-001", "Incident Description": "Test Desc", "Status": "New"}'
        );
        insert rawData;
        List<CRM_Global_Raw_Data_Staging__c> rawDataList = new List<CRM_Global_Raw_Data_Staging__c>{rawData};

        Map<String, List<String>> errorMap = new Map<String, List<String>>();

        CrmGlobalDataIngestionHandlerIncident handler = new CrmGlobalDataIngestionHandlerIncident();
        handler.init(job, rawDataList, errorMap);
        handler.processJob();
        System.assert(!errorMap.containsKey(rawData.Id), '有效数据不应产生错误');
    }

    @isTest
    static void testValidateRawData_ValidationErrors() {
        CRM_Global_Data_Ingestion_Job__c job = new CRM_Global_Data_Ingestion_Job__c();
        insert job;

        CRM_Global_Raw_Data_Staging__c rawData = new CRM_Global_Raw_Data_Staging__c(
            CRM_Global_DataIngestionJob__c = job.Id,
            CRM_Global_RawJSONData__c = '{"Incident ID": "", "Incident Description": "", "Status": "InvalidStatus"}'
        );
        insert rawData;
        List<CRM_Global_Raw_Data_Staging__c> rawDataList = new List<CRM_Global_Raw_Data_Staging__c>{rawData};

        Map<String, List<String>> errorMap = new Map<String, List<String>>();

        CrmGlobalDataIngestionHandlerIncident handler = new CrmGlobalDataIngestionHandlerIncident();
        handler.init(job, rawDataList, errorMap);
        handler.processJob();
        
        List<String> errors = errorMap.get(rawData.Id);

        System.assert(errors.contains('Incident ID is Empty'), '应包含Incident ID为空的错误');
        System.assert(errors.contains('Incident Description is Empty'), '应包含Description为空的错误');
        System.assert(errors.contains('Status [InvalidStatus] is not a correct value'), '应包含Status无效的错误');
    }

    @isTest
    static void testHandleRawData_Success() {
        CRM_Global_Data_Ingestion_Job__c job = new CRM_Global_Data_Ingestion_Job__c();
        insert job;

        CRM_Global_Raw_Data_Staging__c rawData = new CRM_Global_Raw_Data_Staging__c(
            CRM_Global_DataIngestionJob__c = job.Id,
            CRM_Global_RawJSONData__c = '{"Incident ID": "TEST-001", "Incident Description": "Test Desc", "Status": "New"}'
        );
        insert rawData;
        List<CRM_Global_Raw_Data_Staging__c> rawDataList = new List<CRM_Global_Raw_Data_Staging__c>{rawData};

        Map<String, List<String>> errorMap = new Map<String, List<String>>();

        CrmGlobalDataIngestionHandlerIncident handler = new CrmGlobalDataIngestionHandlerIncident();
        handler.init(job, rawDataList, errorMap);
        handler.processJob();

        
        Incident incident = handler.incidentList[0];
        System.assertEquals('TEST-001', incident.CRM_Global_IncidentID__c, 'Incident ID应正确映射');
        System.assertEquals('Test Desc', incident.CRM_Global_IncidentDescription__c, 'Description应正确映射');
        System.assertEquals('New', incident.Status, 'Status应正确映射');
        System.assertEquals(1, handler.rawDataIdList.size(), 'rawDataIdList应包含原始数据ID');
        System.assertEquals(rawData.Id, handler.rawDataIdList[0], 'rawDataId应正确记录');
    }

    @isTest
    static void testHandleRawData_SkipErrorData() {

        CRM_Global_Data_Ingestion_Job__c job = new CRM_Global_Data_Ingestion_Job__c();
        insert job;

        CRM_Global_Raw_Data_Staging__c rawData = new CRM_Global_Raw_Data_Staging__c(
            CRM_Global_DataIngestionJob__c = job.Id,
            CRM_Global_RawJSONData__c = '{"Incident ID": "TEST-001", "Incident Description": "Test Desc", "Status": "New"}'
        );
        insert rawData;
        List<CRM_Global_Raw_Data_Staging__c> rawDataList = new List<CRM_Global_Raw_Data_Staging__c>{rawData};

        Map<String, List<String>> errorMap = new Map<String, List<String>>();
        errorMap.put(rawData.Id, new List<String>{'Test Error'});

        CrmGlobalDataIngestionHandlerIncident handler = new CrmGlobalDataIngestionHandlerIncident();
        handler.init(job, rawDataList, errorMap);
        handler.processJob();
        System.assertEquals(0, handler.incidentList.size(), '错误数据应被跳过，不生成Incident记录');
        System.assertEquals(0, handler.rawDataIdList.size(), '错误数据ID不应被记录');
    }

    @isTest
    static void testHandleRawData_JsonParseException() {
        CRM_Global_Data_Ingestion_Job__c job = new CRM_Global_Data_Ingestion_Job__c();
        insert job;

        CRM_Global_Raw_Data_Staging__c rawData = new CRM_Global_Raw_Data_Staging__c(
            CRM_Global_DataIngestionJob__c = job.Id,
            CRM_Global_RawJSONData__c = 'invalid json' 
        );
        insert rawData;
        List<CRM_Global_Raw_Data_Staging__c> rawDataList = new List<CRM_Global_Raw_Data_Staging__c>{rawData};

        Map<String, List<String>> errorMap = new Map<String, List<String>>();

        CrmGlobalDataIngestionHandlerIncident handler = new CrmGlobalDataIngestionHandlerIncident();
        handler.init(job, rawDataList, errorMap);
        Boolean exceptionThrown = false;
        try {
            handler.processJob();
        } catch (Exception e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Unexpected character'), '应抛出JSON解析异常');
        }
         System.assert(exceptionThrown, 'JSON格式错误应抛出异常');
    }
    @isTest
    static void testAttributeMethods() {
        CrmGlobalDataIngestionHandlerIncident handler = new CrmGlobalDataIngestionHandlerIncident();
        handler.init(new CRM_Global_Data_Ingestion_Job__c(), new List<CRM_Global_Raw_Data_Staging__c>(), new Map<String, List<String>>());

        System.assert(handler.getAttribute('incidentList') instanceof List<Incident>, 'getAttribute应返回incidentList');

        System.assert(handler.getAttribute('rawDataIdList') instanceof List<String>, 'getAttribute应返回rawDataIdList');

        System.assert(null == handler.getAttribute('nonExistent'), '不存在的属性应返回null');

        System.assert(handler.setAttribute('test', 'value') != null, 'setAttribute应返回实例');
    }

}