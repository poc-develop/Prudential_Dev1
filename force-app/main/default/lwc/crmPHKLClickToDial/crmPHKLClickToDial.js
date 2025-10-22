import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';

// Import the fields needed from the Case object
import PHONE_FIELD from '@salesforce/schema/Case.ContactPhone'; // Or your custom phone field
import ACCOUNT_ID_FIELD from '@salesforce/schema/Case.AccountId';

export default class ClickToDialAndOpenTab extends NavigationMixin(LightningElement) {
    @api recordId; // This will automatically be the Case ID (e.g., 500D300000EtrJ3)

    // Wire to get the Case data, including the AccountId
    @wire(getRecord, { recordId: '$recordId', fields: [PHONE_FIELD, ACCOUNT_ID_FIELD] })
    record;

    // Getter for the phone number
    get phoneNumber() {
        return getFieldValue(this.record.data, PHONE_FIELD);
    }

    // Getter for the Account ID
    get accountId() {
        return getFieldValue(this.record.data, ACCOUNT_ID_FIELD);
    }
    
    handleClick(event) {
        
        console.log('Fired handleClick');
        // View a custom object record.
        // Navigate to the Case object home page.
            this[NavigationMixin.Navigate]({
            type: "standard__objectPage",
            attributes: {
                objectApiName: "Case",
                actionName: "home",
            },
        });
        console.log('Fired Navigate');

        //if (!this.phoneNumber) {
        //    console.error('LWC Error: No phone number found.');
        //    return;
        //}

        // --- ACTION 1: INITIATE THE CALL via Service Cloud Voice ---
        //fireClickToDial({
        //    number: this.phoneNumber,
        //    recordId: this.recordId
        //});

        // --- ACTION 2: OPEN THE CUSTOM LWC COMPONENT ---
        // Use the 'standard__component' page reference type for direct component navigation
/*

        const pageReference = {
            type: 'standard__component',
            attributes: {
                // The API name of the LWC to open
                componentName: 'c__crmGlobalCaseCreationPage'
            },
            state: {
                // These key-value pairs become the URL parameters
                c__action: 'CaseDetail',
                c__id: this.recordId, // Pass the current Case ID
                c__AccountId: this.accountId // Pass the fetched Account ID
            }
        };


        console.log('Fired pageRef');
        this[NavigationMixin.Navigate](pageReference);
        console.log('Fired pageRef complete'); */
    }
}