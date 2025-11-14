/**
 * @description Controller for CRM Global Questionnaire Form LWC
 * @author System
 * @date 2024
 */
public with sharing class CRMGlobalQuestionnaireFormController {
    
    /**
     * @description Wrapper class for questionnaire question data
     */
    public class QuestionnaireQuestionWrapper {
        @AuraEnabled public String Id { get; set; }
        @AuraEnabled public String QuestionText { get; set; }
        @AuraEnabled public Boolean IsRequired { get; set; }
        @AuraEnabled public String FAQ { get; set; }
        @AuraEnabled public Integer SortOrder { get; set; }
        @AuraEnabled public List<QuestionChoiceWrapper> Choices { get; set; }
        
        public QuestionnaireQuestionWrapper() {
            this.Choices = new List<QuestionChoiceWrapper>();
        }
    }
    
    /**
     * @description Wrapper class for question choice data
     */
    public class QuestionChoiceWrapper {
        @AuraEnabled public String Id { get; set; }
        @AuraEnabled public String Value { get; set; }
        @AuraEnabled public Integer SortOrder { get; set; }
    }
    
    /**
     * @description Wrapper class for questionnaire response data
     */
    public class QuestionnaireResponseWrapper {
        @AuraEnabled public String questionId { get; set; }
        @AuraEnabled public String selectedChoice { get; set; }
        @AuraEnabled public String remark { get; set; }
    }
    
    /**
     * @description Get questionnaire data including questions and choices
     * @param questionnaireId The ID of the questionnaire
     * @param language The language for the questionnaire
     * @param subType The sub type for the questionnaire
     * @return List of questionnaire questions with their choices
     */
    @AuraEnabled(cacheable=true)
    public static List<QuestionnaireQuestionWrapper> getQuestionnaireData(
        String questionnaireId
    ) {
        try {
            List<QuestionnaireQuestionWrapper> result = new List<QuestionnaireQuestionWrapper>();
            
            // Query questionnaire questions
            List<CRM_Global_QuestionnaireQuestion__c> questions = [
                SELECT Id, CRM_Global_QuestionText__c,  
                CRM_Global_QuestionFAQ__c, CRM_Global_Order__c
                FROM CRM_Global_QuestionnaireQuestion__c 
                WHERE CRM_Global_Questionnaire__c = :questionnaireId
                ORDER BY CRM_Global_Order__c ASC
            ];
            
            // Get question IDs for querying choices
            Set<Id> questionIds = new Set<Id>();
            for (CRM_Global_QuestionnaireQuestion__c question : questions) {
                questionIds.add(question.Id);
            }
            
            // Query question choices
            List<CRM_Global_QuestionnaireQuestionChoice__c> choices = [
                SELECT Id, CRM_Global_Value__c, CRM_Global_Order__c, 
                       CRM_Global_QuestionnaireQuestion__c
                FROM CRM_Global_QuestionnaireQuestionChoice__c 
                WHERE CRM_Global_QuestionnaireQuestion__c IN :questionIds
                ORDER BY CRM_Global_Order__c ASC
            ];
            
            // Group choices by question ID
            Map<Id, List<QuestionChoiceWrapper>> choicesByQuestion = new Map<Id, List<QuestionChoiceWrapper>>();
            for (CRM_Global_QuestionnaireQuestionChoice__c choice : choices) {
                QuestionChoiceWrapper choiceWrapper = new QuestionChoiceWrapper();
                choiceWrapper.Id = choice.Id;
                choiceWrapper.Value = choice.CRM_Global_Value__c;
                choiceWrapper.SortOrder = (Integer) choice.CRM_Global_Order__c;
                
                if (!choicesByQuestion.containsKey(choice.CRM_Global_QuestionnaireQuestion__c)) {
                    choicesByQuestion.put(choice.CRM_Global_QuestionnaireQuestion__c, new List<QuestionChoiceWrapper>());
                }
                choicesByQuestion.get(choice.CRM_Global_QuestionnaireQuestion__c).add(choiceWrapper);
            }
            
            // Build result
            for (CRM_Global_QuestionnaireQuestion__c question : questions) {
                QuestionnaireQuestionWrapper questionWrapper = new QuestionnaireQuestionWrapper();
                questionWrapper.Id = question.Id;
                questionWrapper.QuestionText = question.CRM_Global_QuestionText__c;
                // questionWrapper.IsRequired = question.CRM_Global_IsRequired__c != null ? question.CRM_Global_IsRequired__c : false;
                questionWrapper.FAQ = question.CRM_Global_QuestionFAQ__c;
                questionWrapper.SortOrder = (Integer) question.CRM_Global_Order__c;
                
                if (choicesByQuestion.containsKey(question.Id)) {
                    questionWrapper.Choices = choicesByQuestion.get(question.Id);
                }
                
                result.add(questionWrapper);
            }
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving questionnaire data: ' + e.getMessage());
        }
    }
    
    /**
     * @description Save questionnaire responses
     * @param questionnaireId The ID of the questionnaire
     * @param responses List of responses for each question
     * @param language The language of the responses
     * @param subType The sub type of the responses
     * @return The ID of the created response record
     */
    @AuraEnabled
    public static String saveQuestionnaireResponse(
        String caseId,
        String questionnaireId,
        List<QuestionnaireResponseWrapper> responses,
        String language,
        String subType
    ) {
        try {
            Id caseAccountId = [SELECT AccountId FROM Case WHERE Id = :caseId].AccountId;
            // Create main questionnaire response record
            CRM_Global_QuestionnaireResponse__c questionnaireResponse = new CRM_Global_QuestionnaireResponse__c();
            questionnaireResponse.CRM_Global_Case__c = caseId;
            questionnaireResponse.CRM_Global_Account__c = caseAccountId;
            questionnaireResponse.CRM_Global_Questionnaire__c = questionnaireId;
            // questionnaireResponse.CRM_Global_Language__c = language;
            // questionnaireResponse.CRM_Global_SubType__c = subType;
            // questionnaireResponse.CRM_Global_ResponseDate__c = System.now();
            
            insert questionnaireResponse;
            
            // Create individual question responses
            List<CRM_Global_QuestionnaireQuesResponse__c> questionResponses = new List<CRM_Global_QuestionnaireQuesResponse__c>();
            
            for (QuestionnaireResponseWrapper response : responses) {
                if (String.isNotBlank(response.selectedChoice) || String.isNotBlank(response.remark)) {
                    CRM_Global_QuestionnaireQuesResponse__c questionResponse = new CRM_Global_QuestionnaireQuesResponse__c();
                    questionResponse.CRM_Global_QuestionnaireResponse__c = questionnaireResponse.Id;
                    questionResponse.CRM_Global_QuestionnaireQuestion__c = response.questionId;
                    questionResponse.CRM_Global_Answer__c = response.selectedChoice;
                    questionResponse.CRM_Global_Remark__c = response.remark;
                    
                    questionResponses.add(questionResponse);
                }
            }
            
            if (!questionResponses.isEmpty()) {
                insert questionResponses;
            }
            
            return questionnaireResponse.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error saving questionnaire response: ' + e.getMessage());
        }
    }
}