/**
 * @author Terence
 * @date 2025/7/22
 * @description Test class for CRMGlobalLogManager
 */
@IsTest
private class CRMGlobalLogManagerTest {

    @IsTest
    static void testCreateApexLogs() {
        Test.startTest();
        CRMGlobalLogManager.createApexInfoLog('Info message');
        CRMGlobalLogManager.createApexWarnLog('Warn message');
        CRMGlobalLogManager.createApexDebugLog('Debug message');
        CRMGlobalLogManager.createApexErrorLog('Error message', new CRMGlobalLogManager.CRMGlobalCustomLogException('Test exception'));
        Test.stopTest();

        List<CRM_Global_ApexLog__c> logs = [
            SELECT Id, Severity__c, Log_Message__c FROM CRM_Global_ApexLog__c
        ];
        System.assertEquals(4, logs.size(), 'Should create 4 Apex logs');
    }

    @IsTest
    static void testAddApexLogsAndSaveFlushLogs() {
        Test.startTest();
        CRMGlobalLogManager.addApexInfoLog('Info message');
        CRMGlobalLogManager.addApexWarnLog('Warn message');
        CRMGlobalLogManager.addApexDebugLog('Debug message');
        CRMGlobalLogManager.addApexErrorLog('Error message', new CRMGlobalLogManager.CRMGlobalCustomLogException('Batch exception'));
        CRMGlobalLogManager.saveAndFlushLogs();
        Test.stopTest();

        List<CRM_Global_ApexLog__c> logs = [
            SELECT Id, Severity__c FROM CRM_Global_ApexLog__c
        ];
        System.assertEquals(4, logs.size(), 'Should batch insert 4 Apex logs');
    }

    @IsTest
    static void testCreateOutboundWebServiceLog() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://test.salesforce.com');
        req.setMethod('POST');
        req.setBody('{"request":"body"}');

        HttpResponse res = new HttpResponse();
        res.setBody('{"MessageID":"12345","result":"ok"}');
        res.setStatusCode(200);

        Test.startTest();
        CRMGlobalLogManager.createWebServiceLog(req, res, 150L);
        Test.stopTest();

        List<CRM_Global_Webservice_Call_Log__c> wsLogs = [
            SELECT Id, Message_Id__c, Type__c FROM CRM_Global_Webservice_Call_Log__c
        ];
        System.assertEquals(1, wsLogs.size(), 'Should create one outbound web service log');
        System.assertEquals('12345', wsLogs[0].Message_Id__c, 'MessageID should be parsed from response');
    }

    @IsTest
    static void testAddOutboundWebServiceLogAndSaveFlush() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://example.com/api');
        req.setMethod('GET');
        req.setBody('{}');

        HttpResponse res = new HttpResponse();
        res.setBody('{"MessageID":"99999"}');
        res.setStatusCode(201);

        Test.startTest();
        CRMGlobalLogManager.addWebServiceLog(req, res, 300L);
        CRMGlobalLogManager.saveAndFlushLogs();
        Test.stopTest();

        List<CRM_Global_Webservice_Call_Log__c> wsLogs = [
            SELECT Id, Type__c, Response_Status_Code__c FROM CRM_Global_Webservice_Call_Log__c
        ];
        System.assertEquals(1, wsLogs.size(), 'Should insert 1 outbound ws log');
        System.assertEquals('Outbound', wsLogs[0].Type__c, 'Type should be Outbound');
    }

    @IsTest
    static void testCreateInboundWebServiceLog() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/test';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"key":"value"}');
        req.headers.put('Authorization', 'Bearer xyz');

        RestResponse res = new RestResponse();
        res.responseBody = Blob.valueOf('{"result":"ok"}');
        res.statusCode = 200;

        Test.startTest();
        CRMGlobalLogManager.createWebServiceLog(req, res);
        Test.stopTest();

        List<CRM_Global_Webservice_Call_Log__c> wsLogs = [
            SELECT Id, Type__c, HTTP_Method__c FROM CRM_Global_Webservice_Call_Log__c
        ];
        System.assertEquals(1, wsLogs.size(), 'Should create 1 inbound ws log');
        System.assertEquals('Inbound', wsLogs[0].Type__c, 'Type should be Inbound');
    }

    @IsTest
    static void testAddInboundWebServiceLogAndSaveFlush() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/test2';
        req.httpMethod = 'GET';
        req.requestBody = Blob.valueOf('{"ping":"pong"}');
        req.headers.put('Authorization', 'Bearer abc');

        RestResponse res = new RestResponse();
        res.responseBody = Blob.valueOf('{"result":"pong"}');
        res.statusCode = 201;

        Test.startTest();
        CRMGlobalLogManager.addWebServiceLog(req, res);
        CRMGlobalLogManager.saveAndFlushLogs();
        Test.stopTest();

        List<CRM_Global_Webservice_Call_Log__c> wsLogs = [
            SELECT Id, Type__c FROM CRM_Global_Webservice_Call_Log__c WHERE Type__c = 'Inbound'
        ];
        System.assertEquals(1, wsLogs.size(), 'Should batch insert 1 inbound ws log');
    }
}