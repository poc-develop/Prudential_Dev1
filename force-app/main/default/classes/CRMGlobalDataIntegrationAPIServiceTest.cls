/**
 * @description       : Test class for CRMGlobalDataIntegrationAPIService
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-19
 * @last modified by  : Franco
**/
@IsTest
private class CRMGlobalDataIntegrationAPIServiceTest {

    // Mock for successful HTTP response
    private class MockSuccessResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"result": "ok", "message": "success"}');
            return res;
        }
    }

    // Mock for error HTTP response
    private class MockErrorResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500);
            res.setBody('{"error": "Server Error"}');
            return res;
        }
    }

    // Create a test metadata config record
    private static CRM_Global_DataIntegration_Config__mdt createTestConfig() {
        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt(
            DeveloperName = 'Test_Config',
            MasterLabel = 'Test Config',
            Parent_Object__c = 'Account',
            Parent_ExId_Field__c = 'Name',
            HTTP_Method__c = 'POST',
            Named_Credential__c = 'Test_NC',
            Endpoint_Path__c = '/endpoint',
            Request_Params__c = 'param1=value1',
            Request_Headers__c = '{"fi_client_cd":"123","Name":"{{{Name}}}"}',
            Request_Body__c = '{"name":"{{{Name}}}"}',
            Response_Format__c = 'JSON',
            Success_Codes__c = '200;201',
            Timeout__c = 10000
        );
        return config;
    }

    // Create a test Account record
    private static Account createTestRecord() {
        Id customerRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
        Account acc = new Account(LastName = 'Test Account', RecordTypeId = customerRTId);
        insert acc;
        return acc;
    }

    @IsTest
    static void testCallExternalApi_success() {
        CRM_Global_DataIntegration_Config__mdt config = createTestConfig();
        Account acc = createTestRecord();

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());

        CRMGlobalDataIntegrationConfigWrapper wrapper =
            new CRMGlobalDataIntegrationConfigWrapper(config, acc.Id);

        HttpResponse res = CRMGlobalDataIntegrationAPIService.callExternalApi(wrapper);
        System.assertEquals(200, res.getStatusCode(), 'Should return 200');
        Test.stopTest();
    }

    @IsTest
    static void testCallExternalApi_error() {
        CRM_Global_DataIntegration_Config__mdt config = createTestConfig();
        Account acc = createTestRecord();

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockErrorResponse());

        CRMGlobalDataIntegrationConfigWrapper wrapper =
            new CRMGlobalDataIntegrationConfigWrapper(config, acc.Id);

        try {
            CRMGlobalDataIntegrationAPIService.callExternalApi(wrapper);
            System.assert(false, 'Expected exception not thrown');
        } catch (CRMGlobalDataIntegrationException e) {
            System.assert(e.getMessage().contains('API'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testParseApiResponse_successJson() {
        CRM_Global_DataIntegration_Config__mdt config = createTestConfig();
        Account acc = createTestRecord();

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"result": "ok"}');
        CRMGlobalDataIntegrationConfigWrapper wrapper =
            new CRMGlobalDataIntegrationConfigWrapper(config, acc.Id);

        Object parsed = CRMGlobalDataIntegrationAPIService.parseApiResponse(wrapper, res);
        Map<String, Object> parsedMap = (Map<String, Object>) parsed;
        System.assertEquals('ok', parsedMap.get('result'), 'Should parse JSON correctly');
    }

    @IsTest
    static void testParseApiResponse_parseError() {
        CRM_Global_DataIntegration_Config__mdt config = createTestConfig();
        Account acc = createTestRecord();

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('INVALID_JSON');

        try {
            CRMGlobalDataIntegrationConfigWrapper wrapper =
            new CRMGlobalDataIntegrationConfigWrapper(config, acc.Id);
            CRMGlobalDataIntegrationAPIService.parseApiResponse(wrapper, res);
            System.assert(false, 'Expected exception not thrown');
        } catch (CRMGlobalDataIntegrationException e) {
            System.assert(e.getMessage().contains('Response JSON Parse Error'));
        }
    }

    @IsTest
    static void testParseApiResponse_xmlNotSupported() {
        CRM_Global_DataIntegration_Config__mdt config = createTestConfig();
        Account acc = createTestRecord();
        config.Response_Format__c = 'XML';
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('<xml><test>ok</test></xml>');

        try {
            CRMGlobalDataIntegrationConfigWrapper wrapper =
            new CRMGlobalDataIntegrationConfigWrapper(config, acc.Id);
            CRMGlobalDataIntegrationAPIService.parseApiResponse(wrapper, res);
            System.assert(false, 'Should throw XML not implemented exception');
        } catch (CRMGlobalDataIntegrationException e) {
            System.assert(e.getMessage().contains('XML response format not yet implemented'));
        }
    }

    @IsTest
    static void testIsSuccessResponse_defaultRange() {
        CRM_Global_DataIntegration_Config__mdt config = createTestConfig();
        Account acc = createTestRecord();
        config.Success_Codes__c = null;

        // Call indirectly via parseApiResponse
        HttpResponse res = new HttpResponse();
        res.setStatusCode(204);
        res.setBody('{"result":"no content"}');

        CRMGlobalDataIntegrationConfigWrapper wrapper =
            new CRMGlobalDataIntegrationConfigWrapper(config, acc.Id);
        Object parsed = CRMGlobalDataIntegrationAPIService.parseApiResponse(wrapper, res);
        System.assertNotEquals(null, parsed);
    }

    @IsTest
    static void testGetBodyFromTemplate_withJsonTemplate() {
        CRM_Global_DataIntegration_Config__mdt config = createTestConfig();
        Account acc = createTestRecord();

        // Call indirectly by invoking callExternalApi
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());
        CRMGlobalDataIntegrationConfigWrapper wrapper =
            new CRMGlobalDataIntegrationConfigWrapper(config, acc.Id);
        CRMGlobalDataIntegrationAPIService.callExternalApi(wrapper);
        Test.stopTest();
    }

}