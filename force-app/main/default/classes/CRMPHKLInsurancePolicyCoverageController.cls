public with sharing class CRMPHKLInsurancePolicyCoverageController {

    /**
     * Returns the Id of the first InsurancePolicyCoverage record related to the given InsurancePolicy.
     * Ordering is by CreatedDate ascending to approximate the "first" created coverage.
     */
    @AuraEnabled(cacheable=true)
    public static Id getFirstCoverageId(Id insurancePolicyId) {
        if (insurancePolicyId == null) {
            return null;
        }

        // Query minimal fields; limit to 1 by oldest CreatedDate
        List<InsurancePolicyCoverage> coverages = [
            SELECT Id
            FROM InsurancePolicyCoverage
            WHERE InsurancePolicyId = :insurancePolicyId
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        return coverages.isEmpty() ? null : coverages[0].Id;
    }

    /**
     * Returns the API names of fields included in the specified field set
     * on InsurancePolicyCoverage. Defaults to Insurance_Policy_Coverage_Detail_Fields if not provided.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getDetailFieldsetFields(String fieldSetName) {
        List<String> fieldApiNames = new List<String>();
        
        // Default to Insurance_Policy_Coverage_Detail_Fields if not provided
        if (String.isBlank(fieldSetName)) {
            fieldSetName = 'CRM_PHKL_Life_Policy_Detail_Fields';
        }
        
        Schema.DescribeSObjectResult describe = InsurancePolicyCoverage.SObjectType.getDescribe();
        Map<String, Schema.FieldSet> fieldSets = describe.fieldSets.getMap();
        Schema.FieldSet detailFieldSet = fieldSets.get(fieldSetName);
        if (detailFieldSet == null) {
            return fieldApiNames;
        }
        for (Schema.FieldSetMember member : detailFieldSet.getFields()) {
            fieldApiNames.add(member.getFieldPath());
        }
        return fieldApiNames;
    }
}