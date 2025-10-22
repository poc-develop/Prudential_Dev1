/**
 * @description       : Service to handle API callout for CRM Global Data Integration
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-20
 * @last modified by  : Franco
**/
public with sharing class CRMGlobalDataIntegrationAPIService {

    /**
     * @description Calls the external API
     * @param configWrapper Data Integration Configuration
     * @return `HttpResponse`
     */
    public static HttpResponse callExternalApi(CRMGlobalDataIntegrationConfigWrapper configWrapper) {
        HttpRequest req = new HttpRequest();
        try {
            req.setMethod(configWrapper.config.HTTP_Method__c);
            setEndpoint(req, configWrapper);
            setTimeout(req, configWrapper);
            setRequestHeaders(req, configWrapper);
            setRequestBody(req, configWrapper);
            
            // temp debug code for test
            system.debug(LoggingLevel.INFO, '-------------------- request --------------------');
            system.debug(LoggingLevel.INFO, 'Request: ' + req);
            System.Debug(LoggingLevel.INFO, 'Headers fi_client_cd: ' + req.getHeader('fi_client_cd'));
            System.Debug(LoggingLevel.INFO, 'Request Body: ' + req.getBody());
            // temp debug code for test

            Http http = new Http();
            Long startTime = System.currentTimeMillis();
            HTTPResponse res = http.send(req);
            Long endTime = System.currentTimeMillis();
            Long calloutDuration = endTime - startTime;
            CRMGlobalLogManager.addWebServiceLog(req, res, calloutDuration);

            // low web service response
            if(!isSuccessResponse(configWrapper, res.getStatusCode())) {
                String message = buildAPIErrorMessage(configWrapper);
                throw new CRMGlobalDataIntegrationException(message);
            }
            return res;
        } catch (Exception e) {
            CRMGlobalLogManager.addWebServiceLog(req, null, null);
            CRMGlobalLogManager.addApexErrorLog(e.getMessage(), e);
            System.debug(LoggingLevel.ERROR, 'API Callout Error: ' + e.getMessage() + '-' + e.getStacktraceString());
            String message = buildAPIErrorMessage(configWrapper);
            throw new CRMGlobalDataIntegrationException(message);
        }
    }
    
    /**
     * @description Parses the response body
     * @param configWrapper Data Integration Configuration
     * @param response Response
     * @return  `Object`
     */
    public static Object parseApiResponse(CRMGlobalDataIntegrationConfigWrapper configWrapper, HttpResponse response) {
        if (configWrapper.config.Response_Format__c == 'XML') {
            // Dom.Document doc = response.getBodyDocument();
            throw new CRMGlobalDataIntegrationException('XML response format not yet implemented');
        }

        if(response != null && isSuccessResponse(configWrapper, response.getStatusCode())) {
            // temp debug code for test
            system.debug(LoggingLevel.INFO, '-------------------- response --------------------');
            System.debug(LoggingLevel.INFO, response.getBody());
            // temp debug code for test

            try {
                Object result = JSON.deserializeUntyped(response.getBody());
                return result;
            } catch (Exception e) {
                // log apex error
                System.debug(LoggingLevel.ERROR, 'Response JSON Parse Error: ' + e.getMessage() + '-' + e.getStacktraceString());
                throw new CRMGlobalDataIntegrationException('Response JSON Parse Error: ' + e.getMessage());
            }
        }
        return null;
    }

    private static String buildAPIErrorMessage(CRMGlobalDataIntegrationConfigWrapper configWrapper) {
        List<String> targetFieldLabels = new List<String>();
        for(CRMGlobalDataIntegrationTargetWrapper targetWrapper : configWrapper.targetWrappers) {
            targetFieldLabels.addAll(targetWrapper.targetFieldLabels);
        }
        String message = 'API [' + configWrapper.config.Endpoint_Path__c + '] ERROR|Affected Fields: ' + String.join(targetFieldLabels, ', ');
        return message;
    }

    /**
     * @description Checks if the response is a success
     * @param configWrapper DataIntegration config
     * @param statusCode Status Code
     * @return `Boolean`
     */
    private static Boolean isSuccessResponse(CRMGlobalDataIntegrationConfigWrapper configWrapper, Integer statusCode) {
        if (String.isBlank(configWrapper.config.Success_Codes__c)) {
            return statusCode >= 200 && statusCode < 300;
        }
        Set<Integer> successCodes = new Set<Integer>();
        for (String successCode : configWrapper.config.Success_Codes__c.split(';')) {
            successCodes.add(Integer.valueOf(successCode.trim()));
        }
        return successCodes.contains(statusCode);
    }

    /**
     * @description Sets the request endpoint
     * @param req HttpRequest
     * @param configWrapper DataIntegration config
     */
    private static void setEndpoint(HttpRequest req, CRMGlobalDataIntegrationConfigWrapper configWrapper) {
        String endpoint = 'callout:' + configWrapper.config.Named_Credential__c;
        if (String.isNotBlank(configWrapper.config.Endpoint_Path__c)) {
            endpoint += configWrapper.config.Endpoint_Path__c;
        }
        if (String.isNotBlank(configWrapper.config.Request_Params__c)) {
            String requestParameters = CRMGlobalTemplateMergeFieldService.mergeTemplate(configWrapper.config.Request_Params__c, configWrapper.parentRecord, true);
            endpoint += '?' + requestParameters;
        }
        req.setEndpoint(endpoint);
    }

    /**
     * @description Sets the request timeout
     * @param req HttpRequest
     * @param configWrapper Data Integration Configuration
     */
    private static void setTimeout(HttpRequest req, CRMGlobalDataIntegrationConfigWrapper configWrapper) {
        if(configWrapper.config.Timeout__c != null && configWrapper.config.Timeout__c > 0) {
            Integer timeout = Integer.valueOf(configWrapper.config.Timeout__c);
            req.setTimeout(timeout);
        }
    }

    /**
     * @description Sets the request headers
     * @param req HttpRequest
     * @param configWrapper Data Integration Configuration
     */
    private static void setRequestHeaders(HttpRequest req, CRMGlobalDataIntegrationConfigWrapper configWrapper) {
        Map<String, String> headersMap = getBodyFromTemplate(configWrapper.config.Request_Headers__c, configWrapper.parentRecord, false);
        if (headersMap != null && !headersMap.isEmpty()) {
            for (String header : headersMap.keySet()) {
                req.setHeader(header, headersMap.get(header));
            }
        }
    }

    /**
     * @description Sets the request body
     * @param req HttpRequest
     * @param configWrapper Data Integration Configuration
     */
    private static void setRequestBody(HttpRequest req, CRMGlobalDataIntegrationConfigWrapper configWrapper) {
        Map<String, String> requestBodyMap = getBodyFromTemplate(configWrapper.config.Request_Body__c, configWrapper.parentRecord, false);
        if (requestBodyMap != null && !requestBodyMap.isEmpty()) {
            req.setBody(JSON.serialize(requestBodyMap));
        }
    }

    /**
     * @description Gets the request body from template
     * @param template Template
     * @param record Record
     * @param needUrlEncode Need URL Encode
     * @return `Map<String, String>`
     */
    private static Map<String, String> getBodyFromTemplate(String template, SObject record, Boolean needUrlEncode) { 
        if(String.isBlank(template) || record == null) {
            return null;
        }
        String templateWithValues = template;
        if(CRMGlobalTemplateMergeFieldService.hasMergeFields(template)) {
            templateWithValues = CRMGlobalTemplateMergeFieldService.mergeTemplate(template, record, needUrlEncode);
        }
        System.debug(LoggingLevel.INFO, 'Template with Values: ' + templateWithValues);
        Map<String, String> templateMap = (Map<String, String>) JSON.deserialize(
            templateWithValues, Map<String, String>.class
        );
        Map<String, String> templateMapNew = new Map<String, String>();
        // Ignore those that haven't been merged yet 
        if (templateMap != null && !templateMap.isEmpty()) {
            for (String key : templateMap.keySet()) {
                String value = templateMap.get(key);
                if(!value.contains('{{{')) {
                    templateMapNew.put(key, value);
                }
            }
        }
        return templateMapNew;
    }
}