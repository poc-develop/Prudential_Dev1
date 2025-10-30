/**
 * @description       : Utility class to handle template merge fields
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-23
 * @last modified by  : Franco
**/
public with sharing class CRMGlobalTemplateMergeFieldService {

    // Match {{{FieldName}}} or {{{RelationshipName.FieldName}}}, support one level of relattionship only
    private static final String MERGE_FIELD_PATTERN = '\\{\\{\\{([^{}]+(?:\\.[^{}]+)?)\\}\\}\\}';

    /**
     * @description       : Check if a template string contains merge fields
     * @param template    : The template string to check
     * @return Boolean    : True if the template contains merge fields, false otherwise
     */
    public static Boolean hasMergeFields(String template) {
        return String.isNotBlank(template) && template.contains('{{{') && template.contains('}}}');
    }

    /**
     * @description        : Extract merge fields from a template string
     * @param template     : The template string containing merge fields
     * @return Set<String> : A set of unique merge field names
     */
    public static Set<String> getMergeFieldsFromTemplate(String template) {
        Set<String> fields = new Set<String>();
        if (String.isBlank(template) || !template.contains('{{{')) {
            System.debug(LoggingLevel.INFO, 'No merge fields found or the template is blank');
            return fields;
        }
        Pattern regex = Pattern.compile(MERGE_FIELD_PATTERN);
        Matcher matcher = regex.matcher(template);
        while (matcher.find()) {            
            fields.add(matcher.group(1));
        }
        return fields;
    }

    /**
     * @description         : Replaces merge fields in template with values from record
     * @param template      : template with merge fields
     * @param record        : record to get values from
     * @param needUrlEncode : if true, values will be url encoded
     * @return String       : template with replaced merge fields
     */
    public static String mergeTemplate(String template, SObject record, Boolean needUrlEncode) {
        if (String.isBlank(template) || record == null || !template.contains('{{{')) {
            System.debug(LoggingLevel.INFO, 'No merge fields found or the template is blank');
            return template;
        }
        
        Pattern regex = Pattern.compile(MERGE_FIELD_PATTERN);
        Matcher matcher = regex.matcher(template);
        
        String result = template;
        while (matcher.find()) {
            String fullMatch = matcher.group(0);   // e.g. "{{{Contact.Name}}}" or "{{{Name}}}"
            String fieldPath = matcher.group(1);   // e.g. "Name" or "Contact.Name"
            
            String replacement = resolveFieldValue(record, fieldPath);
            if (replacement == null) {
                replacement = '';
            }
            if(needUrlEncode) {
                replacement = EncodingUtil.urlEncode(replacement, 'UTF-8');
            }
            result = result.replace(fullMatch, replacement);
        }
        return result;
    }
    
    /**
     * @description         : Resolves the value of a field path on a record
     * @param record        : The record to get the value from
     * @param fieldPath     : The field path to resolve (e.g. "Name" or "Contact.Name")
     * @return String       : The field value as a string, or null if not found
     */
    // private static String resolveFieldValue(SObject record, String fieldPath) {
    //     if (record == null || String.isBlank(fieldPath)) {
    //         return null;
    //     }
        
    //     if (fieldPath.contains('.')) {
    //         // Handle RelationshipName.FieldName
    //         List<String> parts = fieldPath.split('\\.');
    //         String relationshipName = parts[0];
    //         String fieldName = parts[1];
            
    //         SObject related = record.getSObject(relationshipName);
    //         if (related != null) {
    //             Object val = related.get(fieldName);
    //             return convertToStringIfNotNull(val);
    //         }
    //         return null;
    //     } else {
    //         Object val = record.get(fieldPath);
    //         return convertToStringIfNotNull(val);
    //     }
    // }

    private static String resolveFieldValue(SObject record, String fieldPath) {
        if (record == null || String.isBlank(fieldPath)) {
            return null;
        }

        List<String> parts = fieldPath.split('\\.');
        SObject currentRecord = record;
        Object currentValue;

        for (Integer i = 0; i < parts.size(); i++) {
            String part = parts[i];

            if (i == parts.size() - 1) {
                currentValue = currentRecord.get(part);
                return convertToStringIfNotNull(currentValue);
            } else {
                currentRecord = currentRecord.getSObject(part);
                if (currentRecord == null) {
                    return null;
                }
            }
        }

        return null;
    }

    /**
     * @description       : Convert value to String if not null
     * @param value       : The value to convert
     * @return  `String`  : The string representation of the value, or null if value is null
     */
    private static String convertToStringIfNotNull(Object value) {
        return (value == null) ? null : String.valueOf(value);
    }
}