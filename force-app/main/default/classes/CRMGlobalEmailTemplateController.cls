/**
 * @description       : Controller for Email Template Component
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-28
 * @last modified by  : hank
**/
public with sharing class CRMGlobalEmailTemplateController {
    
    /**
     * Search Lightning Email Templates
     * @param searchKey Search keyword (optional, returns all templates if empty)
     * @return List<EmailTemplate>
     */
    @AuraEnabled(cacheable=true)
    public static List<EmailTemplate> searchLightningEmailTemplates(String searchKey) {
        try {
            String query = 'SELECT Id, Name, DeveloperName, Subject, Description, ' +
                          'UIType, TemplateStyle, TemplateType ' +
                          'FROM EmailTemplate ' +
                          'WHERE UIType = \'SFX\' ' + 
                          'AND IsActive = true ';
            
            // Add search condition if search keyword exists
            if (String.isNotBlank(searchKey)) {
                String searchPattern = '%' + String.escapeSingleQuotes(searchKey) + '%';
                query += 'AND Name LIKE :searchPattern  ';
            }
            
            query += 'ORDER BY Name ASC LIMIT 100';
            
            return Database.query(query);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error searching Lightning Email Templates: ' + e.getMessage());
            throw new AuraHandledException('Failed to search templates: ' + e.getMessage());
        }
    }
    
    /**
     * Get template full content
     * @param templateId Email Template Id
     * @return EmailTemplate
     */
    @AuraEnabled
    public static EmailTemplate getTemplateContent(String templateId) {
        try {
            if (String.isBlank(templateId)) {
                throw new AuraHandledException('Template ID is required');
            }
            
            List<EmailTemplate> templates = [
                SELECT Id, Name, DeveloperName, Subject, 
                       Body, HtmlValue, Description,
                       UIType, TemplateStyle, TemplateType
                FROM EmailTemplate
                WHERE Id = :templateId
                AND UIType = 'SFX'  // Ensure it's a Lightning Template
                LIMIT 1
            ];
            
            if (templates.isEmpty()) {
                throw new AuraHandledException('Lightning Email Template not found');
            }
            
            return templates[0];
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error fetching template content: ' + e.getMessage());
            throw new AuraHandledException('Failed to fetch template content: ' + e.getMessage());
        }
    }
}

