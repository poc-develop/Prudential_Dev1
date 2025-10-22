/**
 * @description       : 
 * @author            : Franco
 * @group             : 
 * @last modified on  : 2025-09-18
 * @last modified by  : Franco
**/
public with sharing class CRMGlobalCaseTATService {
    
    private static final String STATUS_FIRST_ROUND_PROCESSING = '1st Round Processing';
    private static final String STATUS_SECOND_ROUND_PROCESSING = '2nd Round Processing';
    private static Map<String, CRM_Global_CaseTATSetting__mdt> requestTypeToTATSettingMap;

    static {
        requestTypeToTATSettingMap = new Map<String, CRM_Global_CaseTATSetting__mdt>();
        for (CRM_Global_CaseTATSetting__mdt setting : CRM_Global_CaseTATSetting__mdt.getAll().values()) {
            requestTypeToTATSettingMap.put(setting.CRM_Global_RequestType__c, setting);
        }
    }

    public static DateTime getTATDueDate(String requestType, String caseStatus, Datetime startDatetime) {
        CRM_Global_CaseTATSetting__mdt tatSetting = requestTypeToTATSettingMap.get(requestType);
        if (tatSetting == null) {
            return null;
        }
        Datetime tatDueDate = null;
        BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = TRUE];
        if (caseStatus == STATUS_FIRST_ROUND_PROCESSING && tatSetting.CRM_Global_SLA1Hours__c != -1) {
            tatDueDate = BusinessHours.add(bh.Id, startDatetime, Integer.valueOf(tatSetting.CRM_Global_SLA1Hours__c) * 60 * 60 * 1000);
        } else if (caseStatus == STATUS_SECOND_ROUND_PROCESSING && tatSetting.CRM_Global_SLA2Hours__c != -1) {
            tatDueDate = BusinessHours.add(bh.Id, startDatetime, Integer.valueOf(tatSetting.CRM_Global_SLA2Hours__c) * 60 * 60 * 1000);
        }
        return tatDueDate;
    }

}