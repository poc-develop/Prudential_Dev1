public with sharing class CRMPHKLOmniChannelStatusChangerCtrl {

    // NEW: Inner class to format the list for lightning:combobox
    public class PresenceStatusOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; } // This will hold the 15-digit ID

        public PresenceStatusOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /**
     * Wrapper class to return both the list of all statuses
     * and the user's current status ID.
     */
    public class PresenceStatusInfo {
        // UPDATED: Uses the new wrapper class
        @AuraEnabled public List<PresenceStatusOption> statuses { get; set; }
        @AuraEnabled public String currentStatusId { get; set; } // This will be 15-digits

        public PresenceStatusInfo() {
            this.statuses = new List<PresenceStatusOption>();
        }
    }

    /**
     * @description Gets all active Service Presence Statuses and the current user's
     * current status.
     * @return      A PresenceStatusInfo wrapper with 15-digit IDs.
     */
    @AuraEnabled(cacheable=true)
    public static PresenceStatusInfo getStatuses() {
        PresenceStatusInfo info = new PresenceStatusInfo();
        Id currentUserId = UserInfo.getUserId();

        // 1. Get all active statuses
        List<ServicePresenceStatus> statusRecords = [
            SELECT Id, MasterLabel 
            FROM ServicePresenceStatus 
            ORDER BY MasterLabel ASC
        ];

        // UPDATED: Populate the new wrapper list with 15-digit IDs
        for (ServicePresenceStatus s : statusRecords) {
            info.statuses.add(new PresenceStatusOption(s.MasterLabel, s.Id.to15()));
        }

        // 2. Get the user's current presence status
        List<UserServicePresence> currentPresence = [
            SELECT ServicePresenceStatusId 
            FROM UserServicePresence 
            WHERE UserId = :currentUserId AND IsCurrentState = true 
            LIMIT 1
        ];

        if (!currentPresence.isEmpty()) {
            // UPDATED: Convert to 15-digit string
            info.currentStatusId = currentPresence[0].ServicePresenceStatusId.to15();
        } else {
            // User is likely Offline. Find the 'Offline' status ID.
            try {
                ServicePresenceStatus offlineStatus = [
                    SELECT Id 
                    FROM ServicePresenceStatus 
                    WHERE DeveloperName = 'Offline' 
                    LIMIT 1
                ];
                // UPDATED: Convert to 15-digit string
                info.currentStatusId = offlineStatus.Id.to15();
            } catch (Exception e) {
                info.currentStatusId = null; 
            }
        }
        
        return info;
    }
}