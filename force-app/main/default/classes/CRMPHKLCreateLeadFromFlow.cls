/**
 * @description Invocable Apex class to be called from Salesforce Flow for creating leads.
 * Lead Management
 */
public with sharing class CRMPHKLCreateLeadFromFlow {

    public class LeadInputParameters {
        @InvocableVariable(required=true)
        public String lastName;

        @InvocableVariable
        public String firstName;

        @InvocableVariable(required=true)
        public String phoneNumber;

        @InvocableVariable
        public String countryCode;

        @InvocableVariable
        public String email;

        @InvocableVariable
        public String referredAgentCode;

        @InvocableVariable
        public String otherLeadComments;

        @InvocableVariable
        public Boolean walkIn;
    }

    /**
     * @description Invocable method that creates a lead from Flow input.
     * @param leadInputs List of input parameters from the Flow.
     * @return List of operation success status (though often a single item in practice).
     */
    @InvocableMethod(label='Create PHKL Lead' description='Creates a new lead using the CRMPHKLLeadService.')
    public static List<String> createLead(List<LeadInputParameters> leadInputs) {
        List<String> results = new List<String>();
        for (LeadInputParameters input : leadInputs) {
            try {
                // process input parameters
                String countryCode = input.countryCode == null ? '+852' : input.countryCode;
                String phoneNumber = input.phoneNumber == null ? '' : input.phoneNumber;
                Boolean walkIn = input.walkIn == null ? false : input.walkIn;
                String lastName = input.lastName == null ? 'Anonymous' : input.lastName;
                String firstName = input.firstName == null ? '' : input.firstName;
                Date leadDate = Date.today();

                CRMPHKLLeadDataParams leadParams = new CRMPHKLLeadDataParams(countryCode, phoneNumber, walkIn, lastName, leadDate);
                
                leadParams.email = input.email;
                leadParams.referredAgentCode = input.referredAgentCode;
                leadParams.otherLeadComments = input.otherLeadComments;
                leadParams.firstName = firstName;
                
                system.debug(LoggingLevel.INFO, '-------------------- Screen flow Test --------------------');
                system.debug(LoggingLevel.INFO, 'Request: ' + leadParams);

                //Invoce leadService to create lead
                CRMPHKLLeadService leadService = new CRMPHKLLeadService();
                leadService.collectLeadData(leadParams);
                Boolean isSuccess = leadService.processData();
                
                results.add(isSuccess ? 'Success' : 'Failed');
            } catch (Exception e) {
                // Return exception if any error
                results.add('Error: ' + e.getMessage());
            }
        }
        return results;
    }
}