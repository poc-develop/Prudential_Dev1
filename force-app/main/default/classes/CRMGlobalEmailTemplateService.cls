/**
 * @description       : Service for Email Template with custom merge fields
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-28
 * @last modified by  : hank
**/
public class CRMGlobalEmailTemplateService {
    
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
                subject = CRMGlobalTemplateMergeFieldService.mergeTemplate(subject, recordData, false);
                htmlBody = CRMGlobalTemplateMergeFieldService.mergeTemplate(htmlBody, recordData, false);
                textBody = CRMGlobalTemplateMergeFieldService.mergeTemplate(textBody, recordData, false);
            }
            
            // 4. 构建并发送邮件
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            if (toAddresses != null && !toAddresses.isEmpty()) {
                email.setToAddresses(toAddresses);
            } else if (targetObjectId != null) {
                email.setTargetObjectId(targetObjectId);
            }
            
            email.setSubject(subject);
            email.setHtmlBody(htmlBody);
            email.setPlainTextBody(textBody);
            email.setSaveAsActivity(true);
            
            if (whatId != null) {
                email.setWhatId(whatId);
            }
            
            Messaging.SendEmailResult[] results = Messaging.sendEmail(
                new Messaging.SingleEmailMessage[] { email }
            );
            
            return results[0].isSuccess();
            
        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
            throw new AuraHandledException('Failed to send email: ' + e.getMessage());
        }
    }
    
    /**
     * 发送邮件给 Queue 成员，支持自定义占位符替换
     */
    @AuraEnabled
    public static Boolean sendEmailToQueueWithCustomMerge(
        String queueDeveloperName,
        String templateDeveloperName,
        Id whatId,
        Map<String, String> customReplacements
    ) {
        try {
            // 1. 获取 Queue 成员
            List<Id> userIds = getQueueMemberUserIds(queueDeveloperName);
            if (userIds.isEmpty()) {
                System.debug('No users found in queue: ' + queueDeveloperName);
                return false;
            }
            
            // 2. 获取 Email Template
            EmailTemplate template = getEmailTemplate(templateDeveloperName);
            if (template == null) {
                System.debug('Email template not found: ' + templateDeveloperName);
                return false;
            }
            
            // 3. 获取记录数据
            SObject recordData = null;
            if (whatId != null) {
                recordData = getRecordData(whatId);
            }
            
            // 4. 替换模板内容
            String subject = template.Subject;
            String htmlBody = template.HtmlValue;
            String textBody = template.Body;
            
            // 替换自定义占位符
            if (customReplacements != null && !customReplacements.isEmpty()) {
                subject = replaceCustomPlaceholders(subject, customReplacements);
                htmlBody = replaceCustomPlaceholders(htmlBody, customReplacements);
                textBody = replaceCustomPlaceholders(textBody, customReplacements);
            }
            
            // 替换标准合并字段
            if (recordData != null) {
                subject = CRMGlobalTemplateMergeFieldService.mergeTemplate(subject, recordData, false);
                htmlBody = CRMGlobalTemplateMergeFieldService.mergeTemplate(htmlBody, recordData, false);
                textBody = CRMGlobalTemplateMergeFieldService.mergeTemplate(textBody, recordData, false);
            }
            
            // 5. 批量发送邮件
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            
            for (Id userId : userIds) {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setTargetObjectId(userId);
                email.setSubject(subject);
                email.setHtmlBody(htmlBody);
                email.setPlainTextBody(textBody);
                email.setSaveAsActivity(false);
                
                if (whatId != null) {
                    email.setWhatId(whatId);
                }
                
                emails.add(email);
            }
            
            if (!emails.isEmpty()) {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(emails);
                
                // 检查结果
                Boolean allSuccess = true;
                for (Messaging.SendEmailResult result : results) {
                    if (!result.isSuccess()) {
                        allSuccess = false;
                        System.debug('Email send error: ' + result.getErrors()[0].getMessage());
                    }
                }
                return allSuccess;
            }
            
            return false;
            
        } catch (Exception e) {
            System.debug('Error sending emails to queue: ' + e.getMessage());
            throw new AuraHandledException('Failed to send emails: ' + e.getMessage());
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
    
    /**
     * 获取 Queue 成员用户 IDs
     */
    private static List<Id> getQueueMemberUserIds(String queueDeveloperName) {
        List<Id> userIds = new List<Id>();
        
        List<Group> queues = [
            SELECT Id 
            FROM Group 
            WHERE Type = 'Queue' 
            AND DeveloperName = :queueDeveloperName
            LIMIT 1
        ];
        
        if (queues.isEmpty()) {
            return userIds;
        }
        
        Id queueId = queues[0].Id;
        
        for (GroupMember gm : [
            SELECT UserOrGroupId 
            FROM GroupMember 
            WHERE GroupId = :queueId 
            AND UserOrGroupId IN (SELECT Id FROM User WHERE IsActive = true)
        ]) {
            if (String.valueOf(gm.UserOrGroupId).startsWith('005')) {
                userIds.add(gm.UserOrGroupId);
            }
        }
        
        return userIds;
    }
}
