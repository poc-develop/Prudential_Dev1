import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import the Contact Client Code.
import CLIENT_CODE from '@salesforce/schema/Account.FinServ__CustomerID__c';

export default class PrulifeLauncher extends LightningElement {
    // Get the record ID from the page
    @api recordId;

    clientCode;

    // Use the wire service to get the record data
    @wire(getRecord, { recordId: '$recordId', fields: [CLIENT_CODE] })
    wiredContact({ error, data }) {
        if (data) {
            // Get the client code from the record data
            this.clientCode = getFieldValue(data, CLIENT_CODE);
        } else if (error) {
            console.error('Error fetching contact phone:', JSON.stringify(error));
        }
    }

    // Getter to disable the button if the client code is not available
    get isButtonDisabled() {
        return !this.clientCode;
    }

    //Param: id key, winnetworkusername, programid, propno, clientcode, workflowcontrolcode

    // This function runs when the button is clicked
    handleOpenApp() {
        if (this.clientCode) {
            
            // Construct the final custom URL
            const appUrl = `bpmcall:nbrunprogram?65cb1caf-3cf1-47b8-b42a-e3587e672802%20prulifeu1%20npitlyyt%20lnb3200d%20000020053631%20%22%22%20%22%22%20%22%22`;
            
            // Log to console for debugging
            console.log(`Attempting to open URL: ${appUrl}`);

            // Use window.open to launch the custom URL schema
            window.open(appUrl, '_self');

        } else {
            // Show an error message if the phone number is missing
            this.showToast('Error', 'Phone number is not available on this record.', 'error');
        }
    }

    handleOpenApp1() {
        if (this.clientCode) {
            
            // Construct the final custom URL
            const appUrl = `bpmcall://nbrunprogram?65cb1caf-3cf1-47b8-b42a-e3587e672802%20prulifeu1%20npitlyyt%20lnb3200d%20000020053631%20%22%22%20%22%22%20%22%22`;
            
            // Log to console for debugging
            console.log(`Attempting to open URL: ${appUrl}`);

            // Use window.open to launch the custom URL schema
            window.open(appUrl, '_self');

        } else {
            // Show an error message if the phone number is missing
            this.showToast('Error', 'Phone number is not available on this record.', 'error');
        }
    }

    // Helper function to show toast messages
    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
}