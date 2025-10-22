public with sharing class CRMGlobalCustomerPolicySearchController {
    public final static Integer SEARCH_LIMIT = 20;
    public final static String SEARCH_TARGRT_ALL_FIELDS = 'ALL FIELDS';
    // public final static String VEHICLE_REGISTRATION_NUMBER = 'VehicleRegistrationNumber';
    public static Set<String> insurancePolicyParticipantFieldSet = InsurancePolicyParticipant.getSobjectType().getDescribe().fields.getMap().keySet();
    public static Set<String> insurancePolicyParticipantQueryBasicFieldSet = new Set<String>{
            'Name',
            'Id',
            'PolicyType',
            'Status',
            'NameInsured.CRM_Global_PrivacyFlag__c',
            'NameInsured.Name'
    };
    // public static Set<String> insurancePolicyParticipantQueryBasicFieldSet = new Set<String>{
    //     'Name',
    //     'InsurancePolicyId',
    //     'InsurancePolicy.Name',
    //     'InsurancePolicy.PolicyNo__c',
    //     'InsurancePolicy.PolicyType',
    //     'InsurancePolicy.Status',
    //     'PrimaryParticipantAccountId',
    //     'PrimaryParticipantAccount.FinServ__Status__c',
    //     'PrimaryParticipantAccount.Name',
    //     'PrimaryParticipantAccount.CustomerChineseName__c',
    //     'EnglishName__c',
    //     'ChineseName__c',
    //     'AddressLine1__c',
    //     'AddressLine2__c',
    //     'AddressLine3__c',
    //     'AddressLine4__c',
    //     'AddressLine5__c',
    //     'PostalCode__c'
    // };
    // public final static List<CaseCreationFieldMapping__mdt> CASE_CREATION_FIELD_MAPPINGS = (CaseCreationFieldMapping__mdt.getAll()).values();

    public static Set<String> noAllowProfileNameSet = new Set<String>{ 'System Administrator'};

    @AuraEnabled
    public static Boolean checkPolicyParticipantClickable() {
        Boolean policyParticipantClickable = true;
        Set<Id> noAllowProfileIdSet = new Set<Id>();
        for (Profile profileTemp : [SELECT Id, Name FROM Profile WHERE Name IN :noAllowProfileNameSet]) {
            noAllowProfileIdSet.add(profileTemp.Id);
        }
        if (noAllowProfileIdSet.contains(UserInfo.getProfileId())) {
            policyParticipantClickable = false;
        }
        return policyParticipantClickable;
    }

    @AuraEnabled
    public static List<Object> queryCustomAndPolicy(List<Map<String, Object>> searchParams) {
        List<Object> resultList = new List<Object>();
        if (searchParams.size() == 0) {
            return resultList;
        }

        Boolean needExecuteNextQuery = true;
        Boolean hadQuery = false;
        Set<Id> previousSearchResultIdSet = new Set<Id>();
        Set<String> insurancePolicyParticipantQueryFieldSet = new Set<String>();
        Map<Id, String> insurancePolicyIdAssetNameMap = new Map<Id, String>();
        Map<String, SearchObject> returningObjectTypeNameSearchObjectMap = new Map<String, SearchObject>();
        Map<String, SearchObject> developerNameSearchObjectMap = new Map<String, SearchObject>();
        Map<Id, Account> participantIdPolicyOwnerMap = new Map<Id, Account>();
        Map<String, SearchCondition__mdt> developerNameSearchConditionMap = new Map<String, SearchCondition__mdt>();
        Map<String, PolicySearchResultColumn__mdt> developerNameResultColumnMap = new Map<String, PolicySearchResultColumn__mdt>();
        List<InsurancePolicy> participantQueryResultList = new List<InsurancePolicy>();

        // Boolean searchVehicleRegistrationNumber = false;

        String searchValueVehicleRegistrationNumber = '';
        String selectString = '';
        String soqlConditionString = '';
        for (Map<String, Object> searchParam : searchParams) {
            String searchTarget = searchParam.get('searchTarget').toString().trim();
            String value = searchParam.get('value').toString().trim();
			System.debug('[queryCustomAndPolicy] searchTarget=' + searchTarget);
			System.debug('[queryCustomAndPolicy] searchvalue=' + value);
            // if (String.isNotBlank(value) && searchTarget.equalsIgnoreCase(VEHICLE_REGISTRATION_NUMBER)) {
            //     searchVehicleRegistrationNumber = true;
            //     searchValueVehicleRegistrationNumber = value;
            //     continue;
            // }
            if (searchParam.containsKey('executionLanguage') && searchParam.get('executionLanguage').equals('SOSL')) {
                continue;
            }
            if (searchParam.containsKey('matchingRule') && searchParam.get('matchingRule').equals('Partial Match')) {
                String likeValue = value + '%';
                if (searchTarget.contains('.')) {
                    String anotherObjectName = searchTarget.substringBefore('.');
                    String anotherObjectNameField = anotherObjectName;
                    if (anotherObjectNameField.containsIgnoreCase('__r')) {
                        anotherObjectNameField.replace('__r', '__c');
                    } else {
                        anotherObjectNameField += 'Id';
                    }
                    String anotherSearchTarget = searchTarget.substringAfter('.');
                    soqlConditionString +=
                        anotherObjectNameField +
                        ' IN (SELECT Id FROM ' +
                        anotherObjectName +
                        ' WHERE ' +
                        anotherSearchTarget +
                        ' LIKE \'' +
                        likeValue +
                        '\') AND ';
                } else {
                    System.debug('[queryCustomAndPolicy] else=' + searchTarget);
					if (searchTarget.contains(':')) {
                        System.debug('[queryCustomAndPolicy] replace=' + searchTarget);
                        String replaceObjectName = searchTarget.substringBefore(':') + 
                            		'.' + searchTarget.substringAfter(':');
						searchTarget = replaceObjectName;
                        System.debug('[queryCustomAndPolicy] replace=' + searchTarget);
					}
					soqlConditionString += searchTarget + ' LIKE \'' + likeValue + '\' AND ';
                }
				//System.debug('[queryCustomAndPolicy] matchingRule=' + soqlConditionString);
            } else if (searchParam.get('name').toString().containsIgnoreCase('Date')) {
                Date dateValue = Date.valueOf(value);
                soqlConditionString += searchTarget + ' = ' + String.valueOf(dateValue) + ' AND ';
				//System.debug('[queryCustomAndPolicy] Date=' + soqlConditionString);
            } else {
                soqlConditionString += searchTarget + ' = \'' + value + '\' AND ';
				//System.debug('[queryCustomAndPolicy] else=' + soqlConditionString);
            }
        }

		System.debug('[queryCustomAndPolicy] final=' + soqlConditionString);
        // if (searchVehicleRegistrationNumber) {
        //     Set<Id> vehicleRegistrationNumberResultIdSet = new Set<Id>();
        //     for (InsurancePolicyAsset reader : [
        //         SELECT Id, InsurancePolicyId, AssetName
        //         FROM InsurancePolicyAsset
        //         WHERE AssetName = :searchValueVehicleRegistrationNumber
        //     ]) {
        //         if (String.isNotBlank(reader.AssetName)) {
        //             insurancePolicyIdAssetNameMap.put(reader.InsurancePolicyId, reader.AssetName);
        //         }
        //     }
        //     for (InsurancePolicyParticipant reader : [
        //         SELECT Id, InsurancePolicyId
        //         FROM InsurancePolicyParticipant
        //         WHERE InsurancePolicyId IN :insurancePolicyIdAssetNameMap.keySet()
        //     ]) {
        //         vehicleRegistrationNumberResultIdSet.add(reader.Id);
        //     }
        //     if (vehicleRegistrationNumberResultIdSet.isEmpty()) {
        //         needExecuteNextQuery = false;
        //     } else {
        //         previousSearchResultIdSet = (vehicleRegistrationNumberResultIdSet);
        //     }
        // }

        if (needExecuteNextQuery) {
            insurancePolicyParticipantQueryFieldSet.addAll(insurancePolicyParticipantQueryBasicFieldSet);
            List<String> insurancePolicyParticipantQueryFieldList = new List<String>();
            for (SearchCondition__mdt next : CRMGlobalSearchResultColumnController.getSearchConditionMdtList()) {
                developerNameSearchConditionMap.put(next.DeveloperName, next);
                if (next.ExecutionLanguage__c.equals('SOQL') && String.isNotBlank(next.SearchTarget__c)) {
                    for (String fieldNameString : next.SearchTarget__c.split(',')) {
                        insurancePolicyParticipantQueryFieldList.add(fieldNameString.trim());
                    }
                } else if (
                    next.ExecutionLanguage__c.equals('SOSL') &&
                    next.ReturningObjectTypeName__c.equalsIgnoreCase('InsurancePolicyParticipant') &&
                    String.isNotBlank(next.ReturningFields__c)
                ) {
                    for (String fieldNameString : next.ReturningFields__c.split(',')) {
                        insurancePolicyParticipantQueryFieldList.add(fieldNameString.trim());
                    }
                }
            }
            for (PolicySearchResultColumn__mdt next : CRMGlobalSearchResultColumnController.getPolicySearchResultColumnMdtList()) {
                developerNameResultColumnMap.put(next.DeveloperName, next);
                if (String.isNotBlank(next.FieldName__c)) {
                    for (String fieldNameString : next.FieldName__c.split(',')) {
                        insurancePolicyParticipantQueryFieldList.add(fieldNameString.trim());
                    }
                }
            }
            // for (CaseCreationFieldMapping__mdt next : CASE_CREATION_FIELD_MAPPINGS) {
            //     if (String.isNotBlank(next.SourceFieldName__c)) {
            //         insurancePolicyParticipantQueryFieldList.add(next.SourceFieldName__c.trim());
            //     }
            // }
            for (String next : insurancePolicyParticipantQueryFieldList) {
                if (next.contains('.') || insurancePolicyParticipantFieldSet.contains(next.toLowerCase())) {
                    insurancePolicyParticipantQueryFieldSet.add(next);
                }
            }
            insurancePolicyParticipantQueryFieldSet.remove('Id');

            selectString = 'SELECT Id';
            for (String fieldApiName : insurancePolicyParticipantQueryFieldSet) {
                selectString += ', ' + fieldApiName;
            }
            selectString += ' FROM InsurancePolicy';

            if (String.isNotBlank(soqlConditionString)) {
                hadQuery = true;
                participantQueryResultList = queryPolicyParticipant(selectString, soqlConditionString, 'LIMIT 50000', previousSearchResultIdSet);
                if (participantQueryResultList.isEmpty()) {
                    needExecuteNextQuery = false;
                } else {
                    Set<Id> participantQueryResultIdSet = new Set<Id>();
                    for (InsurancePolicy reader : participantQueryResultList) {
                        participantQueryResultIdSet.add(reader.Id);
                    }
                    previousSearchResultIdSet = participantQueryResultIdSet;
                }
            }
        }

        if (needExecuteNextQuery) {
            for (Map<String, Object> searchParam : searchParams) {
                System.debug('[groupSearchObject] searchParam=' + searchParam);
                if (searchParam.containsKey('executionLanguage') && searchParam.get('executionLanguage').equals('SOSL')) {
                    String searchKeyWord = '';
                    if (searchParam.containsKey('matchingRule') && searchParam.get('matchingRule').toString().equals('Exact Match')) {
                        searchKeyWord = searchParam.get('value').toString().trim();
                    } else {
                        searchKeyWord = searchParam.get('value').toString().trim() + '*';
                    }
                    String searchTarget = SEARCH_TARGRT_ALL_FIELDS;
                    if (searchParam.get('searchTarget') != null) {
                        searchTarget = searchParam.get('searchTarget').toString();
                    }
                    String returningObjectTypeName = searchParam.get('returningObjectTypeName').toString();
                    String returningFields = searchParam.get('returningFields').toString();
                    String developerName = searchParam.get('name').toString();
                    Set<String> returningFieldSet = new Set<String>();
                    for (String returningField : returningFields.split(',')) {
                        returningFieldSet.add(returningField.trim());
                    }
                    String key = returningObjectTypeName;
                    SearchObject searchObject = new SearchObject();
                    SearchObject.searchTarget = searchTarget;
                    SearchObject.returningObjectTypeName = returningObjectTypeName;
                    SearchObject.searchKeyWord = '"' + searchKeyWord + '"';
                    SearchObject.returningFieldSet = returningFieldSet;
                    if (!developerNameSearchObjectMap.containsKey(developerName)) {
                        developerNameSearchObjectMap.put(developerName, searchObject);
                        System.debug('[groupSearchObject] developerName=' + developerName);
                        System.debug('[groupSearchObject] searchObject=' + searchObject);
                    }
                    if (returningObjectTypeNameSearchObjectMap.containsKey(key)) {
                        if (returningObjectTypeNameSearchObjectMap.get(key).searchTarget != searchTarget) {
                            returningObjectTypeNameSearchObjectMap.get(key).searchTarget = SEARCH_TARGRT_ALL_FIELDS;
                        }
                        if (String.isNotBlank(returningObjectTypeNameSearchObjectMap.get(key).searchKeyWord)) {
                            returningObjectTypeNameSearchObjectMap.get(key).searchKeyWord += ' AND "' + searchKeyWord + '"';
                        } else {
                            returningObjectTypeNameSearchObjectMap.get(key).searchKeyWord = '"' + searchKeyWord + '"';
                        }
                        returningObjectTypeNameSearchObjectMap.get(key).returningFieldSet.addAll(returningFieldSet);
                    } else {
                        // new returningObjectTypeSearchObject to avoid the same refer in developerNameSearchObjectMap
                        SearchObject returningObjectTypeSearchObject = new SearchObject();
                        returningObjectTypeSearchObject.searchTarget = searchObject.searchTarget;
                        returningObjectTypeSearchObject.returningObjectTypeName = searchObject.returningObjectTypeName;
                        returningObjectTypeSearchObject.searchKeyWord = searchObject.searchKeyWord;
                        returningObjectTypeSearchObject.returningFieldSet = searchObject.returningFieldSet;
                        returningObjectTypeNameSearchObjectMap.put(key, returningObjectTypeSearchObject);
                        System.debug('[groupSearchObject] key=' + key);
                        System.debug('[groupSearchObject] returningObjectTypeSearchObject=' + returningObjectTypeSearchObject);
                    }
                }
            }
            System.debug('[groupSearchObject] developerNameSearchObjectMap=' + developerNameSearchObjectMap);
            System.debug('[groupSearchObject] returningObjectTypeNameSearchObjectMap=' + returningObjectTypeNameSearchObjectMap);
            if (returningObjectTypeNameSearchObjectMap.size() > SEARCH_LIMIT) {
                needExecuteNextQuery = false;
            }
            if (needExecuteNextQuery && returningObjectTypeNameSearchObjectMap.get('InsurancePolicyParticipant') != null) {
                Set<Id> participantSearchResultIdSet = findResultThroughSOSL(
                    returningObjectTypeNameSearchObjectMap.get('InsurancePolicyParticipant'),
                    previousSearchResultIdSet
                );
                if (participantSearchResultIdSet.isEmpty()) {
                    needExecuteNextQuery = false;
                } else {
                    previousSearchResultIdSet = participantSearchResultIdSet;
                }
            }
        }

        List<InsurancePolicy> insurancePolicyParticipantList = new List<InsurancePolicy>();

        if (needExecuteNextQuery && previousSearchResultIdSet.size() > 0) {
            if (hadQuery && participantQueryResultList.size() > 0) {
                for (InsurancePolicy reader : participantQueryResultList) {
                    if (previousSearchResultIdSet.contains(reader.Id)) {
                        insurancePolicyParticipantList.add(reader);
                    }
                }
            } else if (!hadQuery) {
                insurancePolicyParticipantList = queryPolicyParticipant(selectString, '', 'LIMIT 500', previousSearchResultIdSet);
            }
        }

        if (!insurancePolicyParticipantList.isEmpty()) {
            participantIdPolicyOwnerMap = getInsurancePolicyOwner(insurancePolicyParticipantList);
            resultList = encapsulateResult(
                insurancePolicyParticipantList,
                previousSearchResultIdSet,
                insurancePolicyIdAssetNameMap,
                participantIdPolicyOwnerMap,
                developerNameSearchObjectMap,
                developerNameSearchConditionMap,
                developerNameResultColumnMap
            );
        }
        return resultList;
    }

    public static List<InsurancePolicy> queryPolicyParticipant(
        String selectString,
        String soqlConditionString,
        String limitString,
        Set<Id> previousSearchResultIdSet
    ) {
        String query = selectString;
        String whereClause = '';
        if (!previousSearchResultIdSet.isEmpty()) {
            whereClause += 'Id IN :previousSearchResultIdSet AND ';
        }
        if (String.isNotBlank(soqlConditionString)) {
            whereClause += soqlConditionString;
        }
        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause.substringBeforeLast(' AND ');
        }
        query += ' ORDER BY Name DESC NULLS LAST, CreatedDate DESC ' + limitString;

        System.debug('[queryPolicyParticipant] query=' + query);
        List<InsurancePolicy> insurancePolicyParticipantList = Database.query(query);
        System.debug('[queryPolicyParticipant] insurancePolicyParticipantList.size()=' + insurancePolicyParticipantList.size());
        return insurancePolicyParticipantList;
    }

    public static Map<Id, Account> getInsurancePolicyOwner(List<InsurancePolicy> insurancePolicyParticipantList) {
        Map<Id, Account> participantIdPolicyOwnerMap = new Map<Id, Account>();
        Set<Id> insurancePolicyIdSet = new Set<Id>();

        for (InsurancePolicy participant : insurancePolicyParticipantList) {
            insurancePolicyIdSet.add(participant.Id);
        }

        for (InsurancePolicy participant : [
            SELECT Id, Name, NameInsuredId, NameInsured.Name
            FROM InsurancePolicy
            WHERE Id IN :insurancePolicyIdSet
        ]) {
            participantIdPolicyOwnerMap.put(participant.Id, participant.NameInsured);
        }
        return participantIdPolicyOwnerMap;
    }

    public static Set<Id> findResultThroughSOSL(SearchObject searchObject, Set<Id> previousSearchResultIdSet) {
        System.debug('[findResultThroughSOSL] searchObject=' + searchObject);
        Set<Id> searchResultIdSet = new Set<Id>();
        String searchTarget = searchObject.searchTarget;
        String returningObjectTypeName = searchObject.returningObjectTypeName;
        String searchKeyWord = searchObject.searchKeyWord;
        String returningFields = '';
        for (String returningField : searchObject.returningFieldSet) {
            if (String.isNotBlank(returningFields)) {
                returningFields += ', ' + returningField;
            } else {
                returningFields = returningField;
            }
        }
        //After searching all partitions, the maximum results the can be returned per entity is 2,000. Add ORDER BY CreatedDate DESC to avoid SOSL truncation
        String searchQuery = 'FIND :searchKeyWord IN ' + searchTarget + ' RETURNING ' + returningObjectTypeName + '(Id, ' + returningFields;
        String orderByString = ' ORDER BY Name DESC NULLS LAST, CreatedDate DESC';
        if (!previousSearchResultIdSet.isEmpty()) {
            String previousSearchResultIdSetString = '';
            for (Id reader : previousSearchResultIdSet) {
                if (String.isNotBlank(previousSearchResultIdSetString)) {
                    previousSearchResultIdSetString += ', ' + '\'' + reader + '\'';
                } else {
                    previousSearchResultIdSetString += '(\'' + reader + '\'';
                }
            }
            previousSearchResultIdSetString += ')';
            searchQuery += ' WHERE Id IN ' + previousSearchResultIdSetString + orderByString + ')';
            System.debug('[findResultThroughSOSL] previousSearchResultIdSet=' + previousSearchResultIdSet);
        } else {
            searchQuery += orderByString + ')';
        }
        System.debug('[findResultThroughSOSL] searchKeyWord=' + searchKeyWord);
        System.debug('[findResultThroughSOSL] searchQuery=' + searchQuery);
        List<Object> searchResult = Search.query(searchQuery)[0];
        System.debug('[findResultThroughSOSL] searchResult=' + searchResult);
        System.debug('[findResultThroughSOSL] searchResult.size()=' + searchResult.size());
        if (!searchResult.isEmpty()) {
            for (Object next : searchResult) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(next));
                searchResultIdSet.add(Id.valueOf((String) result.get('Id')));
            }
        }
        System.debug('[findResultThroughSOSL] searchResultIdSet=' + searchResultIdSet);
        System.debug('[findResultThroughSOSL] searchResultIdSet.size()=' + searchResultIdSet.size());
        return searchResultIdSet;
    }

    public static List<Object> encapsulateResult(
        List<InsurancePolicy> queryResult,
        Set<Id> participantResultIdSet,
        Map<Id, String> insurancePolicyIdAssetNameMap,
        Map<Id, Account> participantIdPolicyOwnerMap,
        Map<String, SearchObject> developerNameSearchObjectMap,
        Map<String, SearchCondition__mdt> developerNameSearchConditionMap,
        Map<String, PolicySearchResultColumn__mdt> developerNameResultColumnMap
    ) {
        List<Object> resultList = new List<Object>();
        Map<String, String> resultColumnDeveloperNameToFieldName = new Map<String, String>();

        for (PolicySearchResultColumn__mdt next : developerNameResultColumnMap.values()) {
            resultColumnDeveloperNameToFieldName.put(next.DeveloperName, next.FieldName__c);
        }
        System.debug('[encapsulateResult] queryResult.size()=' + queryResult.size());
        System.debug('[encapsulateResult] developerNameSearchObjectMap=' + developerNameSearchObjectMap);
        System.debug('[encapsulateResult] developerNameSearchConditionMap=' + developerNameSearchConditionMap);
        System.debug('[encapsulateResult] resultColumnDeveloperNameToFieldName=' + resultColumnDeveloperNameToFieldName);
        for (Object next : queryResult) {
            Boolean isMatchSOSL = true;
            Map<String, Object> resultItem = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(next));
            System.debug('[encapsulateResult] resultItem=' + resultItem);
            // Map<String, Object> insurancePolicyMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(resultItem.get('InsurancePolicy')));
            Map<String, Object> primaryParticipantAccountMap = (Map<String, Object>) JSON.deserializeUntyped(
                JSON.serialize(resultItem.get('NameInsured'))
            );
            // System.debug('[encapsulateResult] insurancePolicyMap=' + insurancePolicyMap);
            System.debug('[encapsulateResult] primaryParticipantAccountMap=' + primaryParticipantAccountMap);
            // if (insurancePolicyMap != null) {
            //     for (String key : insurancePolicyMap.keySet()) {
            //         resultItem.put('InsurancePolicy.' + key, insurancePolicyMap.get(key));
            //     }
            // }
            if (primaryParticipantAccountMap != null) {
                for (String key : primaryParticipantAccountMap.keySet()) {
                    resultItem.put('NameInsured.' + key, primaryParticipantAccountMap.get(key));
                }
            }
            Map<String, String> searchObjectResultMap = new Map<String, String>();
            for (String developerName : developerNameSearchObjectMap.keySet()) {
                SearchObject searchObject = developerNameSearchObjectMap.get(developerName);
                Boolean isPartialMatch = true;
                String searchKeyWordOrigin = '';
                if (searchObject != null && String.isNotBlank(searchObject.searchKeyWord)) {
                    String searchKeyWord = searchObject.searchKeyWord;
                    System.debug('[encapsulateResult] searchKeyWord=' + searchKeyWord);
                    isPartialMatch = searchKeyWord.replace('"', '').contains('*');
                    searchKeyWordOrigin = searchKeyWord.replace('"', '').remove('*');
                } else {
                    continue;
                }
                System.debug('[encapsulateResult] isPartialMatch=' + isPartialMatch);
                System.debug('[encapsulateResult] searchKeyWordOrigin=' + searchKeyWordOrigin);
                Map<String, Object> objectMap = resultItem;
                System.debug('[encapsulateResult] objectMap=' + objectMap);
                for (String returningField : searchObject.returningFieldSet) {
                    String returningFieldTrim = returningField.trim();
                    System.debug('[encapsulateResult] returningFieldTrim=' + returningFieldTrim);
                    if (objectMap.get(returningFieldTrim) != null) {
                        System.debug('[encapsulateResult] objectMap.get(returningFieldTrim)=' + objectMap.get(returningFieldTrim));
                        String valueString = objectMap.get(returningFieldTrim).toString();
                        System.debug('[encapsulateResult] valueString=' + valueString);
                        System.debug('[encapsulateResult] isPartialMatch=' + isPartialMatch);
                        if (String.isBlank(searchKeyWordOrigin)) {
                            searchObjectResultMap.put(developerName, valueString);
                            break;
                        } else if (isPartialMatch) {
                            if (valueString.containsIgnoreCase(searchKeyWordOrigin)) {
                                searchObjectResultMap.put(developerName, valueString);
                                break;
                            }
                        } else {
                            if (valueString.equalsIgnoreCase(searchKeyWordOrigin)) {
                                searchObjectResultMap.put(developerName, valueString);
                                break;
                            }
                        }
                    }
                }
                if (String.isNotBlank(searchKeyWordOrigin) && searchObjectResultMap.get(developerName) == null) {
                    System.debug('[encapsulateResult] isMatchSOSL=false searchKeyWordOrigin=' + searchKeyWordOrigin);
                    System.debug('[encapsulateResult] isMatchSOSL=false developerName=' + developerName);
                    System.debug(
                        '[encapsulateResult] isMatchSOSL=false searchObjectResultMap.get(developerName)=' + searchObjectResultMap.get(developerName)
                    );
                    isMatchSOSL = false;
                }
            }
            System.debug('[encapsulateResult] isMatchSOSL=' + isMatchSOSL);
            if (!isMatchSOSL) {
                continue;
            }
            for (String developerName : resultColumnDeveloperNameToFieldName.keySet()) {
                String fieldNameCombination = resultColumnDeveloperNameToFieldName.get(developerName);
                if (searchObjectResultMap.get(developerName) != null) {
                    resultItem.put(fieldNameCombination, searchObjectResultMap.get(developerName));
                } else {
                    SearchCondition__mdt searchCondition = developerNameSearchConditionMap.get(developerName);
                    if (searchCondition != null && searchCondition.ExecutionLanguage__c != null && searchCondition.ExecutionLanguage__c.equals('SOSL')) {
                        for (String returningField : searchCondition.ReturningFields__c.split(',')) {
                            String returningFieldTrim = returningField.trim();
                            if (resultItem.get(returningFieldTrim) != null) {
                                String valueString = resultItem.get(returningFieldTrim).toString();
                                if (String.isNotBlank(valueString)) {
                                    resultItem.put(fieldNameCombination, valueString);
                                    break;
                                }
                            }
                        }
                    }
                }
                for (String fieldNameString : fieldNameCombination.split(',')) {
                    String fieldName = fieldNameString.trim();
                    System.debug('[encapsulateResult] developerName=' + developerName);
                    System.debug('[encapsulateResult] fieldName=' + fieldName);
                    System.debug('[encapsulateResult] resultItem.get(fieldName)=' + resultItem.get(fieldName));
                    if (fieldName.equals('PolicyOwner')) {
                        String insurancePolicyId = (String) resultItem.get('InsurancePolicyId');
                        if (participantIdPolicyOwnerMap.get(insurancePolicyId) != null) {
                            Account account = participantIdPolicyOwnerMap.get(insurancePolicyId);
                            resultItem.put('PolicyOwner', account.Name);
                            resultItem.put('PolicyOwnerAccountId', account.Id);
                            continue;
                        }
                    }
                }
                if (fieldNameCombination.contains(',')) {
                    String fieldNameCombinationValue = '';
                    for (String fieldNameString : fieldNameCombination.split(',')) {
                        String fieldName = fieldNameString.trim();
                        if (resultItem.get(fieldName) != null && String.isNotBlank(resultItem.get(fieldName).toString())) {
                            if (String.isBlank(fieldNameCombinationValue)) {
                                fieldNameCombinationValue += resultItem.get(fieldName);
                            } else {
                                fieldNameCombinationValue += ' - ' + resultItem.get(fieldName);
                            }
                        }
                    }
                    resultItem.put(fieldNameCombination, fieldNameCombinationValue);
                }
            }
            if (resultItem.get('InsurancePolicy.PolicyType') == null) {
                resultItem.put('InsurancePolicy.PolicyType', '');
            }
            // if (searchVehicleRegistrationNumber) {
            //     resultItem.put(VEHICLE_REGISTRATION_NUMBER, insurancePolicyIdAssetNameMap.get(resultItem.get('InsurancePolicyId').toString()));
            // }
            // Privacy masking: if CRM_Global_PrivacyFlag__c is true, mask all fields except Id and the privacy flag itself
            Boolean privacyFlag = false;
            if (resultItem.containsKey('NameInsured.CRM_Global_PrivacyFlag__c') && resultItem.get('NameInsured.CRM_Global_PrivacyFlag__c') != null) {
                String flagString = String.valueOf(resultItem.get('NameInsured.CRM_Global_PrivacyFlag__c')).toLowerCase();
                privacyFlag = flagString == 'true';
            }
            if (privacyFlag) {
                for (String keyName : new List<String>(resultItem.keySet())) {
                    if (keyName == 'Id' || keyName == 'NameInsured.CRM_Global_PrivacyFlag__c') {
                        continue;
                    }
                    resultItem.put(keyName, '****');
                }
            }
            System.debug('[encapsulateResult] resultItem=' + resultItem);
            if (resultList.size() > 200) {
                break;
            }
            resultList.add(resultItem);
        }
        System.debug('[encapsulateResult] resultList.size()=' + resultList.size());
        return resultList;
    }

    public class SearchObject {
        public String searchTarget { get; set; }
        public String returningObjectTypeName { get; set; }
        public String searchKeyWord { get; set; }
        public Set<String> returningFieldSet { get; set; }
    }
}