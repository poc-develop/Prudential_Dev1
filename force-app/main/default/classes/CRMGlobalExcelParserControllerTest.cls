@isTest
public with sharing class CRMGlobalExcelParserControllerTest {
    // @testSetup
    // static void setup(){
    //     LoyaltyProgram programItem = MO_LoyaltyTestDataFactory.createLoyaltyProgram();
    //     Account personAccount = MO_LoyaltyTestDataFactory.createPersonAccountContact(100);
    //     personAccount = [SELECT Id, PersonContactId FROM Account Limit 1];
    //     LoyaltyProgramMember memberItem = MO_LoyaltyTestDataFactory.createLoyaltyProgramMember(programItem.Id,personAccount.PersonContactId);       
    //     personAccount.IruPersonId__c = '111111111';
    //     update personAccount;
    //     memberItem.IruPersonId__c = '111111111';
    //     update memberItem;

    //     SystemConfigurationSetting__c configSetting = new SystemConfigurationSetting__c();
    //     configSetting.Name = 'LimitPerCalloutForRetrieveTransaction';
    //     configSetting.Value__c = '50';
    //     insert configSetting;
        
    //     System.assertNotEquals(personAccount, null, 'This is Error');
    // }

    @IsTest
    private static void coverParseExcelAndSaveRecords(){
        String recordsData = '{"fileName":"callList.xlsx","uploadDate":"2025-10-18T04:57:59.900Z","totalSheets":1,"records":[{"sheetName":"Sheet1","rowNumber":2,"data":{"Case Received Date":"2025-10-15","Policy No.":"000001","Sub Type 2":"testtest","Case Owner":"weizhou@deloittecn.com.cn","Priority":"High"},"originalData":"{\\\"Case Received Date\\\":\\\"2025-10-15\\\",\\\"Policy No.\\\":\\\"000001\\\",\\\"Sub Type 2\\\":\\\"testtest\\\",\\\"Case Owner\\\":\\\"weizhou@deloittecn.com.cn\\\",\\\"Priority\\\":\\\"High\\\"}"}]}';
        String fileName = 'callList.xlsx';
        String callType = 'Not_Specified';
        String subType = 'Not Specified';
        String targetObject = 'Cases';
        String channel = 'HongKong';

        System.Test.startTest();
        CRMGlobalExcelParserController.ProcessingResult result = CRMGlobalExcelParserController.parseExcelAndSaveRecords(
            recordsData,
            fileName,
            callType,
            targetObject,
            channel,
            subType
        );
        System.Test.stopTest();
        
        System.assertNotEquals(result, null, 'This is Syntax Error');
    }

    @IsTest
    private static void coverValidateJson(){
        String recordsData = '{"fileName":"callList.xlsx","uploadDate":"2025-10-18T04:57:59.900Z","totalSheets":1,"records":[{"sheetName":"Sheet1","rowNumber":2,"data":{"Case Received Date":"2025-10-15","Policy No.":"000001","Sub Type 2":"testtest","Case Owner":"weizhou@deloittecn.com.cn","Priority":"High"},"originalData":"{\\\"Case Received Date\\\":\\\"2025-10-15\\\",\\\"Policy No.\\\":\\\"000001\\\",\\\"Sub Type 2\\\":\\\"testtest\\\",\\\"Case Owner\\\":\\\"weizhou@deloittecn.com.cn\\\",\\\"Priority\\\":\\\"High\\\"}"}]}';
        String recordsDataTest = '{a}';

        System.Test.startTest();
        Boolean isBoolean = CRMGlobalExcelParserController.validateJson(
            recordsData
        );
        isBoolean = CRMGlobalExcelParserController.validateJson(
            recordsDataTest
        );
        System.Test.stopTest();
        
        System.assertNotEquals(isBoolean, null, 'This is Syntax Error');
    }


    
}