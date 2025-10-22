public with sharing class DataIntegrationController {
    
    @AuraEnabled(cacheable=true)
    public static DataIntegration_Config__mdt getIntegrationConfig(String configName) {
        try {
            List<DataIntegration_Config__mdt> configs = [
                SELECT Id, MasterLabel, DeveloperName, Integration_Name__c, Is_Active__c, 
                       Named_Credential__c, DataCloud_Query__c, HTTP_Method__c, 
                       Parent_Object__c, Parent_ExId_Field__c,
                       Target_Object__c, Target_ExId_Field__c, Target_Parent_Field__c,
                       Request_Headers__c, Request_Body__c, Response_Format__c, Response_Root_Path__c,
                       Field_Mappings__c, Endpoint_Path__c, Success_Codes__c
                FROM DataIntegration_Config__mdt
                WHERE DeveloperName = :configName
                AND Is_Active__c = TRUE
                LIMIT 1
            ];
            
            if (configs.isEmpty()) {
                throw new AuraHandledException('Configuration not found');
            }
            
            return configs[0];
        } catch (Exception e) {
            throw new AuraHandledException('Configuration error: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String syncWithIntegration(String recordId, String configJson) {
        try {
            DataIntegration_Config__mdt config = (DataIntegration_Config__mdt) JSON.deserialize(
                configJson, DataIntegration_Config__mdt.class
            );
            
            if (!config.Is_Active__c) {
                return 'Sync is disabled in configuration';
            }
            
            validateConfig(config);

            SObject parentRecord = getParentRecord(config, recordId);
            String parentExId = (String)parentRecord.get(config.Parent_ExId_Field__c);

            // Process based on response type
            List<Map<String, Object>> recordsToProcess = new List<Map<String, Object>>();
            Object responseData = null;

            if (config.Integration_Type__c == 'Data_Cloud') {
                responseData = executeDataCloudQuery(config, parentExId);
            } else {
                HttpResponse response = callExternalApi(config, parentExId);
                responseData = parseApiResponse(config, response);
            }

            responseData = getNestedValue(responseData, config.Response_Root_Path__c);

            if (responseData instanceOf List<Object>) {
                // Handle List<Map<String, Object>> case
                for (Object item : (List<Object>)responseData) {
                    if (item instanceof Map<String, Object>) {
                        recordsToProcess.add((Map<String, Object>)item);
                    }
                }
            }
            else if (responseData instanceOf Map<String, Object>) {
                // Handle single Map<String, Object> case
                recordsToProcess.add((Map<String, Object>)responseData);
            }
            
            // Process and upsert records
            UpsertResultWrapper result = processAndUpsertRecords(recordsToProcess, config, recordId);

            if (result.failureCount > 0) {
                throw new AuraHandledException(
                    'Sync failed: ' + String.join(result.failureMessages, ', ')
                );
            }

            return 'Sync completed successfully: ' + result.successCount + ' of ' + result.processedCount + ' records synced';
        } catch (Exception e) {
            throw new AuraHandledException('Sync failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String updateWithIntegration(String recordId, String configJson) {
        try {
            DataIntegration_Config__mdt config = (DataIntegration_Config__mdt) JSON.deserialize(
                configJson, DataIntegration_Config__mdt.class
            );
            
            if (!config.Is_Active__c) {
                return 'Sync is disabled in configuration';
            }
            
            validateConfig(config);

            SObject record = getRecord(config, recordId);

            // Process based on response type
            HttpResponse response = callExternalApiUpdate(config, record);
            Object responseData = parseApiResponse(config, response);

            if (responseData instanceOf Map<String, Object>) {
                Map<String, Object> responseResult = (Map<String, Object>)responseData;

                if (responseResult.containsKey('error')) {
                    throw new AuraHandledException('Update failed: ' + responseResult.get('error'));
                }
            }
            else {
                throw new AuraHandledException('Update failed: ' + (String)responseData);
            }

            return 'Update completed successfully ';
        } catch (Exception e) {
            throw new AuraHandledException('Update failed: ' + e.getMessage());
        }
    }

    private static UpsertResultWrapper processAndUpsertRecords(
        List<Map<String, Object>> sourceData, 
        DataIntegration_Config__mdt config, 
        String recordId
    ) {
        List<SObject> recordsToUpsert = new List<SObject>();
        List<String> failureMessages = new List<String>();
        Integer successCount = 0;
        Integer failureCount = 0;
        
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(config.Target_Object__c);
        Schema.SObjectField externalKey = targetType.getDescribe().fields.getMap().get(config.Target_ExId_Field__c);

        Map<String, String> fieldMappings = (Map<String, String>) JSON.deserialize(
            config.Field_Mappings__c, Map<String, String>.class
        );

        for (Object sourceRecord : sourceData) {
            try {
                SObject record = targetType.newSObject();
                
                for (String sourceField : fieldMappings.keySet()) {
                    String targetField = fieldMappings.get(sourceField);
                    Object value = getNestedValue(sourceRecord, sourceField);
                    
                    if (value != null && isFieldUpdateable(record.getSObjectType().getDescribe().getName(), targetField)) {
                        record.put(targetField, convertFieldValue(
                            record.getSObjectType().getDescribe().fields.getMap().get(targetField).getDescribe(),
                            value
                        ));
                    }

                    // Set parent relationship if needed
                    if (String.isNotBlank(config.Target_Parent_Field__c)) {
                        record.put(config.Target_Parent_Field__c, recordId);
                    }
                }
                
                recordsToUpsert.add(record);
            } catch (Exception e) {
                failureCount++;
                failureMessages.add('Error processing record: ' + e.getMessage());
            }
        }
        
        // Perform upsert
        Database.UpsertResult[] results = Database.upsert(recordsToUpsert, externalKey, false);
        
        // Process results
        for (Integer i = 0; i < results.size(); i++) {
            Database.UpsertResult result = results[i];
            if (result.isSuccess()) {
                successCount++;
            } else {
                failureCount++;
                for (Database.Error err : result.getErrors()) {
                    failureMessages.add('Record ' + i + ' error: ' + err.getMessage());
                }
            }
        }
        
        return new UpsertResultWrapper(
            sourceData.size(),
            successCount,
            failureCount,
            failureMessages
        );
    }

    private static Object getFieldValue(SObject record, String fieldPath) {
        if (record == null || String.isBlank(fieldPath)) {
            return null;
        }

        List<String> fieldParts = fieldPath.split('\\.');

        Object currentValue = record;

        // Traverse the field path
        for (String field : fieldParts) {
            if (currentValue instanceof SObject) {
                // If the current value is an SObject, get the next field
                currentValue = ((SObject) currentValue).getSObject(field);
            } else if (currentValue != null) {
                // If the current value is not an SObject, get the primitive field
                currentValue = ((SObject) currentValue).get(field);
            } else {
                // If the current value is null, stop traversing
                return null;
            }
        }

        return currentValue;
    }
    
    private static void validateConfig(DataIntegration_Config__mdt config) {
        if (String.isBlank(config.Parent_Object__c)) {
            throw new IntegrationException('Parent Object is required');
        }
        
        if (String.isBlank(config.Parent_ExId_Field__c)) {
            throw new IntegrationException('Parent ExId Field is required');
        }

        if (String.isBlank(config.Target_Object__c)) {
            throw new IntegrationException('Parent Object is required');
        }
        
        if (String.isBlank(config.Target_ExId_Field__c)) {
            throw new IntegrationException('Parent ExId Field is required');
        }
        
        if (String.isBlank(config.Field_Mappings__c) && String.isBlank(config.Request_Body__c)) {
            throw new IntegrationException('Either Field Mappings and Request Body are required');
        }
        
        if (config.Integration_Type__c == 'Data_Cloud' && String.isBlank(config.DataCloud_Query__c)) {
            throw new IntegrationException('Data Cloud Query is required for Data Cloud integrations');
        }
    }
    
    private static SObject getParentRecord(DataIntegration_Config__mdt config, String recordId) {
        String query = 'SELECT Id, ' + config.Parent_ExId_Field__c;
        query += ' FROM ' + config.Parent_Object__c + 
                 ' WHERE Id = :recordId';
        
        List<SObject> records = Database.query(query);
        return records[0];
    }

    private static SObject getRecord(DataIntegration_Config__mdt config, String recordId) {
        String query = 'SELECT Id';

        Map<String, String> fieldMappings = (Map<String, String>) JSON.deserialize(
            config.Request_Body__c, Map<String, String>.class
        );
        
        for (String key : fieldMappings.keySet()) {
            if (isFieldAccessible(config.Target_Object__c, key)) {
                query += ', ' + key;
            }
        }

        query += ' FROM ' + config.Parent_Object__c + 
                 ' WHERE Id = :recordId';
        
        List<SObject> records = Database.query(query);
        return records[0];
    }
    
    private static Object executeDataCloudQuery(DataIntegration_Config__mdt config, String recordId) {
        // Replace the recordId placeholder in the query
        String query = config.DataCloud_Query__c.replace('{RECORD_ID}', recordId);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + config.Named_Credential__c + '/query');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(JSON.serialize(new Map<String, String>{
            'query' => query
        }));
        req.setTimeout(getTimeout(config));
        
        HttpResponse res = new Http().send(req);
        
        if (!isSuccessResponse(config, res.getStatusCode())) {
            throw new IntegrationException('Data Cloud API error: ' + res.getStatusCode() + ' - ' + res.getStatus());
        }
        
        Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return responseData.get('records');
    }
    
    private static HttpResponse callExternalApi(DataIntegration_Config__mdt config, String recordId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(getFullEndpoint(config, recordId));
        req.setMethod(config.HTTP_Method__c);
        req.setTimeout(getTimeout(config));
        
        setRequestHeaders(req, config);
        
        if (String.isNotBlank(config.Request_Body__c)) {
            req.setBody(prepareRequestBody(config, recordId));
        }
        
        return new Http().send(req);
    }

    private static HttpResponse callExternalApiUpdate(DataIntegration_Config__mdt config, SObject record) {
        HttpRequest req = new HttpRequest();

        String parentExId = (String)record.get(config.Parent_ExId_Field__c);

        req.setEndpoint(getFullEndpoint(config, parentExId));
        req.setMethod(config.HTTP_Method__c);
        req.setTimeout(getTimeout(config));
        
        setRequestHeaders(req, config);
        
        if (String.isNotBlank(config.Request_Body__c)) {
            req.setBody(prepareRequestBody(config, record));
        }
        System.Debug(req);
        System.Debug(req.getBody());
        System.Debug(req.getHeader('Accept'));
        return new Http().send(req);
    }
    
    private static String getFullEndpoint(DataIntegration_Config__mdt config, String recordId) {
        String endpoint = 'callout:' + config.Named_Credential__c;
        
        if (String.isNotBlank(config.Endpoint_Path__c)) {
            endpoint += config.Endpoint_Path__c.replace('{RECORD_ID}', recordId);
        }
        
        if (String.isNotBlank(config.Request_Params__c)) {
            Map<String, String> params = (Map<String, String>) JSON.deserialize(
                config.Request_Params__c, Map<String, String>.class
            );
            
            if (!params.isEmpty()) {
                endpoint += endpoint.contains('?') ? '&' : '?';
                endpoint += String.join(
                    new List<String>(getUrlEncodedParams(params)), '&'
                );
            }
        }
        
        return endpoint;
    }
    
    private static Object parseApiResponse(DataIntegration_Config__mdt config, HttpResponse response) {
        if (config.Response_Format__c == 'XML') {
            Dom.Document doc = response.getBodyDocument();
            throw new IntegrationException('XML response format not yet implemented');
        }

        System.debug(response.getBody());
        return JSON.deserializeUntyped(response.getBody());
    }
    
    private static Object getNestedValue(Object data, String fieldPath) {
        if (String.isBlank(fieldPath)) {
            return data;
        }

        String[] pathParts = fieldPath.split('\\.');
        Object current = data;
        
        for (String part : pathParts) {
            if (current instanceof Map<String, Object>) {
                current = ((Map<String, Object>)current).get(part);
            } else {
                return null;
            }
        }
        return current;
    }
    
    private static Object convertFieldValue(Schema.DescribeFieldResult fieldDesc, Object value) {
        if (value == null) return null;
        
        try {
            switch on fieldDesc.getType() {
                when BOOLEAN { return Boolean.valueOf(value); }
                when DATE { return Date.valueOf(String.valueOf(value)); }
                when DATETIME { return DateTime.valueOf(String.valueOf(value)); }
                when DOUBLE, CURRENCY, PERCENT { return Double.valueOf(value); }
                when INTEGER { return Integer.valueOf(value); }
                when else { return String.valueOf(value); }
            }
        } catch (Exception e) {
            System.debug('Error converting value: ' + e.getMessage());
            return null;
        }
    }
    
    private static Boolean isFieldAccessible(String objectName, String fieldName) {
        Schema.DescribeSObjectResult objDesc = Schema.describeSObjects(new List<String>{objectName})[0];
        Map<String, Schema.SObjectField> fieldMap = objDesc.fields.getMap();
        return fieldMap.containsKey(fieldName) && fieldMap.get(fieldName).getDescribe().isAccessible();
    }
    
    private static Boolean isFieldUpdateable(String objectName, String fieldName) {
        Schema.DescribeSObjectResult objDesc = Schema.describeSObjects(new List<String>{objectName})[0];
        Map<String, Schema.SObjectField> fieldMap = objDesc.fields.getMap();
        return fieldMap.containsKey(fieldName) && fieldMap.get(fieldName).getDescribe().isUpdateable();
    }
    
    private static List<String> getUrlEncodedParams(Map<String, String> params) {
        List<String> encodedParams = new List<String>();
        for (String key : params.keySet()) {
            encodedParams.add(EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(params.get(key), 'UTF-8'));
        }
        return encodedParams;
    }
    
    private static Integer getTimeout(DataIntegration_Config__mdt config) {
        return config.Timeout__c != null ? Integer.valueOf(config.Timeout__c) : 10000;
    }
    
    private static void setRequestHeaders(HttpRequest req, DataIntegration_Config__mdt config) {
        if (String.isNotBlank(config.Request_Headers__c)) {
            Map<String, String> headers = (Map<String, String>) JSON.deserialize(
                config.Request_Headers__c, Map<String, String>.class
            );
            for (String header : headers.keySet()) {
                req.setHeader(header, headers.get(header));
            }
        }
    }
    
    private static String prepareRequestBody(DataIntegration_Config__mdt config, String recordId) {
        return config.Request_Body__c.replace('{RECORD_ID}', recordId);
    }

    private static String prepareRequestBody(DataIntegration_Config__mdt config, SObject record) {
        Map<String, Object> requestBodyMap = new Map<String, Object>();
    
        Map<String, String> fieldMappings = (Map<String, String>) JSON.deserialize(
            config.Request_Body__c, Map<String, String>.class
        );

        if (fieldMappings != null && !fieldMappings.isEmpty()) {
            for (String sourceField : fieldMappings.keySet()) {
                String targetField = fieldMappings.get(sourceField);
                requestBodyMap.put(targetField, record.get(sourceField));
            }
        }

        return JSON.serialize(requestBodyMap);
    }
    
    private static Boolean isSuccessResponse(DataIntegration_Config__mdt config, Integer statusCode) {
        if (String.isBlank(config.Success_Codes__c)) {
            return statusCode >= 200 && statusCode < 300;
        }
        
        Set<Integer> successCodes = new Set<Integer>();
        for (String code : config.Success_Codes__c.split(',')) {
            successCodes.add(Integer.valueOf(code.trim()));
        }
        
        return successCodes.contains(statusCode);
    }
    
    private class UpsertResultWrapper {
        public Integer processedCount;
        public Integer successCount;
        public Integer failureCount;
        public List<String> failureMessages;
        
        public UpsertResultWrapper(Integer processedCount, Integer successCount, Integer failureCount, List<String> failureMessages) {
            this.processedCount = processedCount;
            this.successCount = successCount;
            this.failureCount = failureCount;
            this.failureMessages = failureMessages;
        }
    }

    public class IntegrationException extends Exception {}
}