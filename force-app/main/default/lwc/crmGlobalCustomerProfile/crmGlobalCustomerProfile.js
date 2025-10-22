import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { openTab, focusTab, closeTab, getFocusedTabInfo } from 'lightning/platformWorkspaceApi';
import getAccountIdByClientCode from '@salesforce/apex/CRMGlobalCustomerProfileController.getAccountIdByClientCode';

export default class CRMGlobalCustomerProfile extends LightningElement {
    @track notFound = false;
    clientCode;
    
    @wire(CurrentPageReference)
    getPageReferenceParameters(currentPageReference) {
        if (currentPageReference) {
            this.clientCode = currentPageReference.state.c__clientCode;
        }
    }

    connectedCallback() {
        console.log('Client Code (from param):', this.clientCode);
        if (this.clientCode) {
            getAccountIdByClientCode({ clientCode: this.clientCode })
                .then(accountId => {
                    console.log('Fetched Account ID:', accountId);
                    if (accountId) {
                        getFocusedTabInfo().then(focusedTabInfo => {
                            const currentTabId = focusedTabInfo.tabId;
                            openTab({
                                recordId: accountId,
                                focus: false
                            }).then(newTabId => {
                                focusTab({ tabId: newTabId });
                            }).then(() => {
                                closeTab(currentTabId);
                            });
                        });
                    } else {
                        this.notFound = true;
                    }
                })
                .catch(error => {
                    console.error('Error fetching account:', error);
                    this.notFound = true;
                });
        } else {
            this.notFound = true;
        }
    }
}