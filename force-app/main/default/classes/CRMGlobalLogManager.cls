/**
 * @author Hassan
 * @date 2025/7/22
 * @description Insert Exception/logs into CRM_Global_ApexLog__c sObject
 *              Insert Inbound/Outbound into CRM_Global_Webservice_Call_Log__c sObject
 */
public without sharing class CRMGlobalLogManager {

    // Dealing with create ApexLog in loops,Batch create logs
    private static List<CRM_Global_ApexLog__c> apexLogList = new List<CRM_Global_ApexLog__c>();
    // Dealing with callout scenarios in loops,Batch create logs
    private static List<CRM_Global_Webservice_Call_Log__c> wsLogList = new List<CRM_Global_Webservice_Call_Log__c>();

    private static Integer logMessageLength = CRM_Global_ApexLog__c.Log_Message__c.getDescribe().getLength();
    private static Integer requestBodyLength = CRM_Global_Webservice_Call_Log__c.Request_Body__c.getDescribe().getLength();
    private static Integer requestHeadersLength = CRM_Global_Webservice_Call_Log__c.Request_Headers__c.getDescribe().getLength();
    private static Integer responseBodyLength = CRM_Global_Webservice_Call_Log__c.Response_Body__c.getDescribe().getLength();

    /**
     * @description Create an apex info log
     * @param message 
     */
    public static void createApexInfoLog(String message) {
        CRM_Global_ApexLog__c apexLog = buildApexLog('INFO', message, null);
        Database.insert(apexLog, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Create an apex warn log
     * @param message 
     */
    public static void createApexWarnLog(String message) {
        CRM_Global_ApexLog__c apexLog = buildApexLog('WARN', message, null);
        Database.insert(apexLog, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Create an apex debug log
     * @param message 
     */
    public static void createApexDebugLog(String message) {
        CRM_Global_ApexLog__c apexLog = buildApexLog('DEBUG', message, null);
        Database.insert(apexLog, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Create an apex error log
     * @param message 
     * @param e 
     */
    public static void createApexErrorLog(String message, Exception e) {
        CRM_Global_ApexLog__c apexLog = buildApexLog('ERROR', message, e);
        Database.insert(apexLog, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Add an apex info log to list
     * @param message 
     */
    public static void addApexInfoLog(String message) {
        CRM_Global_ApexLog__c apexLog = buildApexLog('INFO', message, null);
        apexLogList.add(apexLog);
    }

    /**
     * @description Add an apex warn log to list
     * @param message 
     */
    public static void addApexWarnLog(String message) {
        CRM_Global_ApexLog__c apexLog = buildApexLog('WARN', message, null);
        apexLogList.add(apexLog);
    }

    /**
     * @description Add an apex debug log to list
     * @param message 
     */
    public static void addApexDebugLog(String message) {
        CRM_Global_ApexLog__c apexLog = buildApexLog('DEBUG', message, null);
        apexLogList.add(apexLog);
    }

    /**
     * @description Add an apex error log to list
     * @param message 
     * @param e 
     */
    public static void addApexErrorLog(String message, Exception e) {
        CRM_Global_ApexLog__c apexLog = buildApexLog('ERROR', message, e);
        apexLogList.add(apexLog);
    }

    /**
     * @description Save and flush apex log list and web service log list
     */
    public static void saveAndFlushLogs() {
        if(!apexLogList.isEmpty()){
            Database.insert(apexLogList, AccessLevel.SYSTEM_MODE);
            apexLogList.clear();
        }

        if(!wsLogList.isEmpty()){
            Database.insert(wsLogList, AccessLevel.SYSTEM_MODE);
            wsLogList.clear();
        }
    }

    private static CRM_Global_ApexLog__c buildApexLog(String severity, String message, Exception e) {
        String trace = new CRMGlobalCustomLogException().getStackTraceString();
        String callerLine = trace.split('\n')[2];
        List<String> classInfos = callerLine.split(':')[0].split('\\.');

        String logMessage = message;
        if(e != null) {
            logMessage += ' \n Exception Message: ' + e.getMessage() + ' \n Stack Trace: ' + e.getStacktraceString();
        }

        CRM_Global_ApexLog__c apexLog = new CRM_Global_ApexLog__c(
            Apex_Class__c = classInfos[1],
            Method_Name__c = classInfos[2],
            Severity__c = severity,
            Log_Message__c = logMessage.abbreviate(logMessageLength),
            Transaction_ID__c = System.Request.getCurrent().getRequestId()
        );
        return apexLog;
    }

    /**
     * @description Create an outbound web service log
     * @param req 
     * @param res 
     * @param durationInMS 
     */
    public static void createWebServiceLog(HttpRequest req, HTTPResponse res, Long durationInMS) {
        CRM_Global_Webservice_Call_Log__c wsLog = buildOutboundWebServiceLog(req, res, durationInMS);
        Database.insert(wsLog, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Add an outbound web service log to list
     * @param req 
     * @param res 
     * @param durationInMS 
     */
    public static void addWebServiceLog(HttpRequest req, HTTPResponse res, Long durationInMS) {
        CRM_Global_Webservice_Call_Log__c wsLog = buildOutboundWebServiceLog(req, res, durationInMS);
        wsLogList.add(wsLog);
    }

    private static CRM_Global_Webservice_Call_Log__c buildOutboundWebServiceLog(HttpRequest req, HTTPResponse res, Long durationInMS) {
        String messageId = null;
        try {
            Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            messageId = String.valueOf(dataMap.get('MessageID'));
        } catch (Exception e) {
            messageId = 'Unknown';
        }

        CRM_Global_Webservice_Call_Log__c wsLog = new CRM_Global_Webservice_Call_Log__c(
            Endpoint__c = req?.getEndpoint(),
            HTTP_Method__c = req?.getMethod(),
            Message_Id__c = messageId,
            Processing_Time_ms__c = durationInMS,
            Request_Body__c = req?.getBody(),
            Response_Body__c = res?.getBody(),
            Response_Status_Code__c = res?.getStatusCode(),
            Transaction_ID__c = System.Request.getCurrent().getRequestId(),
            Type__c = 'Outbound'
        );
        return wsLog;
    }

    /**
     * @description Create an inbound web service log
     * @param req 
     * @param res 
     */
    public static void createWebServiceLog(RestRequest req, RestResponse res) {
        CRM_Global_Webservice_Call_Log__c wsLog = buildInboundWebServiceLog(req, res);
        Database.insert(wsLog, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Add an inbound web service to list
     * @param req 
     * @param res 
     */
    public static void addWebServiceLog(RestRequest req, RestResponse res) {
        CRM_Global_Webservice_Call_Log__c wsLog = buildInboundWebServiceLog(req, res);
        wsLogList.add(wsLog);
    }

    private static CRM_Global_Webservice_Call_Log__c buildInboundWebServiceLog(RestRequest req, RestResponse res) {
        CRM_Global_Webservice_Call_Log__c wsLog = new CRM_Global_Webservice_Call_Log__c(
            Endpoint__c = req?.requestURI,
            HTTP_Method__c = req?.httpMethod,
            Request_Body__c = req?.requestBody.toString().abbreviate(requestBodyLength),
            Request_Headers__c = JSON.serializePretty(req?.headers).abbreviate(requestHeadersLength),
            Response_Body__c = res?.responseBody.toString().abbreviate(responseBodyLength),
            Response_Status_Code__c = res?.statusCode,
            Type__c = 'Inbound'
        );
        return wsLog;
    }

    /**
     * @description Custom log excpetion
     */
    public class CRMGlobalCustomLogException extends Exception {}
}