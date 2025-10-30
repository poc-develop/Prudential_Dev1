/**
 * @description       : Controller for creating a case reply
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-24
 * @last modified by  : hank
**/
public without sharing class CRMPHKLCreateCaseReplyController {
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
     * 发送邮件并替换模板中的自定义占位符
     * 支持两种占位符格式:
     * 1. {{{FieldName}}} - 从记录中获取字段值
     * 2. {CustomKey} - 从自定义 Map 中获取值
     */
    @AuraEnabled
    public static Boolean sendEmailWithCustomMerge(
        String templateDeveloperName,
        Id targetObjectId,
        Id whatId,
        List<String> toAddresses,
        Map<String, String> customReplacements
    ) {
        try {
            // 1. 获取 Email Template
            EmailTemplate template = getEmailTemplate(templateDeveloperName);
            if (template == null) {
                System.debug('Email template not found: ' + templateDeveloperName);
                return false;
            }
            
            // 2. 获取记录数据（用于标准合并字段）
            SObject recordData = null;
            if (whatId != null) {
                recordData = getRecordData(whatId);
                System.debug('recordData: ' + recordData);
            }
            
            // 3. 替换模板内容
            String subject = template.Subject;
            String htmlBody = template.HtmlValue;
            String textBody = template.Body;
            
            // 替换自定义占位符 {CustomKey}
            if (customReplacements != null && !customReplacements.isEmpty()) {
                subject = replaceCustomPlaceholders(subject, customReplacements);
                htmlBody = replaceCustomPlaceholders(htmlBody, customReplacements);
                textBody = replaceCustomPlaceholders(textBody, customReplacements);
            }
            
            // 替换标准合并字段 {{{FieldName}}}
            if (recordData != null) {
                textBody = CRMGlobalTemplateMergeFieldService.mergeTemplate(textBody, recordData, false);
            }
            
            // 4. 构建并发送邮件
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            if (toAddresses != null && !toAddresses.isEmpty()) {
                email.setToAddresses(toAddresses);
            } else if (targetObjectId != null) {
                // email.setTargetObjectId(targetObjectId);
            }
            
            email.setSubject(subject);
            email.setHtmlBody(htmlBody);
            email.setPlainTextBody(textBody);
            email.setSaveAsActivity(true);
            
            // if (whatId != null) {
            //     email.setWhatId(whatId);
            // }
            
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
     * 替换自定义占位符 {Key} -> Value
     * 例如: {Enquiry Type} -> "Technical Support"
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
     * 获取 Email Template
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
     * 获取记录数据（动态查询所有字段）
     */
    private static SObject getRecordData(Id recordId) {
        if (recordId == null) {
            return null;
        }
        
        String objectType = recordId.getSObjectType().getDescribe().getName();
        
        // 获取对象的所有字段
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