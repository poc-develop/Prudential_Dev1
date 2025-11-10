/**
 * @description       : Service for sending SMS
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-11-04
 * @last modified by  : hank
**/
public without sharing class CRMGlobalSendSmsService {

    /**
     * Send SMS
     * @param recipientNumber Recipient number
     * @param templateContent Template content
     * @param recordId Record ID - task whatId required
     * @return Map<String, Object> Result
     */
    public static Map<String, Object> sendSms(String recipientNumber, String templateContent, String recordId) {
        Map<String, Object> result = new Map<String, Object>();
        if(String.isBlank(recipientNumber) || String.isBlank(templateContent)) {
            result.put('success', false);
            result.put('message', 'Recipient number and template content are required');
            return result;
        }
        try {
            System.debug(LoggingLevel.INFO, '=== Send SMS API Call Started ===');
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            
            // Construct endpoint
            String endpoint = 'callout:CRM_PHKL_Send_SMS' + '/instantSMS';
            request.setEndpoint(endpoint);
            
            request.setMethod('POST');
            Map<String, String> body = new Map<String, String>();
            body.put('application', 'prudential');
            body.put('sender', '85269725600004');
            body.put('mrt', recipientNumber);
            body.put('msgText', templateContent);
            body.put('msgUtf8', '');
            body.put('msgUnicode', '');
            body.put('vp', '');
            body.put('statusReport', '1');
            body.put('schedule', '');
            String bodyString = JSON.serialize(body);
            System.debug(LoggingLevel.DEBUG, 'Request Body: ' + bodyString);
            request.setBody(bodyString);
            request.setTimeout(60000);
            system.debug('request: ' + request);
            Long startTime = System.currentTimeMillis();
            HttpResponse response = http.send(request);
            Long endTime = System.currentTimeMillis();
            Long calloutDuration = endTime - startTime;
            CRMGlobalLogManager.addWebServiceLog(request, response, calloutDuration);
            System.debug(LoggingLevel.INFO, 'API call duration: ' + calloutDuration + 'ms');
            System.debug(LoggingLevel.INFO, 'Response Status Code: ' + response.getStatusCode());
            System.debug(LoggingLevel.DEBUG, 'Response Body: ' + response.getBody());
            
            
            String responseBody = response.getBody();
            system.debug(LoggingLevel.FINER, 'responseBody: ' + responseBody);
            
            if(response.getStatusCode() != 200) {
                result.put('success', false);
                result.put('message', 'SMS sending failed with status code: ' + response.getStatusCode());
                // result.put('message', responseBody);
            }else if(response.getStatusCode() == 200){
                result.put('success', true);
                result.put('message', 'SMS sent successfully');
                // Get RecordType ID for CRM_Global_SMSEmailHistory
                Id recordTypeId = null;
                recordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName().get('CRM_Global_SMSEmailHistory').getRecordTypeId();        
                // Create Task
                Task smsTask = new Task();
                if (recordTypeId != null) {
                    smsTask.RecordTypeId = recordTypeId;
                }
                smsTask.WhatId = recordId;
                
                insert smsTask;
            }

            
        } catch (Exception e) {
            result.put('success', false);
            result.put('message', 'SMS sending failed with error: ' + e.getMessage());
            CRMGlobalLogManager.addApexErrorLog('SMS sending failed', e);
        }
        CRMGlobalLogManager.saveAndFlushLogs();
        return result;
    }
}