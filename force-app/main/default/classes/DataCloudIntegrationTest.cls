/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 08-22-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class DataCloudIntegrationTest {
    public DataCloudIntegrationTest() {
        System.debug(LoggingLevel.INFO, '=== DataCloudIntegrationTest constructor started ===');
        
        ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
        input.sql = 'select ssot__InsurancePolicyNumber__c from ssot__InsurancePolicy__dlm ';
        System.debug(LoggingLevel.INFO, 'SQL Query to be executed: ' + input.sql);
        List<ssot__InsurancePolicy__dlm> insurancePolicies = [select ssot__InsurancePolicyNumber__c from ssot__InsurancePolicy__dlm ];
        try {
            System.debug(LoggingLevel.INFO, 'List<ssot__InsurancePolicy__dlm> ' + insurancePolicies);
            System.debug(LoggingLevel.INFO, 'insurancePolicies-JSON ' + JSON.serialize(insurancePolicies));
            if (insurancePolicies != null) {
                for (Integer i = 0; i < 5; i++) {
                        System.debug(LoggingLevel.INFO, 'insurancePolicie ' + i + ': ' + insurancePolicies[i]);
                        System.debug(LoggingLevel.INFO, 'insurancePolicie ' + i + ': ' + JSON.serialize(insurancePolicies[i]));
                    }
            }
            System.debug(LoggingLevel.INFO, 'Executing CDP Query...');
            ConnectApi.CdpQueryOutputV2 out = ConnectApi.CdpQuery.queryAnsiSqlV2(input);
            
            System.debug(LoggingLevel.INFO, 'Query executed successfully');
            System.debug(LoggingLevel.INFO, 'Full output object: ' + out);
            
            if (out != null) {
                System.debug(LoggingLevel.INFO, 'Output data: ' + out.data);
                
                if (out.data != null) {
                    System.debug(LoggingLevel.INFO, 'Data size: ' + out.data.size());
                    // 如果数据不为空，打印前几条记录
                    Integer maxRecords = Math.min(5, out.data.size());
                    for (Integer i = 0; i < maxRecords; i++) {
                        System.debug(LoggingLevel.INFO, 'Record ' + i + ': ' + out.data[i]);
                    }
                } else {
                    System.debug(LoggingLevel.WARN, 'Query returned null data');
                }
            } else {
                System.debug(LoggingLevel.WARN, 'Query returned null output');
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Unexpected Exception occurred: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Exception type: ' + e.getTypeName());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        }
        
        System.debug(LoggingLevel.INFO, '=== DataCloudIntegrationTest constructor ended ===');
    }
}