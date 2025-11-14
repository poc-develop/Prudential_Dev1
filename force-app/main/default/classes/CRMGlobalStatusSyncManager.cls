// ATTENTION: You will need to find the Genesys presence ids that exist in your org.

// ATTENTION: You will need to find the Salesforce status ids that exist in your org.
// Run this query in your Salesforce org to get the status ids specific to your org. You can use 15 or 18 digit ids.
// SELECT DeveloperName,Id,IsDeleted,MasterLabel FROM ServicePresenceStatus

global with sharing class CRMGlobalStatusSyncManager implements genesyscloud.GenesysSCVExtension.Status {
    public String onSalesforceStatusChange(String data) {
        IncomingStatusChange statusUpdate = (IncomingStatusChange) JSON.deserialize(data, IncomingStatusChange.class);
        system.debug(LoggingLevel.INFO, '-------------------- onSalesforceStatusChange --------------------');
        system.debug(LoggingLevel.INFO, 'statusUpdate: ' + JSON.serialize(statusUpdate));
        // -----------------------------------------------------------------------------------------------------------------------------------
        // Examples of how to get current Salesforce Status Variables:
        // String salesforceCurrentStatusApiName = statusUpdate.salesforceStatus.currentStatus.statusApiName;
        // String salesforceCurrentStatusId = statusUpdate.salesforceStatus.currentStatus.statusId;
        // String salesforceCurrentStatusName = statusUpdate.salesforceStatus.currentStatus.statusName;

        // Examples of how to get target Salesforce Status Variables:
        // String salesforceTargetStatusApiName = statusUpdate.salesforceStatus.targetStatus.statusApiName;
        String salesforceTargetStatusId = statusUpdate.salesforceStatus.targetStatus.statusId;
        String salesforceTargetStatusName = statusUpdate.salesforceStatus.targetStatus.statusName;
        // -----------------------------------------------------------------------------------------------------------------------------------
        // Examples of how to get current Genesys Status Variables:
        // String genesysCurrentId = statusUpdate.genesysCloudStatus.currentStatus.id;
        // String genesysCurrentSystemPresence = statusUpdate.genesysCloudStatus.currentStatus.systemPresence;

        // Examples of how to get target Genesys Status Variables:
        String genesysTargetId = statusUpdate.genesysCloudStatus.targetStatus.id;
        // String genesysTargetSystemPresence = statusUpdate.genesysCloudStatus.targetStatus.systemPresence;
        // -----------------------------------------------------------------------------------------------------------------------------------

        // These are the variables that will be changed to update the agent's status.
        // These are default values to be sent back if no changes are made to the target statuses.
        // NOTE: If these values are NOT handled below, NO CHANGES will be made to the target statuses.
        String salesforceResponseTargetStatusId = salesforceTargetStatusId;
        String genesysResponseTargetStatusId = genesysTargetId;

        if (String.isNotEmpty(salesforceTargetStatusName)) {
            salesforceTargetStatusName = salesforceTargetStatusName.toUpperCase();
        }

        StatusManager StatusManager = new StatusManager('GenesysCloud');
        system.debug(LoggingLevel.INFO, 'onSalesforceStatusChange StatusManager: ' + JSON.serialize(StatusManager));

        switch on salesforceTargetStatusName {
            when 'AVAILABLE' {
                salesforceResponseTargetStatusId = StatusManager.AVAILABLE;
            }
            when 'IDLE' {
                salesforceResponseTargetStatusId = StatusManager.IDLE;
            }
            when 'ON QUEUE' {
                salesforceResponseTargetStatusId = StatusManager.ONQUEUE;
            }
            when 'AWAY' {
                salesforceResponseTargetStatusId = StatusManager.AWAY;
            }
            when 'BREAK' {
                salesforceResponseTargetStatusId = StatusManager.BREAKS;
            }
            when 'BUSY' {
                salesforceResponseTargetStatusId = StatusManager.BUSY;
            }
            when 'FOLLOW UP' {
                salesforceResponseTargetStatusId = StatusManager.FOLLOWUP;
            }
            when 'MEAL' {
                salesforceResponseTargetStatusId = StatusManager.MEAL;
            }
            when 'MEETING' {
                salesforceResponseTargetStatusId = StatusManager.MEETING;
            }
            when 'ON THE PHONE' {
                salesforceResponseTargetStatusId = StatusManager.ONTHEPHONE;
            }
            when 'OUT OF OFFICE' {
                salesforceResponseTargetStatusId = StatusManager.OUTOFOFFICE;
            }
            when 'TRAINING' {
                salesforceResponseTargetStatusId = StatusManager.TRAINING;
            }
            when null {
                // Agent clicked Offline in Omni-Channel
                genesysResponseTargetStatusId = StatusManager.OFFLINE;
            }
            when else {
                System.debug(logginglevel.WARN, 'Salesforce status NOT HANDLED: ' + salesforceTargetStatusName);
            }
        }

        system.debug(LoggingLevel.INFO, 'onSalesforceStatusChange response: ' + JSON.serialize(new Response(genesysResponseTargetStatusId, salesforceResponseTargetStatusId)));
        // -----------------------------------------------------------------------------------------------------------------
        // Form response object... shouldn't need to be touched.
        return JSON.serialize(new Response(genesysResponseTargetStatusId, salesforceResponseTargetStatusId));
    }
  
    public String onGenesysCloudStatusChange(String data) {
        IncomingStatusChange statusUpdate = (IncomingStatusChange) JSON.deserialize(data, IncomingStatusChange.class);
        system.debug(LoggingLevel.INFO, '-------------------- onGenesysCloudStatusChange --------------------');
        system.debug(LoggingLevel.INFO, 'statusUpdate: ' + JSON.serialize(statusUpdate));
        // -----------------------------------------------------------------------------------------------------------------------------------
        // Examples of how to get current Salesforce Status Variables:
        // String salesforceCurrentStatusApiName = statusUpdate.salesforceStatus.currentStatus.statusApiName;
        // String salesforceCurrentStatusId = statusUpdate.salesforceStatus.currentStatus.statusId;
        // String salesforceCurrentStatusName = statusUpdate.salesforceStatus.currentStatus.statusName;

        // Examples of how to get target Salesforce Status Variables:
        // String salesforceTargetStatusApiName = statusUpdate.salesforceStatus.targetStatus.statusApiName;
        String salesforceTargetStatusId = statusUpdate.salesforceStatus.targetStatus.statusId;
        // String salesforceTargetStatusName = statusUpdate.salesforceStatus.targetStatus.statusName;
        // -----------------------------------------------------------------------------------------------------------------------------------
        // Examples of how to get current Genesys Status Variables:
        // String genesysCurrentId = statusUpdate.genesysCloudStatus.currentStatus.id;
        // String genesysCurrentSystemPresence = statusUpdate.genesysCloudStatus.currentStatus.systemPresence;

        // Examples of how to get target Genesys Status Variables:
        String genesysTargetId = statusUpdate.genesysCloudStatus.targetStatus.id;
        String genesysTargetSystemPresence = statusUpdate.genesysCloudStatus.targetStatus.systemPresence;
        // -----------------------------------------------------------------------------------------------------------------------------------

        // These are the variables that will be changed to update the agent's status.
        // These are default values to be sent back if no changes are made to the target statuses.
        // NOTE: If these values are NOT handled below, NO CHANGES will be made to the target statuses.
        String salesforceResponseTargetStatusId = salesforceTargetStatusId;
        String genesysResponseTargetStatusId = genesysTargetId;

        if (String.isNotEmpty(genesysTargetSystemPresence)) {
            genesysTargetSystemPresence = genesysTargetSystemPresence.toUpperCase();
        }

        StatusManager StatusManager = new StatusManager('Salesforce');
        system.debug(LoggingLevel.INFO, 'onGenesysCloudStatusChange StatusManager: ' + JSON.serialize(StatusManager));

        switch on genesysTargetSystemPresence {
            when 'AVAILABLE' {
                salesforceResponseTargetStatusId = StatusManager.AVAILABLE;
            }
            when 'IDLE' {
                salesforceResponseTargetStatusId = StatusManager.IDLE;
            }
            when 'ON QUEUE' {
                salesforceResponseTargetStatusId = StatusManager.ONQUEUE;
            }
            when 'AWAY' {
                salesforceResponseTargetStatusId = StatusManager.AWAY;
            }
            when 'BREAK' {
                salesforceResponseTargetStatusId = StatusManager.BREAKS;
            }
            when 'BUSY' {
                salesforceResponseTargetStatusId = StatusManager.BUSY;
            }
            when 'FOLLOW UP' {
                salesforceResponseTargetStatusId = StatusManager.FOLLOWUP;
            }
            when 'MEAL' {
                salesforceResponseTargetStatusId = StatusManager.MEAL;
            }
            when 'MEETING' {
                salesforceResponseTargetStatusId = StatusManager.MEETING;
            }
            when 'ON THE PHONE' {
                salesforceResponseTargetStatusId = StatusManager.ONTHEPHONE;
            }
            when 'OUT OF OFFICE' {
                salesforceResponseTargetStatusId = StatusManager.OUTOFOFFICE;
            }
            when 'TRAINING' {
                salesforceResponseTargetStatusId = StatusManager.TRAINING;
            }
            when 'OFFLINE' {
            // Sets agent to Offline in Omni-Channel
                salesforceResponseTargetStatusId = '0';
            }
            when else {
                System.debug(logginglevel.WARN, 'Genesys Cloud status NOT HANDLED: ' + genesysTargetSystemPresence);
            }
        }

        system.debug(LoggingLevel.INFO, 'onGenesysCloudStatusChange response: ' + JSON.serialize(new Response(genesysResponseTargetStatusId, salesforceResponseTargetStatusId)));
        // -----------------------------------------------------------------------------------------------------------------
        // Form response object... shouldn't need to be touched.
        return JSON.serialize(new Response(genesysResponseTargetStatusId, salesforceResponseTargetStatusId));
    }

    public class StatusManager {
        public String AVAILABLE;
        public String IDLE;
        public String ONQUEUE;
        public String AWAY;
        public String BREAKS;
        public String BUSY;
        public String FOLLOWUP;
        public String MEAL;
        public String MEETING;
        public String ONTHEPHONE;
        public String OUTOFOFFICE;
        public String TRAINING;
        public String OFFLINE;

        public StatusManager(String targetSystem) {
            List<Object> StatusList = new List<Object>();

            if(targetSystem == 'Salesforce'){
                StatusList = [SELECT DeveloperName,Id,IsDeleted,MasterLabel FROM ServicePresenceStatus];
            }else if(targetSystem == 'GenesysCloud'){
                StatusList = [SELECT Id,CreatedDate,Name, CRM_Global_Genesys_Status_Name__c,CRM_Global_Genesys_Status_Id__c FROM CRM_Global_Genesys_Cloud_Presence_Status__c];
            }

                
            for(Object status : StatusList){
                String statusName;
                String statusId;
                if(targetSystem == 'Salesforce'){
                    statusName = ((ServicePresenceStatus)status).MasterLabel != null ? ((ServicePresenceStatus)status).MasterLabel.toUpperCase() : null;
                    statusId = ((ServicePresenceStatus)status).Id;
                }
                else if(targetSystem == 'GenesysCloud'){
                    statusName = ((CRM_Global_Genesys_Cloud_Presence_Status__c)status).CRM_Global_Genesys_Status_Name__c != null ? ((CRM_Global_Genesys_Cloud_Presence_Status__c)status).CRM_Global_Genesys_Status_Name__c.toUpperCase() : null;
                    statusId = ((CRM_Global_Genesys_Cloud_Presence_Status__c)status).CRM_Global_Genesys_Status_Id__c;
                }
                switch on statusName {
                    when 'AVAILABLE' {
                        this.AVAILABLE = statusId;
                    }
                    when 'IDLE' {
                        this.IDLE = statusId;
                    }
                    when 'ON QUEUE' {
                        this.ONQUEUE = statusId;
                    }
                    when 'AWAY' {
                        this.AWAY = statusId;
                    }
                    when 'BREAK' {
                        this.BREAKS = statusId;
                    }
                    when 'BUSY' {
                        this.BUSY = statusId;
                    }
                    when 'FOLLOW UP' {
                        this.FOLLOWUP = statusId;
                    }
                    when 'MEAL' {
                        this.MEAL = statusId;
                    }
                    when 'MEETING' {
                        this.MEETING = statusId;
                    }
                    when 'ON THE PHONE' {
                        this.ONTHEPHONE = statusId;
                    }
                    when 'OUT OF OFFICE' {
                        this.OUTOFOFFICE = statusId;
                    }
                    when 'TRAINING' {
                        this.TRAINING = statusId;
                    }
                    when 'OFFLINE' {
                        this.OFFLINE = statusId;
                    }
                    when else {
                        System.debug(logginglevel.WARN, 'Genesys Cloud status NOT HANDLED: ' + statusName);
                    }
                }
            }
        }
    }
  
    // No need to change below --------------------------------------------------------------------------------------------------------
    //#region Response Obj
    public class Response {
        public ResponseGenesysCloudStatusObj genesysCloudStatus;
        public ResponseSalesforceStatusObj salesforceStatus;
        public Response(String genesysResponseTargetStatusId, String salesforceResponseTargetStatusId) {
            this.genesysCloudStatus = new ResponseGenesysCloudStatusObj(genesysResponseTargetStatusId);
            this.salesforceStatus = new ResponseSalesforceStatusObj(salesforceResponseTargetStatusId);
        }
    }
    public class ResponseGenesysCloudStatus {
        public String id;
        public ResponseGenesysCloudStatus(String id) {
            this.id = id;
        }
    }
    public class ResponseGenesysCloudStatusObj {
        public ResponseGenesysCloudStatus targetStatus;
        public ResponseGenesysCloudStatusObj(String genesysResponseTargetStatusId) {
            this.targetStatus = new ResponseGenesysCloudStatus(genesysResponseTargetStatusId);
        }
    }
    public class ResponseSalesforceStatus {
        public String statusId;
        public ResponseSalesforceStatus(String statusId) {
            this.statusId = statusId;
        }
    }
    public class ResponseSalesforceStatusObj {
        public ResponseSalesforceStatus targetStatus;
        public ResponseSalesforceStatusObj(String salesforceResponseTargetStatusId) {
            this.targetStatus = new ResponseSalesforceStatus(salesforceResponseTargetStatusId);
        }
    }
    //#endregion Response Obj
  
    //#region IncomingStatusChange Obj
    public class IncomingStatusChange {
        public IncomingSalesforceStatus salesforceStatus;
        public IncomingGenesysCloudStatus genesysCloudStatus;
    }
    public class IncomingSalesforceStatusObj {
        public String statusApiName;
        public String statusId;
        public String statusName;
    }
    public class IncomingSalesforceStatus {
        public IncomingSalesforceStatusObj targetStatus;
        public IncomingSalesforceStatusObj currentStatus;
    }
    public class IncomingGenesysCloudStatusObj {
        public String id;
        public String systemPresence;
    }
    public class IncomingGenesysCloudStatus {
        public IncomingGenesysCloudStatusObj targetStatus;
        public IncomingGenesysCloudStatusObj currentStatus;
    }
    //#endregion IncomingStatusChange Obj
    // -----------------------------------------------------------------------------------------------------------------
  }