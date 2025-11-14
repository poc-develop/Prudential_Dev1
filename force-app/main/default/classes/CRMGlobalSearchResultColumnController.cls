public with sharing class CRMGlobalSearchResultColumnController {
    @AuraEnabled
	public static List<CRM_Global_SearchCondition__mdt> getSearchConditionMdtList(){
		// String contactCenter = getContactCenter();
		List<CRM_Global_SearchCondition__mdt> searchConditionList= [SELECT Id, Label, DeveloperName, Index__c, Placeholder__c, MessageShow__c, IsInput__c, IsSelect__c, Options__c,
		                                                 MinLength__c, Size__c, Pattern__c, ContactCenter__c, Type__c, ExecutionLanguage__c, MatchingRule__c,
		                                                 ReturningFields__c, ReturningObjectTypeName__c, SearchTarget__c
		                                                 FROM CRM_Global_SearchCondition__mdt ORDER BY Index__c ASC];
		return searchConditionList;
	}

	@AuraEnabled
	public static List<CRM_Global_PolicySearchResultColumn__mdt> getPolicySearchResultColumnMdtList(){
		// String contactCenter = getContactCenter();
		List<CRM_Global_PolicySearchResultColumn__mdt> policySearchResultColumnList = [SELECT Id, Label, DeveloperName, FieldName__c, Type__c, Sortable__c,
		                                                                    InitialWidth__c, Index__c, ContactCenter__c, IsShow__c, TypeAttribute__r.DeveloperName,
		                                                                    TypeAttribute__r.Label, TypeAttribute__r.Type__c, TypeAttribute__r.Value__c,
		                                                                    TypeAttribute__r.NavigationName__c, TypeAttribute__r.NeedDispatchEvent__c,
		                                                                    TypeAttribute__r.FieldName__c
		                                                                    FROM CRM_Global_PolicySearchResultColumn__mdt ORDER BY Index__c ASC];
		return policySearchResultColumnList;
	}

	// public static String getContactCenter() {
	// 	String userId = UserInfo.getUserId();
	// 	User currentUser = [SELECT Id, Name, Country FROM User WHERE Id=:userId];
	// 	return currentUser.Country;
	// }
}