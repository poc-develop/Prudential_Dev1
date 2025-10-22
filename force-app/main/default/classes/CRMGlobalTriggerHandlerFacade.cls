/**
 * @description       : Dynamically loads and executes configurable trigger handlers based on custom metadata, ordered by execution sequence.
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-10-11
 * @last modified by  : Franco
**/
public with sharing class CRMGlobalTriggerHandlerFacade {

    @TestVisible
    private static Map<String, List<CRMGlobalTriggerHandler>> triggerHandlerMap = new Map<String, List<CRMGlobalTriggerHandler>>();

    static {
        List<CRM_Global_TriggerHandlerConfig__mdt> configs = [
            SELECT Handler_Name__c, sObjectType__c
            FROM CRM_Global_TriggerHandlerConfig__mdt
            WITH SECURITY_ENFORCED
            ORDER BY Execution_Order__c ASC
        ];

        initTriggerHandlerMap(configs);
    }

    @TestVisible
    private static void initTriggerHandlerMap(List<CRM_Global_TriggerHandlerConfig__mdt> configs) {
        try {
            for (CRM_Global_TriggerHandlerConfig__mdt cfg : configs) {
                String sObjectType = cfg.sObjectType__c;
                String className = cfg.Handler_Name__c;
                Type handlerType = Type.forName(className);
                if (handlerType == null) {
                    System.debug(LoggingLevel.INFO, 'Skipping ' + className + ' because it does not exist.');
                    continue; // Skip if handler type is not found
                }
                Object handlerInstance = handlerType.newInstance();
                if (handlerInstance instanceof CRMGlobalTriggerHandler) {
                    if (triggerHandlerMap.containsKey(sObjectType)) {
                        triggerHandlerMap.get(sObjectType).add((CRMGlobalTriggerHandler) handlerInstance);
                    } else {
                        triggerHandlerMap.put(sObjectType, new List<CRMGlobalTriggerHandler>{(CRMGlobalTriggerHandler) handlerInstance});
                    }
                } else {
                    throw new CRMGlobalTriggerHandlerException('The class ' + className + ' does not extends the CRMGlobalTriggerHandler calss.');
                }
            }
        } catch (Exception ex) {
            throw new CRMGlobalTriggerHandlerException('Error loading handler for trigger handler: ' + ex.getMessage());
        }
    }

    /**
     * @description Executes all configured trigger handlers for the specified sObject type in their defined execution order.
     * @param sObjectType The sObject type for which to run the trigger handlers.
     */
    public static void run(String sObjectType) {
        List<CRMGlobalTriggerHandler> triggerHandlers = triggerHandlerMap.get(sObjectType);
        if(triggerHandlers != null && !triggerHandlers.isEmpty()) {
            for (CRMGlobalTriggerHandler handler : triggerHandlers) {
                handler.run();
            }
        } else {
            System.debug(LoggingLevel.INFO, 'No handlers found for sObjectType: ' + sObjectType);
        }
    }

    /**
     * @description Custom exception class for trigger handler exceptions.
     */
    public class CRMGlobalTriggerHandlerException extends Exception {}
}