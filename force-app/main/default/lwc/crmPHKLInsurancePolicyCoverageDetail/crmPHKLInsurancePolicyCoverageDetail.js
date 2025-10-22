import { LightningElement, api, wire } from 'lwc';
import getFirstCoverageId from '@salesforce/apex/CRMPHKLInsurancePolicyCoverageController.getFirstCoverageId';
import getDetailFieldsetFields from '@salesforce/apex/CRMPHKLInsurancePolicyCoverageController.getDetailFieldsetFields';

export default class CrmInsurancePolicyCoverageDetail extends LightningElement {
    @api recordId; // InsurancePolicy Id from host record page
    @api fieldSetName; // Default fieldset name

    coverageRecordId;
    errorMessage;
    fields = [];

    @wire(getFirstCoverageId, { insurancePolicyId: '$recordId' })
    wiredCoverage({ error, data }) {
        if (data) {
            this.coverageRecordId = data;
            this.errorMessage = undefined;
        } else if (error) {
            this.coverageRecordId = undefined;
            this.errorMessage = error?.body?.message || 'Failed to load coverage';
        }
    }

    @wire(getDetailFieldsetFields, { fieldSetName: '$fieldSetName' })
    wiredFields({ error, data }) {
        if (data) {
            this.fields = data;
        } else if (error) {
            this.errorMessage = error?.body?.message || 'Failed to load field set';
        }
    }
}