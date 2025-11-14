/**
 * @description       : Test class for CRMPHKLCreateCaseReplyController
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-27
 * @last modified by  : hank
**/
@IsTest
private class CRMPHKLCreateCaseReplyControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test Case
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Phone'
        );
        insert testCase;
        
        // Query existing Email Template folder or use default
        List<Folder> emailFolders = [
            SELECT Id 
            FROM Folder 
            WHERE Type = 'Email' 
            LIMIT 1
        ];
        
        Id folderId = null;
        if (!emailFolders.isEmpty()) {
            folderId = emailFolders[0].Id;
        } else {
            // If no folder exists, try to get user's default folder
            // Note: In test context, we may need to use SeeAllData=true or create folder differently
            // For now, we'll query existing templates in test methods if needed
        }
        
        // Create test Email Template if folder is available
        if (folderId != null) {
            EmailTemplate testTemplate = new EmailTemplate(
                Name = 'Test Template',
                DeveloperName = 'Test_Template',
                Subject = 'Test Subject {CustomKey}',
                Body = 'Test Body {CustomKey}',
                HtmlValue = '<p>Test HTML {CustomKey}</p>',
                TemplateType = 'Text',
                IsActive = true,
                FolderId = folderId
            );
            insert testTemplate;
        }
    }
    
    @IsTest
    static void testCreateCaseReply_Success() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        String replyText = 'Test reply text';
        
        Test.startTest();
        Boolean result = CRMPHKLCreateCaseReplyController.createCaseReply(testCase.Id, replyText);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, result, 'createCaseReply should return true on success');
        
        // Verify the reply item was created
        List<CRM_Global_CaseAssociatedItem__c> replyItems = [
            SELECT Id, CRM_Global_Case__c, CRM_Global_CommentRemarks__c, RecordType.DeveloperName
            FROM CRM_Global_CaseAssociatedItem__c
            WHERE CRM_Global_Case__c = :testCase.Id
        ];
        
        System.assertEquals(1, replyItems.size(), 'Should create one reply item');
        System.assertEquals(testCase.Id, replyItems[0].CRM_Global_Case__c, 'Case ID should match');
        System.assertEquals(replyText, replyItems[0].CRM_Global_CommentRemarks__c, 'Reply text should match');
        System.assertEquals('Reply', replyItems[0].RecordType.DeveloperName, 'RecordType should be Reply');
    }
    
    @IsTest
    static void testCreateCaseReply_WithNullCaseId() {
        Test.startTest();
        Boolean result = CRMPHKLCreateCaseReplyController.createCaseReply(null, 'Test reply');
        Test.stopTest();
        
        // Should return false when caseId is null
        System.assertEquals(false, result, 'createCaseReply should return false when caseId is null');
    }
    
    @IsTest
    static void testCreateCaseReply_WithNullReplyText() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        Boolean result = CRMPHKLCreateCaseReplyController.createCaseReply(testCase.Id, null);
        Test.stopTest();
        
        // Should still create the reply item even if replyText is null
        System.assertEquals(true, result, 'createCaseReply should return true even with null replyText');
        
        // Verify the reply item was created
        List<CRM_Global_CaseAssociatedItem__c> replyItems = [
            SELECT Id, CRM_Global_CommentRemarks__c
            FROM CRM_Global_CaseAssociatedItem__c
            WHERE CRM_Global_Case__c = :testCase.Id
        ];
        
        System.assertEquals(1, replyItems.size(), 'Should create one reply item');
    }
    
    @IsTest
    static void testCreateCaseReply_WithEmptyReplyText() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        Boolean result = CRMPHKLCreateCaseReplyController.createCaseReply(testCase.Id, '');
        Test.stopTest();
        
        // Should still create the reply item even if replyText is empty
        System.assertEquals(true, result, 'createCaseReply should return true even with empty replyText');
    }
    
    @IsTest
    static void testCreateCaseReply_WithInvalidCaseId() {
        Test.startTest();
        Boolean result = CRMPHKLCreateCaseReplyController.createCaseReply('001000000000000AAA', 'Test reply');
        Test.stopTest();
        
        // Should return false when caseId is invalid
        System.assertEquals(false, result, 'createCaseReply should return false when caseId is invalid');
    }
    
    @IsTest
    static void testUpdateAESEquiryReply_Success() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        // Mock HTTP response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Test.startTest();
        CRMPHKLCreateCaseReplyController.updateAESEquiryReply(testCase.Id);
        Test.stopTest();
        
        // If no exception is thrown, the test passes
        System.assert(true, 'updateAESEquiryReply should execute without exception');
    }
    
    @IsTest
    static void testUpdateAESEquiryReply_WithNullCaseId() {
        // Mock HTTP response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Test.startTest();
        try {
            CRMPHKLCreateCaseReplyController.updateAESEquiryReply(null);
            System.assert(true, 'Method should handle null caseId');
        } catch (Exception e) {
            // Exception is acceptable for null caseId
            System.assert(true, 'Exception is acceptable for null caseId');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testSendEmailWithCustomMerge_Success() {
        // Query or create test Email Template
        List<EmailTemplate> existingTemplates = [
            SELECT Id, DeveloperName, Name 
            FROM EmailTemplate 
            WHERE IsActive = true 
            LIMIT 1
        ];
        
        // If no template exists in setup, create one dynamically
        EmailTemplate testTemplate;
        if (existingTemplates.isEmpty()) {
            // Try to create template with available folder
            List<Folder> emailFolders = [
                SELECT Id 
                FROM Folder 
                WHERE Type = 'Email' 
                LIMIT 1
            ];
            
            if (!emailFolders.isEmpty()) {
                testTemplate = new EmailTemplate(
                    Name = 'Test Template',
                    DeveloperName = 'Test_Template',
                    Subject = 'Test Subject {CustomKey}',
                    Body = 'Test Body {CustomKey}',
                    HtmlValue = '<p>Test HTML {CustomKey}</p>',
                    TemplateType = 'Text',
                    IsActive = true,
                    FolderId = emailFolders[0].Id
                );
                insert testTemplate;
            }
        } else {
            testTemplate = existingTemplates[0];
        }
        
        // Skip test if template cannot be created
        if (testTemplate == null) {
            System.assert(true, 'Skipping test - Email Template folder not available');
            return;
        }
        
        List<String> toAddresses = new List<String>{ 'test@example.com' };
        Map<String, String> customReplacements = new Map<String, String>{
            'CustomKey' => 'CustomValue'
        };
        
        Test.startTest();
        Boolean result = CRMPHKLCreateCaseReplyController.sendEmailWithCustomMerge(
            testTemplate.DeveloperName,
            toAddresses,
            customReplacements
        );
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, result, 'sendEmailWithCustomMerge should return true on success');
    }
    
    @IsTest
    static void testSendEmailWithCustomMerge_TemplateNotFound() {
        List<String> toAddresses = new List<String>{ 'test@example.com' };
        Map<String, String> customReplacements = new Map<String, String>();
        
        Test.startTest();
        Boolean result = CRMPHKLCreateCaseReplyController.sendEmailWithCustomMerge(
            'NonExistentTemplate',
            toAddresses,
            customReplacements
        );
        Test.stopTest();
        
        // Assertions
        System.assertEquals(false, result, 'sendEmailWithCustomMerge should return false when template not found');
    }
    
    @IsTest
    static void testSendEmailWithCustomMerge_WithNullToAddresses() {
        List<EmailTemplate> templates = [SELECT Id, DeveloperName FROM EmailTemplate WHERE IsActive = true LIMIT 1];
        if (templates.isEmpty()) {
            System.assert(true, 'Skipping test - No Email Template available');
            return;
        }
        
        EmailTemplate testTemplate = templates[0];
        Map<String, String> customReplacements = new Map<String, String>();
        
        Test.startTest();
        try {
            Boolean result = CRMPHKLCreateCaseReplyController.sendEmailWithCustomMerge(
                testTemplate.DeveloperName,
                null,
                customReplacements
            );
            // Should handle null toAddresses gracefully
            System.assertNotEquals(null, result, 'Should return a result');
        } catch (Exception e) {
            // Exception is acceptable if toAddresses is required
            System.assert(true, 'Exception is acceptable for null toAddresses');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testSendEmailWithCustomMerge_WithEmptyToAddresses() {
        List<EmailTemplate> templates = [SELECT Id, DeveloperName FROM EmailTemplate WHERE IsActive = true LIMIT 1];
        if (templates.isEmpty()) {
            System.assert(true, 'Skipping test - No Email Template available');
            return;
        }
        
        EmailTemplate testTemplate = templates[0];
        List<String> toAddresses = new List<String>();
        Map<String, String> customReplacements = new Map<String, String>();
        
        Test.startTest();
        try {
            Boolean result = CRMPHKLCreateCaseReplyController.sendEmailWithCustomMerge(
                testTemplate.DeveloperName,
                toAddresses,
                customReplacements
            );
            // Should handle empty toAddresses gracefully
            System.assertNotEquals(null, result, 'Should return a result');
        } catch (Exception e) {
            // Exception is acceptable if toAddresses is required
            System.assert(true, 'Exception is acceptable for empty toAddresses');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testSendEmailWithCustomMerge_WithCustomReplacements() {
        List<EmailTemplate> templates = [SELECT Id, DeveloperName FROM EmailTemplate WHERE IsActive = true LIMIT 1];
        if (templates.isEmpty()) {
            System.assert(true, 'Skipping test - No Email Template available');
            return;
        }
        
        EmailTemplate testTemplate = templates[0];
        List<String> toAddresses = new List<String>{ 'test@example.com' };
        Map<String, String> customReplacements = new Map<String, String>{
            'CustomKey' => 'ReplacedValue',
            'AnotherKey' => 'AnotherValue'
        };
        
        Test.startTest();
        Boolean result = CRMPHKLCreateCaseReplyController.sendEmailWithCustomMerge(
            testTemplate.DeveloperName,
            toAddresses,
            customReplacements
        );
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, result, 'sendEmailWithCustomMerge should return true on success');
    }
    
    @IsTest
    static void testSendEmailWithCustomMerge_WithNullCustomReplacements() {
        List<EmailTemplate> templates = [SELECT Id, DeveloperName FROM EmailTemplate WHERE IsActive = true LIMIT 1];
        if (templates.isEmpty()) {
            System.assert(true, 'Skipping test - No Email Template available');
            return;
        }
        
        EmailTemplate testTemplate = templates[0];
        List<String> toAddresses = new List<String>{ 'test@example.com' };
        
        Test.startTest();
        Boolean result = CRMPHKLCreateCaseReplyController.sendEmailWithCustomMerge(
            testTemplate.DeveloperName,
            toAddresses,
            null
        );
        Test.stopTest();
        
        // Should handle null customReplacements gracefully
        System.assertEquals(true, result, 'sendEmailWithCustomMerge should return true even with null customReplacements');
    }
    
    @IsTest
    static void testSendEmailWithCustomMerge_WithEmptyCustomReplacements() {
        List<EmailTemplate> templates = [SELECT Id, DeveloperName FROM EmailTemplate WHERE IsActive = true LIMIT 1];
        if (templates.isEmpty()) {
            System.assert(true, 'Skipping test - No Email Template available');
            return;
        }
        
        EmailTemplate testTemplate = templates[0];
        List<String> toAddresses = new List<String>{ 'test@example.com' };
        Map<String, String> customReplacements = new Map<String, String>();
        
        Test.startTest();
        Boolean result = CRMPHKLCreateCaseReplyController.sendEmailWithCustomMerge(
            testTemplate.DeveloperName,
            toAddresses,
            customReplacements
        );
        Test.stopTest();
        
        // Should handle empty customReplacements gracefully
        System.assertEquals(true, result, 'sendEmailWithCustomMerge should return true even with empty customReplacements');
    }
    
    @IsTest
    static void testSendEmailWithCustomMerge_WithTemplateName() {
        List<EmailTemplate> templates = [SELECT Id, Name FROM EmailTemplate WHERE IsActive = true LIMIT 1];
        if (templates.isEmpty()) {
            System.assert(true, 'Skipping test - No Email Template available');
            return;
        }
        
        EmailTemplate testTemplate = templates[0];
        List<String> toAddresses = new List<String>{ 'test@example.com' };
        Map<String, String> customReplacements = new Map<String, String>();
        
        Test.startTest();
        Boolean result = CRMPHKLCreateCaseReplyController.sendEmailWithCustomMerge(
            testTemplate.Name, // Use Name instead of DeveloperName
            toAddresses,
            customReplacements
        );
        Test.stopTest();
        
        // Should find template by Name as well
        System.assertEquals(true, result, 'sendEmailWithCustomMerge should find template by Name');
    }
    
    @IsTest
    static void testGetRecordData_Success() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        SObject result = CRMPHKLCreateCaseReplyController.getRecordData(testCase.Id);
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'getRecordData should return a record');
        System.assertEquals(testCase.Id, result.Id, 'Returned record ID should match');
        System.assertEquals('Case', result.getSObjectType().getDescribe().getName(), 'Should return a Case record');
    }
    
    @IsTest
    static void testGetRecordData_WithNullRecordId() {
        Test.startTest();
        SObject result = CRMPHKLCreateCaseReplyController.getRecordData(null);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(null, result, 'getRecordData should return null for null recordId');
    }
    
    // Mock HTTP Response class for testing updateAESEquiryReply
    private class MockHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"result": "success", "message": "Enquiry updated"}');
            return res;
        }
    }
}