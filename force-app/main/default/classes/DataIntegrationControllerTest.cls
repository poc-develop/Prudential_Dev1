@isTest
private class DataIntegrationControllerTest {
    
    // @TestSetup
    // static void setup() {
    //     Account testAccount = new Account(
    //         Name = 'Test Account',
    //         External_Id__c = 'ext-123'
    //     );
    //     insert testAccount;
    // }
    
    // @isTest
    // static void testGetIntegrationConfig() {
    //     // Setup test metadata
    //     DataIntegration_Config__mdt testConfig = new DataIntegration_Config__mdt(
    //         DeveloperName = 'Test_Config',
    //         Integration_Name__c = 'Test Integration',
    //         Is_Active__c = true,
    //         Integration_Type__c = 'Data_Cloud',
    //         Named_Credential__c = 'DataCloud_API',
    //         DataCloud_Query__c = 'SELECT Id, Name FROM Customer__dlm WHERE ExternalId__c = \'{RECORD_ID}\'',
    //         Target_Object__c = 'Account',
    //         Target_Id_Field__c = 'External_Id__c',
    //         Field_Mappings__c = '{"Id":"External_Id__c","Name":"Name"}'
    //     );
        
    //     // Mock the metadata query
    //     Test.startTest();
    //     Test.setMock(HttpCalloutMock.class, new DataCloudMock());
    //     DataIntegration_Config__mdt result = DataIntegrationController.getIntegrationConfig('Test_Config');
    //     Test.stopTest();
        
    //     System.assertNotEquals(null, result, 'Should return a configuration');
    // }
    
    // @isTest
    // static void testDataCloudIntegration() {
    //     Account testAccount = [SELECT Id, External_Id__c FROM Account LIMIT 1];
        
    //     // Setup test metadata
    //     DataIntegration_Config__mdt testConfig = new DataIntegration_Config__mdt(
    //         DeveloperName = 'Test_Config',
    //         Integration_Name__c = 'Test Integration',
    //         Is_Active__c = true,
    //         Integration_Type__c = 'Data_Cloud',
    //         Named_Credential__c = 'DataCloud_API',
    //         DataCloud_Query__c = 'SELECT Id, Name FROM Customer__dlm WHERE ExternalId__c = \'{RECORD_ID}\'',
    //         Target_Object__c = 'Account',
    //         Target_Id_Field__c = 'External_Id__c',
    //         Field_Mappings__c = '{"Id":"External_Id__c","Name":"Name"}',
    //         Success_Codes__c = '200'
    //     );
        
    //     // Mock the Data Cloud callout
    //     Test.startTest();
    //     Test.setMock(HttpCalloutMock.class, new DataCloudMock());
    //     String result = DataIntegrationController.syncWithIntegration(
    //         testAccount.External_Id__c,
    //         JSON.serialize(testConfig)
    //     );
    //     Test.stopTest();
        
    //     System.assertEquals('Sync completed successfully', result, 'Sync should complete successfully');
    // }
    
    // @isTest
    // static void testExternalApiIntegration() {
    //     Account testAccount = [SELECT Id, External_Id__c FROM Account LIMIT 1];
        
    //     // Setup test metadata
    //     DataIntegration_Config__mdt testConfig = new DataIntegration_Config__mdt(
    //         DeveloperName = 'Test_Config',
    //         Integration_Name__c = 'Test Integration',
    //         Is_Active__c = true,
    //         Integration_Type__c = 'External_API',
    //         Named_Credential__c = 'ERP_API',
    //         HTTP_Method__c = 'GET',
    //         Endpoint_Path__c = '/customers/{RECORD_ID}',
    //         Target_Object__c = 'Account',
    //         Target_Id_Field__c = 'External_Id__c',
    //         Field_Mappings__c = '{"id":"External_Id__c","name":"Name"}',
    //         Success_Codes__c = '200'
    //     );
        
    //     // Mock the external API call
    //     Test.startTest();
    //     Test.setMock(HttpCalloutMock.class, new ExternalApiMock());
    //     String result = DataIntegrationController.syncWithIntegration(
    //         testAccount.External_Id__c,
    //         JSON.serialize(testConfig)
    //     );
    //     Test.stopTest();
        
    //     System.assertEquals('Sync completed successfully', result, 'Sync should complete successfully');
    // }
    
    // // Mock classes for testing
    // private class DataCloudMock implements HttpCalloutMock {
    //     public HTTPResponse respond(HTTPRequest req) {
    //         HttpResponse res = new HttpResponse();
    //         res.setStatusCode(200);
    //         res.setBody('{"records":[{"Id":"ext-123","Name":"Test Account"}]}');
    //         return res;
    //     }
    // }
    
    // private class ExternalApiMock implements HttpCalloutMock {
    //     public HTTPResponse respond(HTTPRequest req) {
    //         HttpResponse res = new HttpResponse();
    //         res.setStatusCode(200);
    //         res.setBody('{"Id":"ext-123","name":"Test Account"}');
    //         return res;
    //     }
    // }
}