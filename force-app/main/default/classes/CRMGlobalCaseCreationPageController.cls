/**
 * @description       : 
 * @author            : Hassan
 * @group             : 
 * @last modified on  : 2025-09-18
**/
public with sharing class CRMGlobalCaseCreationPageController {
    public CRMGlobalCaseCreationPageController() {

    }

    @AuraEnabled(cacheable=true)
    public static Account getAccountDetails(String accountId) {
        return [select Id,Name,CRM_Global_IDNumber__pc,FinServ__CustomerID__c,PersonMobilePhone,PersonEmail,PersonContactId from Account where Id =: accountId limit 1];
    }

    @AuraEnabled(cacheable=true)
    public static Case getEnquiryCase(String caseId) {
        return [select Id,Origin,AccountId,Account.CRM_Global_IDNumber__pc,Account.FinServ__CustomerID__c,ParentId,Account.PersonContactId from Case where Id =: caseId limit 1];
    }

    @AuraEnabled(cacheable=true)
    public static List<InsurancePolicy> getPolicies(String accountId) {
        return [select Id
                        ,Name
                        ,NameInsured.Name
                        ,NameInsured.CRM_PHKL_PersonBirthdateMask__c
                        ,NameInsured.FinServ__CustomerID__c
                        ,Owner.Name
                        ,Status
                        ,Product.ProductCode
                        ,(select Id
                                ,Role
                                ,CRM_PHKL_ClientNameMask__c
                                ,CRM_PHKL_BirthdateMask__c
                                from InsurancePolicyParticipants)
                        from InsurancePolicy 
                        where NameInsuredId =: accountId];
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getWrapUpCategoryAndItems() {
        Map<String, List<String>> dependencies = CRMGlobalPicklistDependencyUtil.getDependentOptions('CRM_Global_CaseAssociatedItem__c','CRM_Global_WrapUpCategory__c','CRM_Global_WrapUpItem__c');
        System.debug('dependencies:'+JSON.serialize(dependencies));

        List<String> wrapUpCategoryAndItems = new List<String>();
        for(String category : dependencies.keySet()){
            for(String item : dependencies.get(category)){
                wrapUpCategoryAndItems.add(category + ' > ' + item);
            }
        }
        return wrapUpCategoryAndItems;
    }

    @AuraEnabled(cacheable=true)
    public static List<Case> getMasterCaseEnquiries(String masterCaseId){
        return [select Id,CRM_Global_EnquiryCaseNumber__c,Origin,Status,Owner.Name,ParentId,CreatedDate from Case where ParentId =: masterCaseId and Status = 'Active'];
    }

    @AuraEnabled(cacheable=true)
    public static List<Case> getAllEnquiries(String masterCaseId,String accountId){
        return [select Id,CRM_Global_EnquiryCaseNumber__c,Origin,Status,Owner.Name,ParentId,CreatedDate from Case where AccountId =: accountId and ParentId !=: masterCaseId and Status = 'Active'];
    }

    @AuraEnabled(cacheable=true)
    public static List<ServicePresenceStatus> getPresenceStatus(){
        return [SELECT DeveloperName,Id,IsDeleted,MasterLabel FROM ServicePresenceStatus];
    }
    
    @AuraEnabled
    public static RequestResult save(String caseEntityString){
        RequestResult result = new RequestResult();
        try{
            CaseEntity caseEntity = (CaseEntity)JSON.deserialize(caseEntityString, CaseEntity.class);

            // List<Case> childCases = new List<Case>();
            Map<Integer,Case> childCasesMap = new Map<Integer,Case>();
            Map<Integer,CRM_Global_CaseAssociatedItem__c> wrapUpMap = new Map<Integer,CRM_Global_CaseAssociatedItem__c>();
            List<CRM_Global_CaseAssociatedItem__c> wrapUps = new List<CRM_Global_CaseAssociatedItem__c>();
            List<CRM_Global_CaseAssociatedItem__c> wrapUpItems = new List<CRM_Global_CaseAssociatedItem__c>();
            Map<Integer,List<CRM_Global_CaseAssociatedItem__c>> wrapUpItemsMap = new Map<Integer,List<CRM_Global_CaseAssociatedItem__c>>();
            Integer index = 1;

            Case masterCase = new Case(
                Id = caseEntity.id,
                // RecordTypeId = caseEntity.recordTypeId,
                RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Master_Inbound').getRecordTypeId(),
                Status = caseEntity.status,
                Subject = caseEntity.subject,
                Origin = caseEntity.caseOrigin,
                OwnerId = caseEntity.ownerId,
                Priority = caseEntity.priority,
                CRM_Global_EnquirerName__c = caseEntity.enquirerName,
                ContactId = caseEntity.personContactId,
                AccountId = caseEntity.accountId,
                CRM_Global_ContactNumber__c = caseEntity.contactNo,
                CRM_Global_EnquirySummary__c = caseEntity.enquirySummary,
                CRM_Global_FirstContactResolution__c = caseEntity.firstContactResolution,
                // walk-in
                CRM_Global_TicketNumber__c = caseEntity.ticketNumber,
                CRM_Global_CounterNumber__c = caseEntity.counterNumber,
                CRM_Global_WalkInStartTime__c = caseEntity.startTime,
                CRM_Global_LocationOfTheCentre__c = caseEntity.locationOfTheCentre,
                CRM_Global_AccompanyBy__c = caseEntity.accompanyBy,
                CRM_Global_WalkInEndTime__c = caseEntity.endTime,
                // letter
                CRM_Global_LetterSender__c = caseEntity.letterSender,
                CRM_Global_ForwardedTheLetterTo__c = caseEntity.forwardedTheLetterTo,
                CRM_Global_ChannelOfReceipt__c = caseEntity.channelOfReceipt,
                CRM_Global_LogNumber__c = caseEntity.logNumber,
                CRM_Global_LetterRecipient__c = caseEntity.letterRecipient,
                CRM_Global_DateOfReceipt__c = caseEntity.dateOfReceipt,
                CRM_Global_DocumentType__c = caseEntity.documentType,
                // virtual meeting
                CRM_Global_ScheduledTime__c = caseEntity.scheduledTime,
                CRM_Global_VM_Attendance__c = caseEntity.attendance,
                CRM_Global_VM_MeetingLink__c = caseEntity.meetingLink
            );
            if(caseEntity.ignoreMaster == false) upsert masterCase;

            // get Interaction Id
            String interactionId = getInteractionId(caseEntity.caseOrigin,masterCase);

            // Child Case
            for(childCaseEntity child : caseEntity.childCases){
                Case childCase = new Case(
                    RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Enquiry').getRecordTypeId(),
                    Status = child.active == true ? 'Active' : 'Completed',
                    Subject = caseEntity.subject,
                    Origin = caseEntity.caseOrigin,
                    OwnerId = caseEntity.ownerId,
                    Priority = caseEntity.priority,
                    CRM_Global_EnquirerName__c = caseEntity.enquirerName,
                    ContactId = caseEntity.personContactId,
                    AccountId = caseEntity.accountId,
                    CRM_Global_ContactNumber__c = caseEntity.contactNo,
                    CRM_Global_CaseActive__c = child.active,
                    CRM_Global_NonPolicyEnquiry__c = child.nonPolicy,
                    CRM_Global_NextFollowUpDate__c = child.nextFollowUpDate,
                    ParentId = masterCase.Id,
                    CRM_Global_InquirerIdentity__c = child.inquirerIdentity,
                    // walk-in
                    CRM_Global_TicketNumber__c = caseEntity.ticketNumber,
                    CRM_Global_CounterNumber__c = caseEntity.counterNumber,
                    CRM_Global_StartTime__c = caseEntity.startTime,
                    CRM_Global_LocationOfTheCentre__c = caseEntity.locationOfTheCentre,
                    CRM_Global_AccompanyBy__c = caseEntity.accompanyBy,
                    CRM_Global_EndTime__c = caseEntity.endTime,
                    // letter
                    CRM_Global_LetterSender__c = caseEntity.letterSender,
                    CRM_Global_ForwardedTheLetterTo__c = caseEntity.forwardedTheLetterTo,
                    CRM_Global_ChannelOfReceipt__c = caseEntity.channelOfReceipt,
                    CRM_Global_LogNumber__c = caseEntity.logNumber,
                    CRM_Global_LetterRecipient__c = caseEntity.letterRecipient,
                    CRM_Global_DateOfReceipt__c = caseEntity.dateOfReceipt,
                    CRM_Global_DocumentType__c = caseEntity.documentType,
                    // virtual meeting
                    CRM_Global_ScheduledTime__c = caseEntity.scheduledTime,
                    CRM_Global_VM_Attendance__c = caseEntity.attendance,
                    CRM_Global_VM_MeetingLink__c = caseEntity.meetingLink
                );
                childCasesMap.put(index,childCase);

                // wrap up summary
                CRM_Global_CaseAssociatedItem__c wrapUp = new CRM_Global_CaseAssociatedItem__c(
                    RecordTypeId = Schema.SObjectType.CRM_Global_CaseAssociatedItem__c.getRecordTypeInfosByDeveloperName().get('Wrap_Up').getRecordTypeId(),
                    CRM_Global_EnquirySummary__c = caseEntity.enquirySummary,
                    CRM_Global_InteractionId__c = interactionId
                );
                wrapUpMap.put(index,wrapUp);

                List<policyEntity> policyList = new List<policyEntity>();
                if(child.nonPolicy == false) policyList.addAll(child.policyList);
                else policyList.add(new policyEntity());

                // 同一Case下的 Wrap up details
                List<CRM_Global_CaseAssociatedItem__c> wrapUpItems2Case = new List<CRM_Global_CaseAssociatedItem__c>();
                for(policyEntity policy : policyList){
                    for(String items : child.wrapUpItems){

                        String category;
                        String item;
                        if(items.indexOf(' > ') != -1){
                            String[] wrapUpVal = items.split(' > ');

                            if(wrapUpVal.size() >=2){
                                category = wrapUpVal[0];
                                item = wrapUpVal[1];
                            }
                            
                        }
                        CRM_Global_CaseAssociatedItem__c wrapUpItem = new CRM_Global_CaseAssociatedItem__c(
                            RecordTypeId = Schema.SObjectType.CRM_Global_CaseAssociatedItem__c.getRecordTypeInfosByDeveloperName().get('Wrap_Up_Details').getRecordTypeId(),
                            CRM_Global_RelatedPolicy__c = policy.id,
                            CRM_Global_WrapUpCategory__c = category,
                            CRM_Global_WrapUpItem__c = item
                        );
                        wrapUpItems2Case.add(wrapUpItem);
                    }
                }
                wrapUpItemsMap.put(index,wrapUpItems2Case);
                index++;
            }
            insert childCasesMap.values();

            System.debug('childCasesMap:'+JSON.serialize(childCasesMap));
            System.debug('wrapUpItemsMap:'+JSON.serialize(wrapUpItemsMap));

            // wrap up records look up case
            for(Integer i : wrapUpMap.keySet()){
                CRM_Global_CaseAssociatedItem__c wrapUp = wrapUpMap.get(i);
                wrapUp.CRM_Global_Case__c = childCasesMap.get(i).Id;
                wrapUps.add(wrapUp);
            }
            insert wrapUps;

            // wrap up details records look up case
            for(Integer i : wrapUpItemsMap.keySet()){
                for(CRM_Global_CaseAssociatedItem__c wrapUp : wrapUpItemsMap.get(i)){
                    wrapUp.CRM_Global_Case__c = childCasesMap.get(i).Id;
                    wrapUp.CRM_Global_WrapUp__c = wrapUpMap.get(i).Id;
                    wrapUpItems.add(wrapUp);
                }
            }
            insert wrapUpItems;

            // Update enquirySummary to Voice Call
            updateVoiceCall(masterCase.Id,caseEntity.enquirySummary);

            // New activity
            // createActivity(masterCase);

            Map<String,Object> dataMap = new Map<String,Object>();
            dataMap.put('masterCaseId',masterCase.Id);
            dataMap.put('enquiryCases',childCasesMap.values());
            result.statusCode = '0';
            result.message = 'Succuss';
            result.data = dataMap;
        }catch(Exception ex){
            System.debug('Save error==>'+'Line:'+ex.getLineNumber() +'   ' + ex.getMessage());
            result.statusCode = '-1';
            result.message = 'Save error==>'+' Line:'+ex.getMessage()+'   '+ex.getLineNumber();
            result.data = null;
        }
        return result;
    }

    @AuraEnabled
    public static RequestResult saveCaseWrapUp(String caseWrapUpEntityString){
        RequestResult result = new RequestResult();
        try{
            CaseWrapUpEntity wrapUpEntity = (CaseWrapUpEntity)JSON.deserialize(caseWrapUpEntityString, CaseWrapUpEntity.class);

            // List<Case> childCases = new List<Case>();
            Map<Integer,Case> childCasesMap = new Map<Integer,Case>();
            Map<Integer,CRM_Global_CaseAssociatedItem__c> wrapUpMap = new Map<Integer,CRM_Global_CaseAssociatedItem__c>();
            List<CRM_Global_CaseAssociatedItem__c> wrapUps = new List<CRM_Global_CaseAssociatedItem__c>();
            List<CRM_Global_CaseAssociatedItem__c> wrapUpItems = new List<CRM_Global_CaseAssociatedItem__c>();
            Map<Integer,List<CRM_Global_CaseAssociatedItem__c>> wrapUpItemsMap = new Map<Integer,List<CRM_Global_CaseAssociatedItem__c>>();
            List<Case> equiryCaseList = new List<Case>();
            Set<String> masterCaseIds = new Set<String>();
            List<Case> updateMasterCaseList = new List<Case>();
            Integer index = 1;

            // get Interaction Id
            // String interactionId = getInteractionId('Call',masterCase);

            childCaseEntity wrapUpDetails = wrapUpEntity.childCases[0];
            // selected enquiry Case
            for(selectedCaseEntity enquiryCase : wrapUpEntity.selectedCases){
                // wrap up summary
                CRM_Global_CaseAssociatedItem__c wrapUp = new CRM_Global_CaseAssociatedItem__c(
                    RecordTypeId = Schema.SObjectType.CRM_Global_CaseAssociatedItem__c.getRecordTypeInfosByDeveloperName().get('Wrap_Up').getRecordTypeId(),
                    CRM_Global_EnquirySummary__c = wrapUpEntity.enquirySummary,
                    CRM_Global_Channel__c = wrapUpEntity.channel,
                    CRM_Global_InteractionId__c = null,
                    CRM_Global_Case__c = enquiryCase.id
                );
                wrapUpMap.put(index,wrapUp);

                // update master case status
                if(!masterCaseIds.contains(enquiryCase.id)){
                    masterCaseIds.add(enquiryCase.id);
                    Case updateMasterCase = new Case(
                        Id = enquiryCase.masterCaseId,
                        Status = wrapUpEntity.masterCaseStatus
                    );
                    if(wrapUpEntity.masterCaseStatus == 'Completed') {
                        updateMasterCase.CRM_Global_CompletionDate__c = System.now();
                    }
                    updateMasterCaseList.add(updateMasterCase);
                }

                List<policyEntity> policyList = new List<policyEntity>();
                if(wrapUpDetails.nonPolicy == false) {
                    policyList.addAll(wrapUpDetails.policyList);
                }
                else {
                    policyList.add(new policyEntity());
                }
                
                // 同一Case下的 Wrap up details
                List<CRM_Global_CaseAssociatedItem__c> wrapUpItems2Case = new List<CRM_Global_CaseAssociatedItem__c>();
                for(policyEntity policy : policyList){
                    for(String items : wrapUpDetails.wrapUpItems){

                        String category;
                        String item;
                        if(items.indexOf(' > ') != -1){
                            String[] wrapUpVal = items.split(' > ');

                            if(wrapUpVal.size() >=2){
                                category = wrapUpVal[0];
                                item = wrapUpVal[1];
                            }
                            
                        }
                        CRM_Global_CaseAssociatedItem__c wrapUpItem = new CRM_Global_CaseAssociatedItem__c(
                            RecordTypeId = Schema.SObjectType.CRM_Global_CaseAssociatedItem__c.getRecordTypeInfosByDeveloperName().get('Wrap_Up_Details').getRecordTypeId(),
                            CRM_Global_RelatedPolicy__c = policy.id,
                            CRM_Global_WrapUpCategory__c = category,
                            CRM_Global_WrapUpItem__c = item,
                            CRM_Global_Case__c = enquiryCase.id
                        );
                        wrapUpItems2Case.add(wrapUpItem);
                    }
                }
                wrapUpItemsMap.put(index,wrapUpItems2Case);
                index++;

                // Update equiry cases status
                Case equiryCase = new Case(
                    Id = enquiryCase.id,
                    Status = wrapUpDetails.active == true ? 'Active' : 'Completed'
                );
                equiryCaseList.add(equiryCase);
            }
            System.debug('childCasesMap:'+JSON.serialize(childCasesMap));
            System.debug('wrapUpItemsMap:'+JSON.serialize(wrapUpItemsMap));

            insert wrapUpMap.values();

            // wrap up details records look up case
            for(Integer i : wrapUpItemsMap.keySet()){
                for(CRM_Global_CaseAssociatedItem__c wrapUp : wrapUpItemsMap.get(i)){
                    // wrapUp.CRM_Global_Case__c = childCasesMap.get(i).Id;
                    wrapUp.CRM_Global_WrapUp__c = wrapUpMap.get(i).Id;
                    wrapUpItems.add(wrapUp);
                }
            }
            insert wrapUpItems;

            // Update equiry cases
            update equiryCaseList;

            // Update master cases
            update updateMasterCaseList;


            // Update enquirySummary to Voice Call
            // updateVoiceCall(masterCase.Id,wrapUpEntity.enquirySummary);

            // New activity
            // createActivity(masterCase);

            // defer chat send SMS
            if(wrapUpEntity.caseOrigin == 'Defer Chat'){
                sendDeferChatSMS(wrapUpEntity.contactNumber, wrapUpEntity.accountId);
            }

            Map<String,String> dataMap = new Map<String,String>();
            // dataMap.put('caseId',masterCase.Id);
            result.statusCode = '0';
            result.message = 'Succuss';
            result.data = dataMap;
        }catch(Exception ex){
            System.debug('Save error==>'+'Line:'+ex.getLineNumber() +'   ' + ex.getMessage());
            result.statusCode = '-1';
            result.message = 'Save error==>'+' Line:'+ex.getMessage()+'   '+ex.getLineNumber();
            result.data = null;
        }
        return result;
    }

    @future
    public static void updateVoiceCall(String masterCaseId, String enquirySummary){
        VoiceCall vc = [select Id,CRM_Global_EnquirySummary__c from VoiceCall where RelatedRecordId =: masterCaseId limit 1];
        if(vc != null){
            vc.CRM_Global_EnquirySummary__c = enquirySummary;
            update vc;
        }
    }

    public static String createActivity(Case masterCase){
        Task activity = new Task(
            WhatId = masterCase.Id,
            WhoId = masterCase.ContactId,
            RecordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName().get('ClientAssociateTask').getRecordTypeId(),
            Status = 'Active',
            CRM_Global_CaseOrigin__c = masterCase.Origin,
            Subject = masterCase.Subject
        );
        insert activity;
        return activity.Id;
    }

    public static String getInteractionId(String caseOrigin,Case masterCase) {
        String interactionId;
        switch on caseOrigin {
            when 'Call' {
                List<VoiceCall> vc = [select Id,CRM_Global_EnquirySummary__c from VoiceCall where RelatedRecordId =: masterCase.Id limit 1];
                createActivity(masterCase);
                interactionId = vc.size() > 0 ? vc[0].Id : null;
            }
            when 'Email' {
                interactionId = null;
            }
            when 'Defer Chat' {
                interactionId = null;
            }   
            when 'Walk-in','Letter','E-enquiry' {
                interactionId = createActivity(masterCase);
            }
            when else  {
                interactionId = null;
            }
        }
        return interactionId;
    }

    @future(callout=true)
    public static void sendDeferChatSMS(String recipientNumber,String accountId){
        String preferLanguage = getPreferLanguage(accountId);

        List<EmailTemplate> templates = new List<EmailTemplate>();

        switch on preferLanguage {
            when 'Chinese' {
                templates = [SELECT Id, Name, Subject, HtmlValue, Body, DeveloperName FROM EmailTemplate WHERE DeveloperName = 'Defer_Chat_Enquiry_Case_Outbound_Wrap_Up_TC_1762515613556' and IsActive = true];
            }
            when 'English' {
                templates = [SELECT Id, Name, Subject, HtmlValue, Body, DeveloperName FROM EmailTemplate WHERE DeveloperName = 'Defer_Chat_Enquiry_Case_Outbound_Wrap_Up_EN_1762515555411' and IsActive = true];
            }
            when else {
                templates = [SELECT Id, Name, Subject, HtmlValue, Body, DeveloperName FROM EmailTemplate WHERE DeveloperName = 'Defer_Chat_Enquiry_Case_Outbound_Wrap_Up_TC_1762515613556' and IsActive = true];
            }
        }

        if(templates.size() > 0 && templates[0].HtmlValue != null){
            CRMGlobalSendSmsService.sendSms(recipientNumber, templates[0].HtmlValue, accountId);
        }   
    }

    public static String getPreferLanguage(String accountId){
        String result = null;
        CRM_Global_DataIntegration_Config__mdt config = CRMGlobalDataIntegrationController.getIntegrationConfig('Prulife_getCustomerInfo_Account');
        CRMGlobalDataIntegrationConfigWrapper configWrapper = new CRMGlobalDataIntegrationConfigWrapper(config, accountId);

        if(config.Integration_Type__c == 'External_API') {
            HttpResponse response = CRMGlobalDataIntegrationAPIService.callExternalApi(configWrapper);
            Object responseData = CRMGlobalDataIntegrationAPIService.parseApiResponse(configWrapper, response);

            if (responseData != null && responseData instanceOf Map<String, Object>){
                Map<String, Object> dataMap = (Map<String, Object>)responseData;
                if (dataMap.containsKey('Results') && dataMap.get('Results') instanceOf List<Object> && ((List<Object>)dataMap.get('Results')).size() > 0) {
                    Map<String, Object> customerInfoMap = (Map<String, Object>)((List<Object>)dataMap.get('Results'))[0];

                    String preferLanguage = customerInfoMap.containsKey('fo_lang_pfr_ind')? (String)customerInfoMap.get('fo_lang_pfr_ind') : null;
                    switch on preferLanguage {
                        when 'C' {
                            result = 'Chinese';
                        }
                        when 'E' {
                            result = 'English';
                        }
                        when else  {
                            result = null;
                        }
                    }
                }
            }
        }
        System.debug(LoggingLevel.INFO, '#getPreferLanguage -> ' + result);
        return result;
    }

    public class CaseEntity{
		@AuraEnabled public String id{set;get;}
		@AuraEnabled public String recordTypeId{set;get;}
		@AuraEnabled public String status{set;get;}
		@AuraEnabled public String subject{set;get;}
		@AuraEnabled public String caseOrigin{set;get;}
		@AuraEnabled public String ownerId{set;get;}
		@AuraEnabled public String priority{set;get;}
		@AuraEnabled public String enquirerName{set;get;}
		@AuraEnabled public String personContactId{set;get;}
		@AuraEnabled public String contactEmail{set;get;}
		@AuraEnabled public String accountId{set;get;}
		@AuraEnabled public String clientCode{set;get;}
		@AuraEnabled public String contactNo{set;get;}
		@AuraEnabled public String IDNumber{set;get;}
		@AuraEnabled public String agentCode{set;get;}
		@AuraEnabled public String enquirySummary{set;get;}
		@AuraEnabled public Boolean firstContactResolution{set;get;}
        // walk-in
		@AuraEnabled public String ticketNumber{set;get;}
		@AuraEnabled public String counterNumber{set;get;}
        @AuraEnabled public Datetime startTime{set;get;}
		@AuraEnabled public String locationOfTheCentre{set;get;}
		@AuraEnabled public String accompanyBy{set;get;}
        @AuraEnabled public Datetime endTime{set;get;}
        // letter
		@AuraEnabled public String letterSender{set;get;}
		@AuraEnabled public String forwardedTheLetterTo{set;get;}
		@AuraEnabled public String channelOfReceipt{set;get;}
		@AuraEnabled public Decimal logNumber{set;get;}
        @AuraEnabled public String letterRecipient{set;get;}
		@AuraEnabled public Datetime dateOfReceipt{set;get;}
		@AuraEnabled public String documentType{set;get;}
        // 
		@AuraEnabled public Datetime scheduledTime{set;get;}
		@AuraEnabled public Datetime meetingStartDateTime{set;get;}
		@AuraEnabled public String attendance{set;get;}
		@AuraEnabled public String meetingLink{set;get;}
		@AuraEnabled public Datetime meetingEndDateTime{set;get;}
		@AuraEnabled public Boolean ignoreMaster{set;get;}
		@AuraEnabled public List<childCaseEntity> childCases{set;get;}
	}

    public class childCaseEntity{
        @AuraEnabled public String inquirerIdentity{set;get;}
        @AuraEnabled public Boolean active{set;get;}
		@AuraEnabled public Boolean nonPolicy{set;get;}
		@AuraEnabled public Date nextFollowUpDate{set;get;}
        @AuraEnabled public List<policyEntity> policyList{set;get;}
		@AuraEnabled public List<String> wrapUpItems{set;get;}
		@AuraEnabled public List<String> wrapUpReasons{set;get;}
		@AuraEnabled public List<String> wrapUpSuggestions{set;get;}
    }

    public class policyEntity{
		@AuraEnabled public String id{set;get;}
		@AuraEnabled public String name{set;get;}
	}

    public class RequestResult{
		@AuraEnabled public String statusCode{set;get;}
		@AuraEnabled public String message{set;get;}
		@AuraEnabled public Object data{set;get;}
	}

    public class selectedCaseEntity{
		@AuraEnabled public String id{set;get;}
		@AuraEnabled public String name{set;get;}
		@AuraEnabled public String masterCaseId{set;get;}
	}

    public class CaseWrapUpEntity{
        @AuraEnabled public String id{set;get;}
        @AuraEnabled public String caseOrigin{set;get;}
        @AuraEnabled public String contactNumber{set;get;}
        @AuraEnabled public String enquirySummary{set;get;}
        @AuraEnabled public String channel{set;get;}
        @AuraEnabled public String accountId{set;get;}
        @AuraEnabled public String masterCaseStatus{set;get;}
        @AuraEnabled public List<selectedCaseEntity> selectedCases{set;get;}
        @AuraEnabled public List<childCaseEntity> childCases{set;get;}
    }
}