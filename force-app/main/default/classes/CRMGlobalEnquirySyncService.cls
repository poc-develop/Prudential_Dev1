/**
 * @description       : Service class for PHKL Enquiry Sync operations
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-28
 * @last modified by  : hank
**/
public with sharing class CRMGlobalEnquirySyncService {
    
    // Configuration key for storing last sync time
    private static final String LAST_SYNC_TIME_KEY = 'CRMGlobalEnquiryLastSyncTime';
    
    // Static RecordType cache
    public static List<RecordType> caseRecordTypes = [
        SELECT Id, DeveloperName 
        FROM RecordType 
        WHERE SObjectType = 'Case' 
        AND isActive = true
    ];
    
    /**
     * Call external API to get Enquiry data
     * @param lastSyncTime Last sync time (null for default)
     * @return CRMGlobalEnquiryAPIResponse API response object
     */
    public static CRMGlobalEnquiryAPIResponse callEnquiryAPI(DateTime lastSyncTime) {
        try {
            System.debug(LoggingLevel.INFO, '=== API Call Started ===');
            
            // Get last sync time and current time
            DateTime syncTime;
            if (lastSyncTime != null) {
                syncTime = lastSyncTime;
            } else {
                // Calculate sync time based on current time
                DateTime now = DateTime.now();
                Integer currentHour = now.hour();
                
                if (currentHour >= 15) {
                    // If current time is 15:00 or later, use today at 00:00:00
                    syncTime = DateTime.newInstance(now.date(), Time.newInstance(0, 0, 1, 0));
                    System.debug(LoggingLevel.INFO, 'Current time >= 15:00, using today 00:00:00 as sync time');
                } else {
                    // Otherwise, use yesterday at 16:00:00
                    Date yesterday = now.date().addDays(-1);
                    syncTime = DateTime.newInstance(yesterday, Time.newInstance(16, 0, 1, 0));
                    System.debug(LoggingLevel.INFO, 'Current time < 15:00, using yesterday 16:00:00 as sync time');
                }
            }
            DateTime currentSyncTime = DateTime.now();
            
            // Format datetime for API (ISO 8601 format with timezone)
            String createDtFrom = formatDateTimeForAPI(syncTime);
            // String createDtFrom = '2025-04-05T16:00:00Z';
            String createDtTo = formatDateTimeForAPI(currentSyncTime);
            
            System.debug(LoggingLevel.INFO, 'Last Sync Time: ' + createDtFrom);
            System.debug(LoggingLevel.INFO, 'Current Sync Time: ' + createDtTo);
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            
            // Construct endpoint
            String endpoint = 'callout:CRM_PHKL_AES_Enquiry' + '/getAESeEnquiry';
            request.setEndpoint(endpoint);
            
            request.setMethod('POST');
            Map<String, String> body = new Map<String, String>();
            body.put('enquiryId', '');
            body.put('enquiryStatus', 'A|P|C');
            body.put('enquiryType', 'UW|PA|CL|O');
            body.put('agentCd', '');
            body.put('agentClass', 'N');
            body.put('slaType', 'O');
            body.put('polNo', '');
            body.put('usrId', '');
            body.put('createDtFrom', createDtFrom);
            body.put('createDtTo', createDtTo);
            String bodyString = JSON.serialize(body);
            
            System.debug(LoggingLevel.INFO, 'API Request - createDtFrom: ' + createDtFrom + ', createDtTo: ' + createDtTo);
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
            
            if(response.getStatusCode() != 200) {
                String errorDetail = 'API call failed with status code: ' + response.getStatusCode();
                errorDetail += '\nEndpoint: ' + endpoint;
                errorDetail += '\nResponse Body: ' + responseBody;
                
                throw new CalloutException(errorDetail);
            }
            
            // Parse response
            if (response != null && String.isNotBlank(responseBody)) {
                System.debug(LoggingLevel.DEBUG, 'Parsing response body...');
                System.debug(LoggingLevel.DEBUG, 'Response body length: ' + responseBody.length());
                // Parse the response using untyped deserialization first to handle Results format
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                
                // Extract Results field
                Object resultsObj = responseMap.get('Results');
                List<CRMGlobalEnquiryData> resultsList = new List<CRMGlobalEnquiryData>();
                
                // Handle Results: can be array or single object
                if (resultsObj != null) {
                    if (resultsObj instanceof List<Object>) {
                        // Results is an array
                        System.debug(LoggingLevel.INFO, 'Results is an array, parsing...');
                        resultsList = (List<CRMGlobalEnquiryData>) JSON.deserialize(
                            JSON.serialize(resultsObj),
                            List<CRMGlobalEnquiryData>.class
                        );
                    } else if (resultsObj instanceof Map<String, Object>) {
                        // Results is a single object, convert to array
                        System.debug(LoggingLevel.INFO, 'Results is a single object, converting to array...');
                        CRMGlobalEnquiryData singleResult = (CRMGlobalEnquiryData) JSON.deserialize(
                            JSON.serialize(resultsObj),
                            CRMGlobalEnquiryData.class
                        );
                        resultsList.add(singleResult);
                    }
                }
                
                System.debug(LoggingLevel.INFO, 'Results count: ' + resultsList.size());
                
                // Build the response object
                CRMGlobalEnquiryAPIResponse apiResponse = new CRMGlobalEnquiryAPIResponse();
                apiResponse.type = (String) responseMap.get('Type');
                apiResponse.returnCode = (String) responseMap.get('ReturnCode');
                apiResponse.lastAccessedUrl = (String) responseMap.get('LastAccessedUrl');
                apiResponse.caller = (String) responseMap.get('Caller');
                apiResponse.apiName = (String) responseMap.get('ApiName');
                apiResponse.results = resultsList;
                apiResponse.httpResponseCode = response.getStatusCode();
                apiResponse.messageID = (String) responseMap.get('MessageID');
                
                System.debug(LoggingLevel.INFO, 'Response parsed successfully');
                System.debug(LoggingLevel.INFO, 'ReturnCode: ' + apiResponse.returnCode);
                
                return apiResponse;
            }
            
            System.debug(LoggingLevel.WARN, 'Response is null or empty');
            return null;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'API call error: ' + e.getMessage());
            CRMGlobalLogManager.addApexErrorLog('Enquiry API call failed', e);
            throw e;
        }
    }
    
    /**
     * Extract SOAP Fault information from SOAP XML response
     * @param soapResponse SOAP XML response string
     * @return String Extracted fault message
     */
    public static String extractSOAPFault(String soapResponse) {
        if (String.isBlank(soapResponse)) {
            return 'No response body';
        }
        
        try {
            // Extract faultcode
            String faultcode = '';
            Integer faultcodeStart = soapResponse.indexOf('<faultcode>');
            Integer faultcodeEnd = soapResponse.indexOf('</faultcode>');
            if (faultcodeStart >= 0 && faultcodeEnd > faultcodeStart) {
                faultcode = soapResponse.substring(faultcodeStart + 11, faultcodeEnd).trim();
            }
            
            // Extract faultstring
            String faultstring = '';
            Integer faultstringStart = soapResponse.indexOf('<faultstring>');
            Integer faultstringEnd = soapResponse.indexOf('</faultstring>');
            if (faultstringStart >= 0 && faultstringEnd > faultstringStart) {
                faultstring = soapResponse.substring(faultstringStart + 13, faultstringEnd).trim();
            }
            
            // Extract detail if available
            String detail = '';
            Integer detailStart = soapResponse.indexOf('<detail>');
            Integer detailEnd = soapResponse.indexOf('</detail>');
            if (detailStart >= 0 && detailEnd > detailStart) {
                detail = soapResponse.substring(detailStart + 8, detailEnd).trim();
            }
            
            String errorMsg = 'FaultCode: ' + faultcode;
            if (String.isNotBlank(faultstring)) {
                errorMsg += '\nFaultString: ' + faultstring;
            }
            if (String.isNotBlank(detail)) {
                errorMsg += '\nDetail: ' + detail;
            }
            
            return errorMsg;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error extracting SOAP fault: ' + e.getMessage());
            return 'SOAP Fault detected but could not parse: ' + soapResponse.substring(0, Math.min(200, soapResponse.length()));
        }
    }
    
    /**
     * Process Enquiry data - create or update records
     * @param enquiryList List of enquiry data from API
     * @return CRMGlobalEnquiryProcessResult Processing result with statistics
     */
    public static CRMGlobalEnquiryProcessResult processEnquiryData(List<CRMGlobalEnquiryData> enquiryList) {
        CRMGlobalEnquiryProcessResult result = new CRMGlobalEnquiryProcessResult();
        result.processedCount = 0;
        result.successCount = 0;
        result.failureCount = 0;
        result.errorMessages = new List<String>();
        
        // Collect all enquiryIds
        Set<String> enquiryIds = new Set<String>();
        // Collect all client codes for Account lookup
        Set<String> clientCodes = new Set<String>();
        // Map to store agentName for each clientCd (use first encountered agentName)
        Map<String, String> clientCodeToAgentNameMap = new Map<String, String>();
        // Map to store agentCd for each clientCd (use first encountered agentCd)
        Map<String, String> clientCodeToAgentCdMap = new Map<String, String>();
        
        for (CRMGlobalEnquiryData enquiry : enquiryList) {
            if (String.isNotBlank(enquiry.enquiryId)) {
                enquiryIds.add(enquiry.enquiryId);
            }
            if (String.isNotBlank(enquiry.clientCd)) {
                clientCodes.add(enquiry.clientCd);
                // Store first encountered agentName for each clientCd
                if (!clientCodeToAgentNameMap.containsKey(enquiry.clientCd) && String.isNotBlank(enquiry.agentName)) {
                    clientCodeToAgentNameMap.put(enquiry.clientCd, enquiry.agentName);
                }
                // Store first encountered agentCd for each clientCd
                if (!clientCodeToAgentCdMap.containsKey(enquiry.clientCd) && String.isNotBlank(enquiry.agentCd)) {
                    clientCodeToAgentCdMap.put(enquiry.clientCd, enquiry.agentCd);
                }
            }
        }
        
        // Step 0: Query Accounts by client codes (FinServ__CustomerID__c) and create missing ones
        Map<String, Id> clientCodeToAccountIdMap = new Map<String, Id>();
        if (!clientCodes.isEmpty()) {
            try {
                // Query existing Accounts
                List<Account> accounts = [
                    SELECT Id, FinServ__CustomerID__c 
                    FROM Account 
                    WHERE FinServ__CustomerID__c IN :clientCodes
                    AND FinServ__CustomerID__c != null
                ];
                
                for (Account acc : accounts) {
                    if (String.isNotBlank(acc.FinServ__CustomerID__c)) {
                        clientCodeToAccountIdMap.put(acc.FinServ__CustomerID__c, acc.Id);
                    }
                }
                
                System.debug(LoggingLevel.INFO, 'Found ' + clientCodeToAccountIdMap.size() + ' existing Accounts for ' + clientCodes.size() + ' client codes');
                
                // Create Accounts for missing client codes
                List<Account> accountsToCreate = new List<Account>();
                Id customerRTId = null;
                
                try {
                    customerRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Customer').getRecordTypeId();
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'Could not find CRM_GLOBAL_Customer RecordType: ' + e.getMessage());
                }
                
                for (String clientCd : clientCodes) {
                    if (!clientCodeToAccountIdMap.containsKey(clientCd)) {
                        // Create new Account with agentName and clientCd
                        Account newAccount = new Account();
                        if (customerRTId != null) {
                            newAccount.RecordTypeId = customerRTId;
                        }
                        newAccount.FinServ__CustomerID__c = clientCd;
                        
                        // Use agentName as LastName (or split if needed)
                        String agentName = clientCodeToAgentNameMap.get(clientCd);
                        if (String.isNotBlank(agentName)) {
                            // If agentName contains space, try to split into FirstName and LastName
                            List<String> nameParts = agentName.split(' ', 2);
                            if (nameParts.size() > 1) {
                                newAccount.FirstName = nameParts[0];
                                newAccount.LastName = nameParts[1];
                            } else {
                                newAccount.LastName = agentName;
                            }
                        } else {
                            // Fallback: use clientCd as name if agentName is not available
                            newAccount.LastName = 'Customer ' + clientCd;
                        }
                        
                        // Set agentCd if available
                        String agentCd = clientCodeToAgentCdMap.get(clientCd);
                        if (String.isNotBlank(agentCd)) {
                            newAccount.CRM_Global_AgentCode__c = agentCd;
                        }
                        
                        accountsToCreate.add(newAccount);
                        System.debug(LoggingLevel.INFO, 'Preparing to create Account for client code: ' + clientCd + ' with name: ' + agentName + ', agentCd: ' + agentCd);
                    }
                }
                
                // Insert new Accounts
                if (!accountsToCreate.isEmpty()) {
                    Database.SaveResult[] accountResults = Database.insert(accountsToCreate, false);
                    for (Integer i = 0; i < accountResults.size(); i++) {
                        if (accountResults[i].isSuccess()) {
                            String clientCd = accountsToCreate[i].FinServ__CustomerID__c;
                            clientCodeToAccountIdMap.put(clientCd, accountResults[i].getId());
                            System.debug(LoggingLevel.INFO, 'Created Account ' + accountResults[i].getId() + ' for client code: ' + clientCd);
                        } else {
                            String errorMsg = 'Failed to create Account for client code: ' + accountsToCreate[i].FinServ__CustomerID__c;
                            for (Database.Error err : accountResults[i].getErrors()) {
                                errorMsg += ' - ' + err.getMessage();
                            }
                            result.errorMessages.add(errorMsg);
                            System.debug(LoggingLevel.ERROR, errorMsg);
                        }
                    }
                }
                
                System.debug(LoggingLevel.INFO, 'Total Accounts (existing + created): ' + clientCodeToAccountIdMap.size() + ' for ' + clientCodes.size() + ' client codes');
                
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error querying/creating Accounts by client codes: ' + e.getMessage());
                CRMGlobalLogManager.addApexErrorLog('Error querying/creating Accounts', e);
            }
        }
        
        String enquiryCaseRecordTypeId = '';
        String masterCaseRecordTypeId = '';
        for (RecordType recordType : caseRecordTypes) {
            if (recordType.DeveloperName == 'Enquiry') {
                enquiryCaseRecordTypeId = recordType.Id;
            }
            if (recordType.DeveloperName == 'Master_Inbound') {
                masterCaseRecordTypeId = recordType.Id;
            }
        }
        
        // Get Queue Id for Case assignment
        Id queueId = getQueueId('CRM_Global_Eenquiry');
        
        // Prepare Master Cases for insertion
        List<Case> masterCasesToInsert = new List<Case>();
        // Map to track enquiry data for each master case
        Map<Integer, CRMGlobalEnquiryData> enquiryDataMap = new Map<Integer, CRMGlobalEnquiryData>();
        
        // Step 1: Create Master Cases
        Integer index = 0;
        for (CRMGlobalEnquiryData enquiry : enquiryList) {
            try {
                result.processedCount++;
                
                // Create Master Case (RecordType: Master_Inbound)
                Case masterCase = new Case();
                masterCase.RecordTypeId = masterCaseRecordTypeId;
                masterCase.Status = 'New';
                masterCase.Subject = 'E-enquiry from ' + enquiry.agentName;
                masterCase.Origin = 'E-enquiry';
                masterCase.OwnerId = queueId != null ? queueId : UserInfo.getUserId();
                masterCase.Priority = 'Medium';
                masterCase.CRM_Global_EnquirerName__c = enquiry.agentName;
                masterCase.CRM_Global_ContactNumber__c = enquiry.agentCd;
                masterCase.CRM_Global_AgentClass__c = enquiry.agentClass;
                masterCase.CRM_Global_Source__c = enquiry.source;
                masterCase.CRM_Global_Division__c = enquiry.division;
                masterCase.CRM_Global_EnquiryQuestion__c = enquiry.enquiryQuestion;
                masterCase.CRM_Global_AgentDistributionChannel__c = enquiry.agentDistChan;
                masterCase.CRM_Global_TargetReplyDate__c = parseDatetime(enquiry.targetReplyDt);
                masterCase.CRM_Global_DesignatedCode__c = enquiry.dsgnCd;
                masterCase.CRM_Global_EnquiryDetails__c = enquiry.enquiryDetails;
                masterCase.CRM_Global_ServiceLevel__c = enquiry.serviceLevel;
                masterCase.CRM_Global_CreatedDate__c = parseDatetime(enquiry.createDt);
                masterCase.CRM_Global_CutOffDate__c = parseDatetime(enquiry.cutoffDate);
                masterCase.CRM_Global_EnquiryType__c = enquiry.enquiryType;
                masterCase.CRM_Global_PolicyNumber__c = enquiry.polNo;
                masterCase.CRM_Global_SLAType__c = enquiry.slaType;
                masterCase.CRM_Global_EnquiryID__c = enquiry.enquiryId;
                masterCase.CRM_Global_EmailAddress__c = enquiry.agentEmail;
                
                // Set AccountId based on clientCd
                if (String.isNotBlank(enquiry.clientCd) && clientCodeToAccountIdMap.containsKey(enquiry.clientCd)) {
                    masterCase.AccountId = clientCodeToAccountIdMap.get(enquiry.clientCd);
                    System.debug(LoggingLevel.INFO, 'Assigned Account ' + masterCase.AccountId + ' to Master Case for client code: ' + enquiry.clientCd);
                }
                
                masterCasesToInsert.add(masterCase);
                enquiryDataMap.put(index, enquiry);
                index++;
                
            } catch (Exception e) {
                result.failureCount++;
                String errorMsg = 'Error processing enquiry ' + enquiry.enquiryId + ': ' + e.getMessage();
                result.errorMessages.add(errorMsg);
                System.debug(LoggingLevel.ERROR, errorMsg);
            }
        }
        
        // Step 2: Insert Master Cases first
        Map<Integer, Id> masterCaseIdMap = new Map<Integer, Id>();
        // Map to store AccountId for each master case index
        Map<Integer, Id> masterCaseAccountIdMap = new Map<Integer, Id>();
        
        if (!masterCasesToInsert.isEmpty()) {
            try {
                Database.SaveResult[] masterResults = Database.insert(masterCasesToInsert, false);
                
                // Get RecordType ID for CRM_GLOBAL_Alert_Task
                Id alertTaskRecordTypeId = null;
                try {
                    alertTaskRecordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName().get('CRM_GLOBAL_Alert_Task').getRecordTypeId();
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'Could not find CRM_GLOBAL_Alert_Task RecordType: ' + e.getMessage());
                }
                
                // Prepare Tasks to create for successfully inserted Master Cases
                List<Task> tasksToInsert = new List<Task>();
                
                // Map inserted Master Case IDs to their index and store AccountId
                for (Integer i = 0; i < masterResults.size(); i++) {
                    if (masterResults[i].isSuccess()) {
                        Id masterCaseId = masterResults[i].getId();
                        masterCaseIdMap.put(i, masterCaseId);
                        // Store AccountId from the inserted master case
                        if (masterCasesToInsert[i].AccountId != null) {
                            masterCaseAccountIdMap.put(i, masterCasesToInsert[i].AccountId);
                        }
                        result.successCount++;
                        
                        // Create Task for this Master Case
                        Task alertTask = new Task();
                        if (alertTaskRecordTypeId != null) {
                            alertTask.RecordTypeId = alertTaskRecordTypeId;
                        }
                        alertTask.WhatId = masterCaseId;
                        alertTask.CRM_Global_CaseOrigin__c = 'E-enquiry';
                        tasksToInsert.add(alertTask);
                    } else {
                        result.failureCount++;
                        String errorMsg = 'Master Case insert failed: ';
                        for (Database.Error err : masterResults[i].getErrors()) {
                            errorMsg += err.getMessage() + '; ';
                        }
                        result.errorMessages.add(errorMsg);
                    }
                }
                
                // Insert Tasks for successfully created Master Cases
                if (!tasksToInsert.isEmpty()) {
                    Database.SaveResult[] taskResults = Database.insert(tasksToInsert, false);
                    for (Integer i = 0; i < taskResults.size(); i++) {
                        if (!taskResults[i].isSuccess()) {
                            String errorMsg = 'Task creation failed for Master Case: ';
                            for (Database.Error err : taskResults[i].getErrors()) {
                                errorMsg += err.getMessage() + '; ';
                            }
                            result.errorMessages.add(errorMsg);
                            System.debug(LoggingLevel.ERROR, errorMsg);
                        } else {
                            System.debug(LoggingLevel.INFO, 'Task created successfully for Master Case: ' + tasksToInsert[i].WhatId);
                        }
                    }
                }
                
            } catch (Exception e) {
                result.failureCount += masterCasesToInsert.size();
                String errorMsg = 'Master Case batch insert error: ' + e.getMessage();
                result.errorMessages.add(errorMsg);
                CRMGlobalLogManager.addApexErrorLog(errorMsg, e);
                return result; // Cannot proceed without Master Cases
            }
        }
        
        // Step 3: Create and insert Enquiry Cases (child records)
        List<Case> enquiryCasesToInsert = new List<Case>();
        
        for (Integer i = 0; i < masterCasesToInsert.size(); i++) {
            // Only create Enquiry Case if Master Case was successfully inserted
            if (masterCaseIdMap.containsKey(i)) {
                CRMGlobalEnquiryData enquiry = enquiryDataMap.get(i);
                Case enquiryCase = new Case();
                
                // Set parent relationship
                enquiryCase.ParentId = masterCaseIdMap.get(i);
                
                // Set AccountId to match parent Master Case AccountId
                if (masterCaseAccountIdMap.containsKey(i)) {
                    enquiryCase.AccountId = masterCaseAccountIdMap.get(i);
                    System.debug(LoggingLevel.INFO, 'Assigned Account ' + enquiryCase.AccountId + ' to Enquiry Case (matching parent Master Case)');
                }
                
                // Map all enquiry fields to Enquiry Case
                mapEnquiryFieldsToCase(enquiryCase, enquiry, enquiryCaseRecordTypeId);
                
                enquiryCasesToInsert.add(enquiryCase);
            }
        }
        
        // Step 4: Insert Enquiry Cases
        if (!enquiryCasesToInsert.isEmpty()) {
            try {
                Database.SaveResult[] enquiryResults = Database.insert(enquiryCasesToInsert, false);
                
                for (Integer i = 0; i < enquiryResults.size(); i++) {
                    if (enquiryResults[i].isSuccess()) {
                        result.successCount++;
                    } else {
                        result.failureCount++;
                        String errorMsg = 'Enquiry Case insert failed: ';
                        for (Database.Error err : enquiryResults[i].getErrors()) {
                            errorMsg += err.getMessage() + '; ';
                        }
                        result.errorMessages.add(errorMsg);
                    }
                }
            } catch (Exception e) {
                result.failureCount += enquiryCasesToInsert.size();
                String errorMsg = 'Enquiry Case batch insert error: ' + e.getMessage();
                result.errorMessages.add(errorMsg);
                CRMGlobalLogManager.addApexErrorLog(errorMsg, e);
            }
        }
        
        return result;
    }
    
    /**
     * Get Queue Id by DeveloperName
     * @param queueDeveloperName Queue DeveloperName
     * @return Id Queue Id, or null if not found
     */
    public static Id getQueueId(String queueDeveloperName) {
        try {
            List<Group> queues = [
                SELECT Id 
                FROM Group 
                WHERE Type = 'Queue' 
                AND DeveloperName = :queueDeveloperName
                LIMIT 1
            ];
            
            if (!queues.isEmpty()) {
                return queues[0].Id;
            }
            
            System.debug(LoggingLevel.WARN, 'Queue not found: ' + queueDeveloperName);
            return null;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error querying Queue: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Map enquiry status code to Case Status value
     * Mapping: A→Active, P→Pending, C→Complete, E→Escalated Active, W→Escalated Pending,
     *          D→Escalated Completed, F→Escalated Active (2), X→Escalated Pending (2), S→Escalated Completed (2)
     * @param enquiryStatus Single letter status code from enquiry data
     * @return String Case Status value, or 'New' if mapping not found
     */
    public static String mapEnquiryStatusToCaseStatus(String enquiryStatus) {
        if (String.isBlank(enquiryStatus)) {
            return 'New';
        }
        
        Map<String, String> statusMapping = new Map<String, String>{
            'A' => 'Active',
            'P' => 'Pending to Close',
            'C' => 'Completed',
            'E' => 'Escalated Active',
            'W' => 'Escalated Pending',
            'D' => 'Escalated Completed',
            'F' => 'Escalated Active (2)',
            'X' => 'Escalated Pending (2)',
            'S' => 'Escalated Completed (2)'
        };
        
        String mappedStatus = statusMapping.get(enquiryStatus.toUpperCase());
        if (String.isNotBlank(mappedStatus)) {
            return mappedStatus;
        }
        
        // Default to 'New' if status code not recognized
        System.debug(LoggingLevel.WARN, 'Unrecognized enquiry status code: ' + enquiryStatus + ', defaulting to New');
        return 'New';
    }
    
    /**
     * Map enquiry fields to Case object (Enquiry Case)
     * @param enquiryCase The Case object to populate
     * @param enquiry The enquiry data from API
     * @param enquiryCaseRecordTypeId The RecordType ID for Enquiry Case
     */
    public static void mapEnquiryFieldsToCase(Case enquiryCase, CRMGlobalEnquiryData enquiry, String enquiryCaseRecordTypeId) {
        // Set RecordType
        enquiryCase.RecordTypeId = enquiryCaseRecordTypeId;
        
        // Get Queue Id for Case assignment
        Id queueId = getQueueId('CRM_Global_Eenquiry');
        
        // Basic fields
        enquiryCase.Status = 'New'; // Default status, will be overridden by enquiryStatus if available
        enquiryCase.Origin = 'E-enquiry';
        enquiryCase.OwnerId = queueId != null ? queueId : UserInfo.getUserId();
        enquiryCase.Priority = 'Medium';
        enquiryCase.Subject = 'E-enquiry from ' + enquiry.agentName;
        
        // Contact information
        enquiryCase.CRM_Global_EnquirerName__c = enquiry.agentName;
        enquiryCase.CRM_Global_ContactNumber__c = enquiry.agentCd;
        enquiryCase.CRM_Global_AgentClass__c = enquiry.agentClass;
        enquiryCase.CRM_Global_Source__c = enquiry.source;
        enquiryCase.CRM_Global_Division__c = enquiry.division;
        enquiryCase.CRM_Global_EnquiryQuestion__c = enquiry.enquiryQuestion;
        enquiryCase.CRM_Global_AgentDistributionChannel__c = enquiry.agentDistChan;
        enquiryCase.CRM_Global_TargetReplyDate__c = parseDatetime(enquiry.targetReplyDt);
        enquiryCase.CRM_Global_DesignatedCode__c = enquiry.dsgnCd;
        enquiryCase.CRM_Global_EnquiryDetails__c = enquiry.enquiryDetails;
        enquiryCase.CRM_Global_ServiceLevel__c = enquiry.serviceLevel;
        enquiryCase.CRM_Global_CreatedDate__c = parseDatetime(enquiry.createDt);
        enquiryCase.CRM_Global_CutOffDate__c = parseDatetime(enquiry.cutoffDate);
        enquiryCase.CRM_Global_EnquiryType__c = enquiry.enquiryType;
        enquiryCase.CRM_Global_PolicyNumber__c = enquiry.polNo;
        enquiryCase.CRM_Global_EmailAddress__c = enquiry.agentEmail;
        
        // Map enquiry status to Case Status
        if (String.isNotBlank(enquiry.enquiryStatus)) {
            enquiryCase.Status = mapEnquiryStatusToCaseStatus(enquiry.enquiryStatus);
        }
        
        enquiryCase.CRM_Global_SLAType__c = enquiry.slaType;
        enquiryCase.CRM_Global_EnquiryID__c = enquiry.enquiryId;
    }
    
    /**
     * Parse datetime string (ISO 8601 format)
     * Example: "2025-06-10T09:37:14+08:00" or "2025-06-10T09:37:14-08:00"
     * @param dateTimeStr DateTime string to parse
     * @return DateTime Parsed datetime, or null if parsing fails
     */
    public static DateTime parseDatetime(String dateTimeStr) {
        try {
            if (String.isBlank(dateTimeStr)) {
                return null;
            }
            
            // Remove timezone information
            String cleanStr = dateTimeStr;
            
            // Handle timezone with + (e.g., +08:00)
            if (cleanStr.contains('+')) {
                cleanStr = cleanStr.substringBefore('+');
            } 
            // Handle timezone with - (e.g., -08:00)
            // Check if there's a timezone after the time part
            else if (cleanStr.contains('-')) {
                // ISO 8601: YYYY-MM-DDTHH:mm:ss-HH:mm
                // Find T to separate date and time
                Integer tIndex = cleanStr.indexOf('T');
                if (tIndex > 0) {
                    String timePart = cleanStr.substring(tIndex + 1);
                    // Time part should be HH:mm:ss, if there's another - after, it's timezone
                    List<String> timeParts = timePart.split('-');
                    if (timeParts.size() > 1) {
                        // The time part is before the timezone separator
                        cleanStr = cleanStr.substring(0, tIndex + 1) + timeParts[0];
                    }
                }
            }
            
            // Remove Z timezone indicator if present
            if (cleanStr.endsWith('Z')) {
                cleanStr = cleanStr.substringBefore('Z');
            }
            
            // Replace T with space for DateTime.valueOfGmt
            cleanStr = cleanStr.replace('T', ' ');
            
            return DateTime.valueOfGmt(cleanStr);
        } catch (Exception e) {
            System.debug('Error parsing datetime: ' + dateTimeStr + ' - ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Get last sync time from storage or return default time
     * Priority: Platform Cache > Custom Metadata > Default (24 hours ago)
     * @return DateTime Last sync time, or null if not found
     */
    public static DateTime getLastSyncTime() {
        DateTime lastSync = null;
        // Option 1: Try Platform Cache first (if available)
       
        Cache.OrgPartition orgPartition = Cache.Org.getPartition('local.LastEnquirySyncTime');
        if (orgPartition != null) {
            Object cachedTime = orgPartition.get(LAST_SYNC_TIME_KEY);
            if (cachedTime instanceof DateTime) {
                lastSync = (DateTime) cachedTime;
            } else if (cachedTime instanceof String) {
                lastSync = DateTime.valueOf((String) cachedTime);
            }
        }
        return lastSync;
    }
    
    /**
     * Save last sync time to storage
     * Priority: Platform Cache > Custom Metadata (if Platform Cache not available)
     * @param syncTime DateTime to save
     */
    public static void saveLastSyncTime(DateTime syncTime) {
        Boolean saved = false;
        Cache.OrgPartition orgPartition = Cache.Org.getPartition('local.LastEnquirySyncTime');
        if (orgPartition != null) {
            // 24 hours in seconds (24 * 60 * 60 = 86400)
            Integer ttlSeconds = 86400;
            orgPartition.put(LAST_SYNC_TIME_KEY, syncTime, ttlSeconds);
            saved = true;
            System.debug(LoggingLevel.INFO, 'Last sync time saved to Platform Cache (TTL: 24 hours): ' + formatDateTimeForAPI(syncTime));
        }
    }
    
    /**
     * Format DateTime to API required format (ISO 8601 with UTC timezone)
     * Example: "2025-01-01T08:30:00Z"
     * @param dt DateTime to format
     * @return String Formatted datetime string
     */
    public static String formatDateTimeForAPI(DateTime dt) {
        if (dt == null) {
            return '';
        }
        
        // Convert to UTC and format as ISO 8601
        DateTime gmtDateTime = dt;
        
        // Format: YYYY-MM-DDTHH:mm:ssZ (UTC timezone)
        String year = String.valueOf(gmtDateTime.yearGmt());
        String month = String.valueOf(gmtDateTime.monthGmt()).leftPad(2, '0');
        String day = String.valueOf(gmtDateTime.dayGmt()).leftPad(2, '0');
        String hour = String.valueOf(gmtDateTime.hourGmt()).leftPad(2, '0');
        String minute = String.valueOf(gmtDateTime.minuteGmt()).leftPad(2, '0');
        String second = String.valueOf(gmtDateTime.secondGmt()).leftPad(2, '0');
        
        return year + '-' + month + '-' + day + 'T' + hour + ':' + minute + ':' + second + 'Z';
    }
    
    // ============ Inner Classes: API Response Structure ============
    
    public class CRMGlobalEnquiryAPIResponse {
        public String type;
        public String returnCode;
        public String lastAccessedUrl;
        public String caller;
        public String apiName;
        public List<CRMGlobalEnquiryData> results;
        public Integer httpResponseCode;
        public String messageID;
    }
    
    public class CRMGlobalEnquiryData {
        public String enquiryId;
        public String enquiryStatus;
        public String enquiryType;
        public String enquiryQuestion;
        public String enquiryDetails;
        public String enquiryReply;
        public String polNo;
        public String polOwner;
        public String clientCd;
        public String agentCd;
        public String agentName;
        public String agentEmail;
        public String agentClass;
        public String agentDistChan;
        public String source;
        public String division;
        public String dsgnCd;
        public String wrapUpCategory;
        public String wrapUpItem;
        public String slaType;
        public String serviceLevel;
        public Integer rating;
        public String handlingTime;
        public String createDt;
        public String lastUpdDt;
        public String firstReplyDt;
        public String targetReplyDt;
        public String lastAssignDt;
        public String lastWrapUpDt;
        public String cutoffDate;
        public String lastUpdUsr;
    }
    
    /**
     * Result class for processEnquiryData method
     */
    public class CRMGlobalEnquiryProcessResult {
        public Integer processedCount;
        public Integer successCount;
        public Integer failureCount;
        public List<String> errorMessages;
    }
}
