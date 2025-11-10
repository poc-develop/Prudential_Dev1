/**
 * @description       : Service class to handle the response from the CRM Global Data Integration process
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-25
 * @last modified by  : Franco
**/
@SuppressWarnings('PMD')
public with sharing class CRMGlobalDataIntegrationRespService {

    /**
     * @description Convert a field value to the correct type
     * @param configWrapper 
     * @param fieldDesc 
     * @param value 
     * @return  `Object`
     */
    public static Object convertFieldValue(CRMGlobalDataIntegrationConfigWrapper configWrapper, Schema.DescribeFieldResult fieldDesc, Object value) {
        if (value == null) {
            return null;
        }
        Schema.DisplayType fieldType = fieldDesc.getType();
        System.debug(LoggingLevel.INFO, 'Converting field value: ' + fieldDesc.getLabel() + ' (' + fieldType + ')');
        try {
            switch on fieldType {
                when BOOLEAN {
                    return parseBooleanValue(configWrapper, value);
                }
                when DATE { 
                    return parseDateValue(configWrapper, value);
                }
                when DATETIME { 
                    return parseDatetimeValue(configWrapper, value);
                }
                when INTEGER {
                    return Integer.valueOf(value);
                }
                when DOUBLE, CURRENCY, PERCENT {
                    if(String.valueOf(value) == '') {
                        return null;
                    }
                    return Double.valueOf(value);
                }
                when else {
                    return String.valueOf(value);
                }
            }
        } catch (Exception e) {
            String errorMessage = 'Error converting value: [' + String.valueOf(value) + '] for field: [' + fieldDesc.getName() + '] ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, errorMessage);
            CRMGlobalLogManager.addApexErrorLog(errorMessage, e);
            return null;
        }
    }

    /**
     * @description Parse a boolean value
     * @param configWrapper 
     * @param value 
     * @return  `Boolean`
     */
    private static Boolean parseBooleanValue(CRMGlobalDataIntegrationConfigWrapper configWrapper, Object value) {
        if (value == null) {
            return false;
        }
        String booleanTrueValues = configWrapper.config.Boolean_True_Values__c;
        if(String.isNotBlank(booleanTrueValues)) {
            List<String> booleanTrueValuesArr = booleanTrueValues.toLowerCase().split(';');
            booleanTrueValuesArr.add('true');
            String valueStr = String.valueOf(value);
            return booleanTrueValuesArr.contains(valueStr.toLowerCase());
        } else {
            return Boolean.valueOf(value);
        }
    }

    /**
     * @description Parse a date value
     * @param configWrapper 
     * @param value 
     * @return  `Date`
     */
    private static Date parseDateValue(CRMGlobalDataIntegrationConfigWrapper configWrapper, Object value) {
        if (value == null || String.valueOf(value) == '') {
            return null;
        }
        String dateFormat = configWrapper.config.Date_Format__c;
        if(dateFormat == null || dateFormat == 'YYYY-MM-dd') {
            return Date.valueOf(String.valueOf(value));
        } else if(dateFormat == 'MM/dd/YYYY') {
            String[] dateArr = String.valueOf(value).split('/');
            return Date.valueOf(dateArr[2] + '-' + dateArr[0] + '-' + dateArr[1]);
        } else if(dateFormat == 'dd/MM/YYYY') {
            String[] dateArr = String.valueOf(value).split('/');
            return Date.valueOf(dateArr[2] + '-' + dateArr[1] + '-' + dateArr[0]);
        }
        return null;
    }

    /**
     * @description Parse a datetime value
     * @param configWrapper 
     * @param value 
     * @return  `Datetime`
     */
    private static Datetime parseDatetimeValue(CRMGlobalDataIntegrationConfigWrapper configWrapper, Object value) {
        if (value == null || String.valueOf(value) == '') {
            return null;
        }
        String valueStr = String.valueOf(value);
        String separator = valueStr.contains('T') ? 'T' : ' ';
        String datetimeFormat = configWrapper.config.Datetime_Format__c;
        if(datetimeFormat == null || datetimeFormat == 'YYYY-MM-dd HH:mm:ss') {
            String[] datetimeArr = valueStr.split(separator);
            String timePart = datetimeArr.size() > 1 ? datetimeArr[1] : '00:00:00';
            return Datetime.valueOf(datetimeArr[0] + ' ' + timePart);
        } else if(datetimeFormat == 'MM/dd/YYYY HH:mm:ss') {
            String[] datetimeArr = valueStr.split(separator);
            String[] dateArr = datetimeArr[0].split('/');
            String timePart = datetimeArr.size() > 1 ? datetimeArr[1] : '00:00:00';
            return Datetime.valueOf(dateArr[2] + '-' + dateArr[0] + '-' + dateArr[1] + ' ' + timePart);
        } else if(datetimeFormat == 'dd/MM/YYYY HH:mm:ss') {
            String[] datetimeArr = valueStr.split(separator);
            String[] dateArr = datetimeArr[0].split('/');
            String timePart = datetimeArr.size() > 1 ? datetimeArr[1] : '00:00:00';
            return Datetime.valueOf(dateArr[2] + '-' + dateArr[1] + '-' + dateArr[0] + ' ' + timePart);
        }
        return null;
    }

    /**
     * @description Get a nested value from a data object
     * @param data data object
     * @param fieldPath fieldPath to the nested value. eg. 'field1.field2.field3' or 'field1.0.field2'
     * @return  `Object`
     */
    public static Object getNestedValue(Object data, String fieldPath) {
        if (String.isBlank(fieldPath)) {
            return data;
        }
        String[] pathParts = fieldPath.split('\\.');
        return getNestedValueRecursive(data, pathParts, 0);
    }

    /**
     * @description Get a nested value from a data object recursively
     * @param data data object
     * @param pathParts  path to the nested value. eg. 'field1.field2.field3' or 'field1.0.field2'
     * @param index  current index in the pathParts array
     * @return  `Object`
     */
    private static Object getNestedValueRecursive(Object data, String[] pathParts, Integer index) {
        if (index >= pathParts.size()) {
            return data;
        }
        
        String currentPart = pathParts[index];
        
        // Handle Map objects
        if (data instanceof Map<String, Object>) {
            Map<String, Object> dataMap = (Map<String, Object>)data;
            if (dataMap.containsKey(currentPart)) {
                return getNestedValueRecursive(dataMap.get(currentPart), pathParts, index + 1);
            } else {
                // Key not found
                return null;
            }
        }
        // Handle List objects
        else if (data instanceof List<Object>) {
            List<Object> dataList = (List<Object>)data;
            try {
                // Try to parse as index
                Integer listIndex = Integer.valueOf(currentPart);
                if (listIndex >= 0 && listIndex < dataList.size()) {
                    return getNestedValueRecursive(dataList[listIndex], pathParts, index + 1);
                } else {
                    // Index out of bounds
                    return null;
                }
            } catch (Exception e) {
                // currentPart is not a number, so we need to apply the remaining path to each item in the list
                List<Object> results = new List<Object>();
                for (Object item : dataList) {
                    Object result = getNestedValueRecursive(item, pathParts, index);
                    if (result != null) {
                        if (result instanceof List<Object>) {
                            // Flatten nested lists
                            results.addAll((List<Object>)result);
                        } else {
                            results.add(result);
                        }
                    }
                }
                return results;
            }
        }
        // Handle primitive or other object types
        else {
            return null;
        }
    }
}