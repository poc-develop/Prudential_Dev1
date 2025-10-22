/**
 * CrmGlobalDataIngestionHandlerAbstract
 * @author       : Easin Zhou
 * @date         : 2025-10-15
 * @description  : Abstract Class for Data Ingestion Job Handler.
 */
public without sharing abstract class CrmGlobalDataIngestionHandlerAbstract {
    
    /**
     * @description Data Ingestion Job record.
     */
    protected CRM_Global_Data_Ingestion_Job__c job;

    /**
     * @description Data Ingestion Job record list.
     */
    protected List<CRM_Global_Raw_Data_Staging__c> rawDataList;

    /**
     * @description Check List Raw.
     */
    protected List<String> checkListRaws;

    /**
     * @description Collection of Raw Data's Error Message.
     */
    protected Map<String, List<String>> errorMap;

    /**
     * @description Common Data.
     */
    protected Map<String, Object> commonData = new Map<String, Object>();


    /**
     * @description Map Use to Store Instance.
     */
    private static Map<String, CrmGlobalDataIngestionHandlerAbstract> instances = new Map<String, CrmGlobalDataIngestionHandlerAbstract>();

    /**
     * @description Protected constructor.
     */
    protected CrmGlobalDataIngestionHandlerAbstract() {
        System.debug(LoggingLevel.INFO, 'Protected CrmGlobalDataIngestionHandlerAbstract constructor');
    }

    /**
     * getInstance
     * @description Get Specific Instance. 
     * @param handlerClassName
     */
    public static CrmGlobalDataIngestionHandlerAbstract getInstance(String handlerClassName) {
        if (!instances.containsKey(handlerClassName)) {
            Type handlerType = Type.forName(handlerClassName);
            if (handlerType == null) {
                throw new IllegalArgumentException('Handler class not found: ' + handlerClassName);
            }
            // Dynamic instantiate subclasses
            CrmGlobalDataIngestionHandlerAbstract handlerInstance =
                (CrmGlobalDataIngestionHandlerAbstract) handlerType.newInstance();
            instances.put(handlerClassName, handlerInstance);
        }
        return instances.get(handlerClassName);
    }


    /**
     * @method init
     * @description init method for pass parameters instead of constructor.
     * @param job
     * @param rawDataList
     * @param errorMap
     * @return CrmGlobalDataIngestionHandlerAbstract
     */
    public virtual CrmGlobalDataIngestionHandlerAbstract init(
        CRM_Global_Data_Ingestion_Job__c job,
        List<CRM_Global_Raw_Data_Staging__c> rawDataList,
        Map<String, List<String>> errorMap
    ) {
        this.job = job;
        this.rawDataList = rawDataList != null ? rawDataList : new List<CRM_Global_Raw_Data_Staging__c>();
        this.checkListRaws = new List<String>();
        this.errorMap = errorMap != null ? errorMap : new Map<String, List<String>>();
        return this;
    }

    /**
     * @method processJob
     * @description Main Method of Entry for Processing.
     */
    public void processJob() {
        if (rawDataList.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'No raw data for job ' + job.Id);
            return;
        }
        validateRawData();
        handleRawData();
    }

    /**
     * @method validateRawData
     * @description Validate Raw Data.
     */
    protected abstract void validateRawData();

    /**
     * @method handleRawData
     * @description handle Raw Data.
     */
    protected abstract void handleRawData();

    /**
     * checkRawDataItem
     * @description Check Raw Data Item.
     * @param rawKey
     * @param rawDataItem
     * @return String
     */
    protected virtual String checkRawDataItem(String rawKey, String rawDataItem) {
        System.debug(LoggingLevel.INFO, 'Check Raw Data Item: ' + rawKey + ':' + String.valueOf(rawDataItem));
        String errorMessage;
        return errorMessage;
    }

    /**
     * setAttribute
     * @description Set Attribute.
     * @param attributeName
     * @param attributeValue
     * @return CrmGlobalDataIngestionHandlerAbstract
     */
    public virtual CrmGlobalDataIngestionHandlerAbstract setAttribute(String attributeName, Object attributeValue) {
        System.debug(LoggingLevel.INFO, 'Set Attribute: ' + attributeName + ':' + attributeValue);
        return this;
    }

    /**
     * getAttribute
     * @description Get Attribute.
     * @param attributeName
     * @return Object
     */
    public virtual Object getAttribute(String attributeName){
        System.debug(LoggingLevel.INFO, 'Get Attribute: ' + attributeName);
        Object myVar;
        return myVar;
    }

}