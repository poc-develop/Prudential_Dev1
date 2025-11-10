/**
 * @description       : Controller for Email Template Component
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-28
 * @last modified by  : hank
**/
public without sharing class CRMGlobalEmailTemplateController {
    
    /**
     * Search Lightning Email Templates
     * @param searchKey Search keyword (optional, returns all templates if empty)
     * @return List<EmailTemplate>
     */
    @AuraEnabled(cacheable=true)
    public static List<EmailTemplate> searchLightningEmailTemplates(String searchKey) {
        try {
            String query = 'SELECT Id, Name, DeveloperName, Subject, Description, ' +
                          'UIType, TemplateStyle, TemplateType ' +
                          'FROM EmailTemplate ' +
                          'WHERE UIType = \'SFX\' ' + 
                          'AND IsActive = true ';
            
            // Add search condition if search keyword exists
            if (String.isNotBlank(searchKey)) {
                String searchPattern = '%' + String.escapeSingleQuotes(searchKey) + '%';
                query += 'AND Name LIKE :searchPattern  ';
            }
            
            query += 'ORDER BY Name ASC LIMIT 100';
            List<EmailTemplate> templates = Database.query(query);
            
            return templates;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error searching Lightning Email Templates: ' + e.getMessage());
            throw new AuraHandledException('Failed to search templates: ' + e.getMessage());
        }
    }
    
    /**
     * Get template full content
     * @param templateId Email Template Id
     * @param recordId Record Id (optional, for merge fields)
     * @return Map<String, String> Contains 'content' and 'subject'
     */
    @AuraEnabled
    public static Map<String, String> getTemplateContent(String templateId, String recordId) {
        try {
            if (String.isBlank(templateId)) {
                throw new AuraHandledException('Template ID is required');
            }
            
            List<EmailTemplate> templates = [
                SELECT Id, Name, DeveloperName, Subject, 
                       Body, HtmlValue, Description,
                       UIType, TemplateStyle, TemplateType, RelatedEntityType
                FROM EmailTemplate
                WHERE Id = :templateId
                AND UIType = 'SFX'  // Ensure it's a Lightning Template
                LIMIT 1
            ];
            
            if (templates.isEmpty()) {
                throw new AuraHandledException('Lightning Email Template not found');
            }
            
            EmailTemplate template = templates[0];
            String htmlContent = template.HtmlValue;
            String subject = template.Subject != null ? template.Subject : '';
            
            // Extract text from HTML
            String textContent = extractTextFromHtml(htmlContent);
            
            // If recordId is provided, merge fields
            if (String.isNotBlank(recordId)) {
                Map<String, String> fieldPreservationMap = new Map<String, String>();
                SObject record = queryRecordWithFields(recordId, textContent, fieldPreservationMap);
                if (record != null) {
                    // Replace fields not on Case with placeholders to preserve them
                    String templateForMerge = preserveFieldsNotOnCase(textContent, fieldPreservationMap);
                    // Merge Case fields
                    templateForMerge = CRMGlobalTemplateMergeFieldService.mergeTemplate(templateForMerge, record, false);
                    // Restore preserved fields back to merge field format
                    textContent = restorePreservedFields(templateForMerge, fieldPreservationMap);
                }
            }
            
            Map<String, String> result = new Map<String, String>();
            result.put('content', textContent);
            result.put('subject', subject);
            result.put('templateName', template.Name);
            
            return result;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error fetching template content: ' + e.getMessage());
            throw new AuraHandledException('Failed to fetch template content: ' + e.getMessage());
        }
    }
    
    /**
     * Extract text content from HTML string while preserving line breaks and spacing
     * @param html HTML string
     * @return String Plain text content with preserved formatting
     */
    @TestVisible
    private static String extractTextFromHtml(String html) {
        if (String.isBlank(html)) {
            return '';
        }
        
        String text = html;
        
        // Convert block-level elements to line breaks before removing tags
        // Replace <br>, <br/>, <br /> with newline
        text = text.replaceAll('(?i)<br\\s*/?>', '\n');
        
        // Replace closing block elements with newline
        text = text.replaceAll('(?i)</(p|div|li|h[1-6]|tr)>', '\n');
        
        // Replace opening block elements (but keep text after them)
        text = text.replaceAll('(?i)<(p|div|li|h[1-6]|tr)[^>]*>', '');
        
        // Convert <pre> tags - preserve their content
        text = text.replaceAll('(?i)<pre[^>]*>', '');
        text = text.replaceAll('(?i)</pre>', '\n');
        
        // Remove remaining HTML tags (but preserve text content)
        text = text.replaceAll('<[^>]+>', '');
        
        // Decode common HTML entities
        text = text.replaceAll('&nbsp;', ' ');  // Non-breaking space -> regular space
        text = text.replaceAll('&lt;', '<');
        text = text.replaceAll('&gt;', '>');
        text = text.replaceAll('&amp;', '&');
        text = text.replaceAll('&quot;', '"');
        text = text.replaceAll('&#39;', '\'');
        text = text.replaceAll('&apos;', '\'');
        
        // Decode numeric entities for common characters
        text = text.replaceAll('&#160;', ' '); // Non-breaking space
        text = text.replaceAll('&#32;', ' ');  // Regular space
        
        // Normalize multiple spaces/tabs to single space (but keep newlines)
        // Replace multiple spaces and tabs with single space, but preserve newlines
        text = text.replaceAll('[ \\t]+', ' ');
        
        // Clean up: remove leading spaces from lines (handle each line separately)
        List<String> lines = text.split('\n');
        for (Integer i = 0; i < lines.size(); i++) {
            lines[i] = lines[i].trim();
        }
        text = String.join(lines, '\n');
        
        // Normalize multiple consecutive newlines to maximum 2 newlines
        text = text.replaceAll('\n{3,}', '\n\n');
        
        // Trim leading and trailing whitespace (including newlines)
        text = text.trim();
        
        return text;
    }
    
    /**
     * Check if current user can edit email content based on Profile
     * CSR Profile: cannot edit (readonly)
     * CS Supervisor or Admin: can edit
     * @return Boolean True if user can edit, false otherwise
     */
    @AuraEnabled(cacheable=true)
    public static Boolean canEditEmailContent() {
        try {
            // Get current user's Profile Name
            Id profileId = UserInfo.getProfileId();
            Profile userProfile = [SELECT Name FROM Profile WHERE Id = :profileId LIMIT 1];
            String profileName = userProfile.Name;
            
            System.debug('Current user profile: ' + profileName);
            
            // CSR cannot edit
            if (profileName == 'CSR') {
                return true;
            }
            
            // CS Supervisor and System Administrator (or other admin profiles) can edit
            // You can extend this list as needed
            if (profileName.contains('CS Supervisor') || 
                profileName == 'System Administrator' ||
                profileName.contains('管理员')) {
                return false;
            }
            
            // Default: cannot edit for safety
            return true;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error checking user edit permission: ' + e.getMessage());
            // Default to false on error for security
            return true;
        }
    }
    
    /**
     * Get Case field value (Contact Number)
     * @param recordId Case Record ID
     * @return String Contact Number field value
     */
    @AuraEnabled(cacheable=true)
    public static String getCaseContactNumber(String recordId) {
        try {
            if (String.isBlank(recordId)) {
                return '';
            }
            
            // Verify it's a Case record
            Id recId = Id.valueOf(recordId);
            String objectType = recId.getSObjectType().getDescribe().getName();
            
            if (objectType != 'Case') {
                System.debug(LoggingLevel.WARN, 'Record is not a Case: ' + objectType);
                return '';
            }
            
            List<Case> cases = [
                SELECT CRM_Global_ContactNumber__c
                FROM Case
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            if (cases.isEmpty()) {
                return '';
            }
            
            return cases[0].CRM_Global_ContactNumber__c != null ? cases[0].CRM_Global_ContactNumber__c : '';
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting Case contact number: ' + e.getMessage());
            return '';
        }
    }
    
    /**
     * Query record with required fields for merge
     * Only queries direct Case fields, ignores relationship fields (e.g., InsurancePolicy.FieldName)
     * Fields not found on Case will be preserved in fieldPreservationMap for later restoration
     * @param recordId Record ID
     * @param template Template content containing merge fields
     * @param fieldPreservationMap Map to store fields not on Case for preservation
     * @return SObject Record with fields
     */
    @TestVisible
    private static SObject queryRecordWithFields(String recordId, String template, Map<String, String> fieldPreservationMap) {
        try {
            // Get object type from recordId
            Id recId = Id.valueOf(recordId);
            String objectType = recId.getSObjectType().getDescribe().getName();
            if(objectType != 'Case') {
                return null;
            }
            
            // Extract merge fields from template
            Set<String> mergeFields = CRMGlobalTemplateMergeFieldService.getMergeFieldsFromTemplate(template);
            
            if (mergeFields.isEmpty()) {
                // If no merge fields, just query Id
                String query = 'SELECT Id FROM ' + objectType + ' WHERE Id = :recordId LIMIT 1';
                List<SObject> records = Database.query(query);
                return records.isEmpty() ? null : records[0];
            }
            
            // Get Case object describe to validate fields
            Schema.DescribeSObjectResult caseDescribe = Case.SObjectType.getDescribe();
            Map<String, Schema.SObjectField> caseFieldMap = caseDescribe.fields.getMap();
            
            // Only process direct Case fields (no '.'), ignore relationship fields
            Set<String> fieldsToQuery = new Set<String>{'Id'};
            for (String fieldPath : mergeFields) {
                // Skip relationship fields (e.g., InsurancePolicy.Name, Account.Name)
                // Only process direct Case fields
                if (!fieldPath.contains('.')) {
                    // Validate field exists on Case
                    if (caseFieldMap.containsKey(fieldPath.toLowerCase())) {
                        fieldsToQuery.add(fieldPath);
                    } else {
                        // Field not found on Case - preserve it to prevent merge from replacing it
                        System.debug(LoggingLevel.WARN, 'Field not found on Case, will preserve as merge field: ' + fieldPath);
                        String placeholder = '__PRESERVE_' + fieldPath.toUpperCase().replaceAll('[^A-Z0-9]', '_') + '__';
                        fieldPreservationMap.put(placeholder, fieldPath);
                    }
                } else {
                    // Relationship field (e.g., InsurancePolicy.Name) - preserve it
                    System.debug(LoggingLevel.INFO, 'Preserving relationship field (will be processed later): ' + fieldPath);
                    String placeholder = '__PRESERVE_' + fieldPath.toUpperCase().replaceAll('[^A-Z0-9]', '_') + '__';
                    fieldPreservationMap.put(placeholder, fieldPath);
                }
            }
            
            // Build dynamic query
            String query = 'SELECT ' + String.join(new List<String>(fieldsToQuery), ', ') + 
                          ' FROM ' + objectType + 
                          ' WHERE Id = :recordId LIMIT 1';
            
            System.debug('Query (Case fields only): ' + query);
            
            List<SObject> records = Database.query(query);
            return records.isEmpty() ? null : records[0];
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error querying record: ' + e.getMessage());
            // Return null if query fails, template will use unmerged fields
            return null;
        }
    }
    
    /**
     * Replace fields not on Case with special markers to preserve them during merge
     * Uses a marker format that won't be processed by mergeTemplate
     * @param template Template content
     * @param fieldPreservationMap Map of markers to original field paths
     * @return String Template with markers replacing fields to preserve
     */
    @TestVisible
    private static String preserveFieldsNotOnCase(String template, Map<String, String> fieldPreservationMap) {
        if (fieldPreservationMap == null || fieldPreservationMap.isEmpty()) {
            return template;
        }
        
        String preservedTemplate = template;
        for (String placeholder : fieldPreservationMap.keySet()) {
            String fieldPath = fieldPreservationMap.get(placeholder);
            // Replace {{{FieldPath}}} with special marker (not merge field format to avoid processing)
            // Use a format that we can reliably restore later
            String pattern = '\\{\\{\\{' + Pattern.quote(fieldPath) + '\\}\\}\\}';
            String replacement = '<!--PRESERVE_START:' + placeholder + ':PRESERVE_END-->';
            preservedTemplate = preservedTemplate.replaceAll(pattern, replacement);
        }
        
        return preservedTemplate;
    }
    
    /**
     * Restore preserved fields back to original merge field format
     * @param template Template content after merge (with markers)
     * @param fieldPreservationMap Map of markers to original field paths
     * @return String Template with restored merge fields
     */
    @TestVisible
    private static String restorePreservedFields(String template, Map<String, String> fieldPreservationMap) {
        if (fieldPreservationMap == null || fieldPreservationMap.isEmpty()) {
            return template;
        }
        
        String restoredTemplate = template;
        for (String placeholder : fieldPreservationMap.keySet()) {
            String fieldPath = fieldPreservationMap.get(placeholder);
            // Replace marker back with original merge field format
            String pattern = '<!--PRESERVE_START:' + Pattern.quote(placeholder) + ':PRESERVE_END-->';
            String replacement = '{{{' + fieldPath + '}}}';
            restoredTemplate = restoredTemplate.replaceAll(pattern, replacement);
        }
        
        return restoredTemplate;
    }
    
    /**
     * Merge Insurance Policy fields in template content
     * This method processes InsurancePolicy relationship fields (e.g., {{{InsurancePolicy.Name}}})
     * @param templateContent Template content with merge fields (already partially merged with Case fields)
     * @param insurancePolicyId Insurance Policy Record ID
     * @return String Template content with Insurance Policy fields merged
     */
    @AuraEnabled
    public static String mergeInsurancePolicyFields(String templateContent, String insurancePolicyId) {
        try {
            if (String.isBlank(templateContent)) {
                return templateContent;
            }
            
            if (String.isBlank(insurancePolicyId)) {
                // If no policy ID, return content as-is (InsurancePolicy fields will remain as merge fields)
                return templateContent;
            }
            
            
            // Extract merge fields from template
            Set<String> mergeFields = CRMGlobalTemplateMergeFieldService.getMergeFieldsFromTemplate(templateContent);
            
            if (mergeFields.isEmpty()) {
                return templateContent;
            }
            
            // Build query for InsurancePolicy with required fields
            Set<String> fieldsToQuery = new Set<String>{'Id'};
            fieldsToQuery.addAll(mergeFields);
            
            String query = 'SELECT ' + String.join(new List<String>(fieldsToQuery), ', ') + 
                          ' FROM InsurancePolicy ' +
                          ' WHERE Id = :insurancePolicyId LIMIT 1';
            
            System.debug('InsurancePolicy Query: ' + query);
            
            SObject policy = Database.query(query);
            
            if (policy == null) {
                System.debug(LoggingLevel.WARN, 'InsurancePolicy not found: ' + insurancePolicyId);
                return templateContent;
            }
            
            // Merge InsurancePolicy fields manually
            // String mergedContent = mergeInsurancePolicyFieldsManually(templateContent, policy, policyFields);
            String mergedContent = CRMGlobalTemplateMergeFieldService.mergeTemplate(templateContent, policy, false);
            
            return mergedContent;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error merging Insurance Policy fields: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
            // Return original content if merge fails
            return templateContent;
        }
    }
    

    @AuraEnabled
    public static Map<String, Object> sendSms(String recipientNumber, String templateContent, String recordId) {
        Map<String, Object> result = CRMGlobalSendSmsService.sendSms(recipientNumber, templateContent, recordId);
        
        return result;
    }
}