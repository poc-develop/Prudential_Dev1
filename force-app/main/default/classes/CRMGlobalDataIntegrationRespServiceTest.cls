/**
 * @description       : Test class for CRMGlobalDataIntegrationRespService
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-10
 * @last modified by  : Franco
**/
@IsTest
private class CRMGlobalDataIntegrationRespServiceTest {

    @IsTest
    static void testConvertFieldValue_AllTypes() {
        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt();
        config.Boolean_True_Values__c = 'yes;1;y';
        config.Date_Format__c = 'YYYY-MM-dd';
        config.Datetime_Format__c = 'YYYY-MM-dd HH:mm:ss';
        CRMGlobalDataIntegrationConfigWrapper wrapper = new CRMGlobalDataIntegrationConfigWrapper(config, null);
        

        Schema.DescribeFieldResult boolField = Account.IsDeleted.getDescribe();
        Schema.DescribeFieldResult dateField = Account.PersonBirthdate.getDescribe();
        Schema.DescribeFieldResult intField = Account.NumberOfEmployees.getDescribe();
        Schema.DescribeFieldResult textField = Account.Name.getDescribe();

        // Boolean test
        Object result1 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, boolField, 'yes');
        System.assertEquals(true, result1);

        // Integer test
        Object result2 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, intField, 123);
        System.assertEquals(123, result2);

        // Double test
        Schema.DescribeFieldResult revenueField = Account.AnnualRevenue.getDescribe();
        Object result3 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, revenueField, '456.78');
        System.assertEquals(456.78, result3);

        // Date test
        Object result4 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, dateField, '2025-01-01');
        System.assertEquals(Date.valueOf('2025-01-01'), result4);

        // Text test
        Object result5 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, textField, 'Some text');
        System.assertEquals('Some text', result5);

        // Null value test
        Object result6 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, textField, null);
        System.assertEquals(null, result6);

        // Exception
        Object result7 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, dateField, 'invalid date');
        System.assertEquals(null, result7);
    }

    @IsTest
    static void testConvertFieldValue_DateFormats() {
        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt();
        CRMGlobalDataIntegrationConfigWrapper wrapper = new CRMGlobalDataIntegrationConfigWrapper(config, null);
        Schema.DescribeFieldResult dateField = Account.PersonBirthdate.getDescribe();

        // MM/dd/YYYY
        wrapper.config.Date_Format__c = 'MM/dd/YYYY';
        Object date1 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, dateField, '01/01/2025');
        System.assertEquals(Date.valueOf('2025-01-01'), date1);

        // dd/MM/YYYY
        wrapper.config.Date_Format__c = 'dd/MM/YYYY';
        Object date2 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, dateField, '01/01/2025');
        System.assertEquals(Date.valueOf('2025-01-01'), date2);

        // null
        wrapper.config.Date_Format__c = 'dd/MM/YYYY';
        Object date3 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, dateField, null);
        System.assertEquals(null, date3);
    }

    @IsTest
    static void testConvertFieldValue_DatetimeFormats() {
        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt();
        CRMGlobalDataIntegrationConfigWrapper wrapper = new CRMGlobalDataIntegrationConfigWrapper(config, null);
        Schema.DescribeFieldResult dateField = Account.CreatedDate.getDescribe();

        // YYYY-MM-dd HH:mm:ss
        wrapper.config.Datetime_Format__c = 'YYYY-MM-dd HH:mm:ss';
        Object dt1 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, dateField, '2024-10-01 12:30:00');
        System.assertEquals(Datetime.newInstance(2024,10,1,12,30,0), dt1);

        // MM/dd/YYYY HH:mm:ss
        wrapper.config.Datetime_Format__c = 'MM/dd/YYYY HH:mm:ss';
        Object dt2 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, dateField, '10/01/2024 12:30:00');
        System.assertEquals(Datetime.newInstance(2024,10,1,12,30,0), dt2);

        // dd/MM/YYYY HH:mm:ss with "T" separator
        wrapper.config.Datetime_Format__c = 'dd/MM/YYYY HH:mm:ss';
        Object dt3 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, dateField, '01/10/2024T12:30:00');
        System.assertEquals(Datetime.newInstance(2024,10,1,12,30,0), dt3);
    }

    // ====== Boolean parsing fallback ======
    @IsTest
    static void testParseBoolean_DefaultLogic() {
        CRM_Global_DataIntegration_Config__mdt config = new CRM_Global_DataIntegration_Config__mdt();
        CRMGlobalDataIntegrationConfigWrapper wrapper = new CRMGlobalDataIntegrationConfigWrapper(config, null);
        wrapper.config.Boolean_True_Values__c = null;
        Schema.DescribeFieldResult boolField = Account.IsDeleted.getDescribe();

        Object result1 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, boolField, 'true');
        Object result2 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, boolField, 'false');
        Object result3 = CRMGlobalDataIntegrationRespService.convertFieldValue(wrapper, boolField, null);

        System.assertEquals(true, result1);
        System.assertEquals(false, result2);
        System.assertEquals(null, result3);
    }

    // ====== getNestedValue Tests ======
    @IsTest
    static void testGetNestedValue_MapAndList() {
        Map<String, Object> data = new Map<String, Object>{
            'name' => 'Root',
            'child' => new Map<String, Object>{
                'value' => 'ChildValue',
                'list' => new List<Object>{
                    new Map<String, Object>{'subValue' => 'A'},
                    new Map<String, Object>{'subValue' => 'B'}
                }
            }
        };

        Object val1 = CRMGlobalDataIntegrationRespService.getNestedValue(data, 'child.value');
        System.assertEquals('ChildValue', val1);

        Object val2 = CRMGlobalDataIntegrationRespService.getNestedValue(data, 'child.list.0.subValue');
        System.assertEquals('A', val2);

        Object val3 = CRMGlobalDataIntegrationRespService.getNestedValue(data, '');
        System.assertEquals(data, val3);

        Object val4 = CRMGlobalDataIntegrationRespService.getNestedValue(data, 'child.nonexistent');
        System.assertEquals(null, val4);
    }

    @IsTest
    static void testGetNestedValue_ListFlatten() {
        List<Object> dataList = new List<Object>{
            new Map<String, Object>{'key' => 'A'},
            new Map<String, Object>{'key' => 'B'}
        };
        Object val = CRMGlobalDataIntegrationRespService.getNestedValue(dataList, 'key');
        System.assert(val instanceof List<Object>);
        System.assertEquals(2, ((List<Object>)val).size());
    }
}