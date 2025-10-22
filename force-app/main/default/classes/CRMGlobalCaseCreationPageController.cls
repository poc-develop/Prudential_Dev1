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
    
    @AuraEnabled
    public static RequestResult save(String caseEntityString){
        RequestResult result = new RequestResult();
        try{
            CaseEntity caseEntity = (CaseEntity)JSON.deserialize(caseEntityString, CaseEntity.class);

            // List<Case> childCases = new List<Case>();
            Map<Integer,Case> childCasesMap = new Map<Integer,Case>();
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
                    // CRM_Global_Policy__c = policy.id
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

                // 同一Case下的 Wrap up
                List<CRM_Global_CaseAssociatedItem__c> wrapUpItems2Case = new List<CRM_Global_CaseAssociatedItem__c>();
                for(policyEntity policy : child.policyList){
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
                        CRM_Global_CaseAssociatedItem__c wrapUp = new CRM_Global_CaseAssociatedItem__c(
                            CRM_Global_RelatedPolicy__c = policy.id,
                            CRM_Global_WrapUpCategory__c = category,
                            CRM_Global_WrapUpItem__c = item
                        );
                        wrapUpItems2Case.add(wrapUp);
                    }
                }
                wrapUpItemsMap.put(index,wrapUpItems2Case);
                index++;
            }
            insert childCasesMap.values();

            System.debug('childCasesMap:'+JSON.serialize(childCasesMap));
            System.debug('wrapUpItemsMap:'+JSON.serialize(wrapUpItemsMap));

            // wrap up records look up case
            for(Integer i : wrapUpItemsMap.keySet()){
                for(CRM_Global_CaseAssociatedItem__c wrapUp : wrapUpItemsMap.get(i)){
                    wrapUp.CRM_Global_Case__c = childCasesMap.get(i).Id;
                    wrapUpItems.add(wrapUp);
                }
            }
            insert wrapUpItems;

            // Update enquirySummary to Voice Call
            updateVoiceCall(masterCase.Id,caseEntity.enquirySummary);

            // New activity
            createActivity(masterCase);

            Map<String,String> dataMap = new Map<String,String>();
            dataMap.put('caseId',masterCase.Id);
            result.statusCode = '0';
            result.message = 'Succuss';
            result.data = dataMap;
        }catch(Exception ex){
            System.debug('Save error==>'+'Line:'+ex.getLineNumber() +'   ' + ex.getMessage());
            result.statusCode = '-1';
            result.message = ex.getMessage()+'   '+ex.getLineNumber();
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

    public static void createActivity(Case masterCase){
        Task activity = new Task(
            WhatId = masterCase.Id,
            RecordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName().get('ClientAssociateTask').getRecordTypeId(),
            Status = 'Active',
            CRM_Global_CaseOrigin__c = masterCase.Origin,
            Subject = masterCase.Subject
        );
        insert activity;
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
        // walk-in
		@AuraEnabled public Decimal ticketNumber{set;get;}
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





    public class DependencyResult {
        public String controllingFieldName;
        public String dependentFieldName;
        public Map<String, List<String>> dependencyMap;
        
        public DependencyResult(String ctrlField, String depField, Map<String, List<String>> depMap) {
            this.controllingFieldName = ctrlField;
            this.dependentFieldName = depField;
            this.dependencyMap = depMap;
        }
    }
    
    public static DependencyResult getFieldDependency(String objectName, String dependentFieldName, String controllingFieldName) {
        Map<String, List<String>> dependencyMap = new Map<String, List<String>>();
        
        try {
            // 获取对象类型
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            if (objType == null) {
                throw new IllegalArgumentException('对象不存在: ' + objectName);
            }
            
            // 获取字段映射
            Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
            
            // 获取依赖字段
            Schema.SObjectField dependentField = fieldMap.get(dependentFieldName);
            if (dependentField == null) {
                throw new IllegalArgumentException('依赖字段不存在: ' + dependentFieldName);
            }
            
            Schema.DescribeFieldResult dependentFieldDescribe = dependentField.getDescribe();
            
            // 获取控制字段
            Schema.SObjectField controllingField = fieldMap.get(controllingFieldName);
            if (controllingField == null) {
                throw new IllegalArgumentException('控制字段不存在: ' + controllingFieldName);
            }
            
            Schema.DescribeFieldResult controllingFieldDescribe = controllingField.getDescribe();
            
            // 获取picklist值
            List<Schema.PicklistEntry> controllingEntries = controllingFieldDescribe.getPicklistValues();
            List<Schema.PicklistEntry> dependentEntries = dependentFieldDescribe.getPicklistValues();
            
            // 使用JSON序列化来访问隐藏的validFor属性
            String dependentEntriesJSON = JSON.serialize(dependentEntries);
            List<Map<String, Object>> dependentEntriesMap = (List<Map<String, Object>>)JSON.deserializeUntyped(dependentEntriesJSON);
            
            // 初始化依赖映射
            for (Schema.PicklistEntry ctrlEntry : controllingEntries) {
                dependencyMap.put(ctrlEntry.getValue(), new List<String>());
            }
            
            // 处理每个依赖字段条目
            for (Integer i = 0; i < dependentEntries.size(); i++) {
                Schema.PicklistEntry depEntry = dependentEntries[i];
                Map<String, Object> depEntryMap = dependentEntriesMap[i];
                
                // 检查是否有validFor属性
                if (depEntryMap.containsKey('validFor')) {
                    String validFor = String.valueOf(depEntryMap.get('validFor')); // 确保转换为字符串
                    
                    if (validFor != null && validFor != '') {
                        List<Integer> validIndexes = decodeValidFor(validFor);
                        
                        for (Integer index : validIndexes) {
                            if (index < controllingEntries.size()) {
                                String controllingValue = controllingEntries[index].getValue();
                                // 确保值存在再添加
                                if (dependencyMap.containsKey(controllingValue)) {
                                    dependencyMap.get(controllingValue).add(depEntry.getValue());
                                }
                            }
                        }
                    }
                }
            }
            
            return new DependencyResult(controllingFieldName, dependentFieldName, dependencyMap);
            
        } catch (Exception e) {
            System.debug('获取字段依赖关系时出错: ' + e.getMessage());
            System.debug('堆栈跟踪: ' + e.getStackTraceString());
            throw e;
        }
    }
    
    // 修复后的解码方法
    private static List<Integer> decodeValidFor(String validFor) {
        List<Integer> indexes = new List<Integer>();
        
        if (validFor == null || validFor == '') {
            return indexes;
        }
        
        try {
            // Base64解码
            Blob blobValue = EncodingUtil.base64Decode(validFor);
            if (blobValue != null) {
                // 将Blob转换为十六进制字符串
                String hexString = EncodingUtil.convertToHex(blobValue);
                
                // 将十六进制字符串转换为二进制字符串
                String binaryString = '';
                for (Integer i = 0; i < hexString.length(); i++) {
                    String hexChar = hexString.substring(i, i + 1).toLowerCase();
                    String binaryNibble = hexCharToBinary(hexChar);
                    binaryString += binaryNibble;
                }
                
                System.debug('二进制字符串: ' + binaryString);
                System.debug('二进制字符串长度: ' + binaryString.length());
                
                // 从右向左读取位（最低有效位优先）
                for (Integer i = 0; i < binaryString.length(); i++) {
                    // 注意：这里比较字符，不是整数
                    String bit = binaryString.substring(binaryString.length() - 1 - i, binaryString.length() - i);
                    if (bit == '1') { // 比较字符串和字符串
                        indexes.add(i);
                    }
                }
            }
        } catch (Exception e) {
            System.debug('解码ValidFor时出错: ' + e.getMessage());
        }
        
        return indexes;
    }
    
    // 十六进制字符转4位二进制
    private static String hexCharToBinary(String hexChar) {
        Map<String, String> hexToBinMap = new Map<String, String>{
            '0' => '0000', '1' => '0001', '2' => '0010', '3' => '0011',
            '4' => '0100', '5' => '0101', '6' => '0110', '7' => '0111',
            '8' => '1000', '9' => '1001', 'a' => '1010', 'b' => '1011',
            'c' => '1100', 'd' => '1101', 'e' => '1110', 'f' => '1111'
        };
        
        return hexToBinMap.get(hexChar.toLowerCase());
    }
    
    // 格式化输出依赖关系
    public static String formatDependencyResult(DependencyResult result) {
        if (result == null || result.dependencyMap == null) {
            return '无依赖关系数据';
        }
        
        String output = '';
        output += '控制字段: ' + result.controllingFieldName + '\n';
        output += '依赖字段: ' + result.dependentFieldName + '\n';
        output += '依赖关系:\n';
        
        Boolean hasDependencies = false;
        for (String controllingValue : result.dependencyMap.keySet()) {
            List<String> dependentValues = result.dependencyMap.get(controllingValue);
            if (dependentValues != null && !dependentValues.isEmpty()) {
                output += controllingValue + ' > ' + String.join(dependentValues, ', ') + '\n';
                hasDependencies = true;
            }
        }
        
        if (!hasDependencies) {
            output += '未找到依赖关系\n';
        }
        
        return output;
    }
}