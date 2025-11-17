/**
 * @description       : Controller for creating a case reply
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-24
 * @last modified by  : hank
**/
public without sharing class CRMGlobalCreateCaseReplyController {
    @AuraEnabled
    public static Boolean createCaseReply(String caseId, String replyText) {
        List<RecordType> replyRecordTypes = [SELECT Id FROM RecordType WHERE SObjectType = 'CRM_Global_CaseAssociatedItem__c' AND DeveloperName = 'Reply'];
        try {
            CRM_Global_CaseAssociatedItem__c replyItem = new CRM_Global_CaseAssociatedItem__c(
                CRM_Global_Case__c = caseId,
                CRM_Global_CommentRemarks__c = replyText,
                RecordTypeId = replyRecordTypes[0].Id
            );
            System.debug('replyItem: ' + replyItem);
            insert replyItem;
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    @AuraEnabled
    public static void updateAESEquiryReply(String caseId){
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:CRM_PHKL_APIM_AES' + '/updateAESeEnquiry');
        request.setMethod('POST');
        Map<String, String> body = new Map<String, String>();
        body.put('usrId', 'npcrklcj');
        body.put('enquiryStatus', 'P');
        body.put('enquiryReply', 'Reply Content Here');
        body.put('wrapUpDt', '2025-06-10T00:00:00+08:00');
        body.put('wrapUpCategory', 'ICC(PS):DDA');
        body.put('wrapUpItem', 'DDA collection status/reject reason');
        String bodyString = JSON.serialize(body);
        System.debug('bodyString: ' + bodyString);
        request.setBody(bodyString);
        request.setTimeout(60000);
        HttpResponse response = http.send(request);
        System.debug('response: ' + response.getBody());
    }

    /**
     * Send email and replace custom placeholders in template
     * Supports two placeholder formats:
     * 1. {{{FieldName}}} - Get field value from record
     * 2. {CustomKey} - Get value from custom Map
     */
    @AuraEnabled
    public static Boolean sendEmailWithCustomMerge(
        String templateDeveloperName,
        List<String> toAddresses,
        Map<String, String> customReplacements
    ) {
        try {
            // 1. Get Email Template
            EmailTemplate template = getEmailTemplate(templateDeveloperName);
            if (template == null) {
                System.debug('Email template not found: ' + templateDeveloperName);
                return false;
            }
            
            // 2. Replace template content
            String subject = template.Subject;
            String htmlBody = template.HtmlValue;
            String textBody = template.Body;
            
            // Replace custom placeholders {CustomKey}
            if (customReplacements != null && !customReplacements.isEmpty()) {
                subject = replaceCustomPlaceholders(subject, customReplacements);
                htmlBody = replaceCustomPlaceholders(htmlBody, customReplacements);
                textBody = replaceCustomPlaceholders(textBody, customReplacements);
            }
            
            // Replace standard merge fields {{{FieldName}}}
            // Note: recordData variable is not defined in this method signature
            // This may need to be added as a parameter or retrieved differently
            
            // 3. Build and send email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            if (toAddresses != null && !toAddresses.isEmpty()) {
                email.setToAddresses(toAddresses);
            }
            
            email.setSubject(subject);
            email.setHtmlBody(htmlBody);
            email.setPlainTextBody(textBody);
            email.setSaveAsActivity(true);
            
            Messaging.SendEmailResult[] results = Messaging.sendEmail(
                new Messaging.SingleEmailMessage[] { email }
            );
            System.debug('results: ' + results);
            return results[0].isSuccess();
            
        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
            throw new AuraHandledException('Failed to send email: ' + e.getMessage());
        }
    }

    /**
     * Replace custom placeholders {Key} -> Value
     * Example: {Enquiry Type} -> "Technical Support"
     */
    private static String replaceCustomPlaceholders(String content, Map<String, String> replacements) {
        if (String.isBlank(content) || replacements == null || replacements.isEmpty()) {
            return content;
        }
        
        String result = content;
        for (String key : replacements.keySet()) {
            String placeholder = '{' + key + '}';
            String value = replacements.get(key);
            if (value == null) {
                value = '';
            }
            result = result.replace(placeholder, value);
        }
        
        return result;
    }
    
    /**
     * Get Email Template
     */
    private static EmailTemplate getEmailTemplate(String templateName) {
        List<EmailTemplate> templates = [
            SELECT Id, Name, DeveloperName, Subject, Body, HtmlValue 
            FROM EmailTemplate 
            WHERE DeveloperName = :templateName 
            OR Name = :templateName
            LIMIT 1
        ];
        
        return templates.isEmpty() ? null : templates[0];
    }
    
    /**
     * Get record data (dynamically query all fields)
     */
    @TestVisible
    private static SObject getRecordData(Id recordId) {
        if (recordId == null) {
            return null;
        }
        
        String objectType = recordId.getSObjectType().getDescribe().getName();
        
        // Get all fields of the object
        Map<String, Schema.SObjectField> fieldMap = 
            recordId.getSObjectType().getDescribe().fields.getMap();
        
        List<String> fields = new List<String>();
        for (String fieldName : fieldMap.keySet()) {
            if (fieldMap.get(fieldName).getDescribe().isAccessible()) {
                fields.add(fieldName);
            }
        }
        
        String query = 'SELECT ' + String.join(fields, ', ') + 
                       ' FROM ' + objectType + 
                       ' WHERE Id = :recordId LIMIT 1';
        
        List<SObject> records = Database.query(query);
        return records.isEmpty() ? null : records[0];
    }
}