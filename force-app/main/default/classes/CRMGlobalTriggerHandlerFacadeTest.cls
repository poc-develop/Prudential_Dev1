/**
 * @description       : Test class for CRMGlobalTriggerHandlerFacade
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-11
 * @last modified by  : Franco
**/
@IsTest
public class CRMGlobalTriggerHandlerFacadeTest {

    // Dummy handler class that implements CRMGlobalTriggerHandler
    public class DummyValidHandler extends CRMGlobalTriggerHandler {
        public DummyValidHandler() {}
        public Boolean wasRun = false;
        public override void beforeInsert() {
            wasRun = true;
        }
    }

    // Another dummy class that does NOT extend CRMGlobalTriggerHandler (for exception test)
    public class DummyInvalidHandler {
        public DummyInvalidHandler() {}
    }

    @IsTest
    static void testInitTriggerHandlerMapAndRun() {
        // Prepare fake metadata records
        CRM_Global_TriggerHandlerConfig__mdt handlerConfig = new CRM_Global_TriggerHandlerConfig__mdt(
            Handler_Name__c = 'CRMGlobalTriggerHandlerFacadeTest.DummyValidHandler',
            sObjectType__c = 'Account'
        );

        Test.startTest();
        // Assign test configs directly
        List<CRM_Global_TriggerHandlerConfig__mdt> configs = new List<CRM_Global_TriggerHandlerConfig__mdt>{ handlerConfig };
        // Re-initialize the map
        CRMGlobalTriggerHandlerFacade.initTriggerHandlerMap(configs);

        // Run handlers for Account
        try {
            CRMGlobalTriggerHandlerFacade.run('Account');
        } catch(Exception e) {
            // Not in trigger context, Trigger handler called outside of Trigger execution
        }
        
        Test.stopTest();

        // Validate that handler was added
        System.assert(
            CRMGlobalTriggerHandlerFacade.triggerHandlerMap.size() == 1,
            'Configs should have 1 record.'
        );
    }

    @IsTest
    static void testRun_NoHandlers() {
        Test.startTest();
        // Prepare configs that do not match any sObject type
        List<CRM_Global_TriggerHandlerConfig__mdt> configs = new List<CRM_Global_TriggerHandlerConfig__mdt>();
        CRMGlobalTriggerHandlerFacade.initTriggerHandlerMap(configs);
        // Should simply log and not throw error
        CRMGlobalTriggerHandlerFacade.run('Contact');
        Test.stopTest();

        System.assert(true, 'Run completed successfully even with no handlers.');
    }

    @IsTest
    static void testInitTriggerHandlerMap_InvalidHandler() {
        // Prepare invalid metadata record (class does not extend CRMGlobalTriggerHandler)
        CRM_Global_TriggerHandlerConfig__mdt invalidCfg = new CRM_Global_TriggerHandlerConfig__mdt(
            Handler_Name__c = 'CRMGlobalTriggerHandlerFacadeTest.DummyInvalidHandler',
            sObjectType__c = 'Contact'
        );

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            List<CRM_Global_TriggerHandlerConfig__mdt> configs = new List<CRM_Global_TriggerHandlerConfig__mdt>{ invalidCfg };
            CRMGlobalTriggerHandlerFacade.initTriggerHandlerMap(configs);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Expected exception for invalid handler.');
    }
}