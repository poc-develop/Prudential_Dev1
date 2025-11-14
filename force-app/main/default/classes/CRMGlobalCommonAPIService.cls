/**
 * @description A simple way to handler external API callout
 * Lead Management
 */
public with sharing class CRMGlobalCommonAPIService implements CRMGlobalCommonAPIServiceInterface {

    private String apiConfigKey;
	private String httpMethod;
	private String endPoint;
	private String baseURL;
	private Integer timeout;
	private String requestBody;
	
    public CRMGlobalCommonAPIService(CRMGlobalIntegratable parameters) {
	    this.apiConfigKey = parameters.getApiConfigKey();
		this.requestBody = parameters.serializeToJson();
		if(this.apiConfigKey != null) setAPIProperties(apiConfigKey);
	}
	
	private void setAPIProperties(String apiConfigKey) {
	    Common_External_API_Config__mdt apiConfig = Common_External_API_Config__mdt.getInstance(apiConfigKey);
        if (apiConfig != null && apiConfig.Is_Active__c == true) {
            this.httpMethod = apiConfig.HTTP_Method__c;
			this.endPoint = apiConfig.EndPoint__c;
			this.baseURL = apiConfig.Named_Credential__c;
			this.timeout = Integer.valueOf(apiConfig.Timeout__c != null ? apiConfig.Timeout__c : 30000 );
        }
	}
	
	public Boolean verifyParamters() {
		if (this.httpMethod == null) return false;
		if (this.baseURL == null) return false;
		if (this.endPoint == null) return false;
		//Handle headers if needs
		return true;
	}
	
    public HttpResponse callExternalApi() {
		if (!this.verifyParamters()) {
			throw new CRMGlobalCommonAPIServiceException('API failed | Missing Key Parameters');
		}
		
        HttpRequest req = new HttpRequest();
        try {
            req.setMethod(this.httpMethod);
			req.setEndpoint('callout:' + this.baseURL + this.endPoint);
            req.setTimeout(this.timeout);
			//req.setHeader(this.headers);
			
			Set<String> hasBodyMethods = new Set<String>{'POST', 'PUT', 'PATCH'};

			if (hasBodyMethods.contains(this.httpMethod)) req.setBody(this.requestBody);
            
            
            // temp debug code for test
            system.debug(LoggingLevel.INFO, '-------------------- request --------------------');
            system.debug(LoggingLevel.INFO, 'Request: ' + req);
            System.Debug(LoggingLevel.INFO, 'Request Body: ' + req.getBody());
            // temp debug code for test

            Http http = new Http();
            Long startTime = System.currentTimeMillis();
            HTTPResponse res = http.send(req);
            Long endTime = System.currentTimeMillis();
            Long calloutDuration = endTime - startTime;
            CRMGlobalLogManager.addWebServiceLog(req, res, calloutDuration);
            
            system.debug(LoggingLevel.INFO, '-------------------- Response --------------------');
            system.debug(LoggingLevel.INFO, 'Response: ' + res.getBody());
            return res;

        } catch (Exception e) {
            CRMGlobalLogManager.addWebServiceLog(req, null, null);
            CRMGlobalLogManager.addApexErrorLog(e.getMessage(), e);
            System.debug(LoggingLevel.ERROR, 'API Callout Error: ' + e.getMessage() + '-' + e.getStacktraceString());
            throw new CRMGlobalCommonAPIServiceException(e.getMessage());
        }
    }


    /**
    * @description Internal Excpetion class for Common APIService
    */
    public class CRMGlobalCommonAPIServiceException extends Exception {}
}