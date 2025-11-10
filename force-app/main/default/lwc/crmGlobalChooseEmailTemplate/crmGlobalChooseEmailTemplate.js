import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import CASE_POLICY_FIELD from '@salesforce/schema/Case.CRM_Global_Policy__c';
import searchLightningEmailTemplates from '@salesforce/apex/CRMGlobalEmailTemplateController.searchLightningEmailTemplates';
import getTemplateContent from '@salesforce/apex/CRMGlobalEmailTemplateController.getTemplateContent';
import getCaseContactNumber from '@salesforce/apex/CRMGlobalEmailTemplateController.getCaseContactNumber';
import mergeInsurancePolicyFields from '@salesforce/apex/CRMGlobalEmailTemplateController.mergeInsurancePolicyFields';
import canEditEmailContent from '@salesforce/apex/CRMGlobalEmailTemplateController.canEditEmailContent';
import sendSms from '@salesforce/apex/CRMGlobalEmailTemplateController.sendSms';

export default class CrmGlobalChooseEmailTemplate extends LightningElement {

    @track searchKey = '';
    @track templateOptions = [];
    @track selectedTemplateId = '';
    @track selectedTemplateName = '';
    @track emailContent = '';
    @track noTemplateFound = false;
    @track defualtAddress = '';
    @track policyNo;
    noTemplateFoundMessage = 'No Lightning Email Templates found matching your search';
    @track isLoading = false;
    @track isEmailContentEditable = false; // Default to readonly for security
    
    // Current page record ID
    @api recordId;
    currentRecordId = '';
    
    // Current page object API name
    currentObjectApiName = '';

    templateMap = new Map();

    // Get current page reference to extract record ID
    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (pageRef) {
            console.log('Page Reference:', JSON.stringify(pageRef));
            
            // For record pages (standard/custom object record pages)
            if (pageRef.type === 'standard__recordPage') {
                this.currentRecordId = pageRef.attributes.recordId || '';
                this.currentObjectApiName = pageRef.attributes.objectApiName || '';
                console.log('Current Record ID:', this.currentRecordId);
                console.log('Current Object API Name:', this.currentObjectApiName);
            }
            
            // For other page types, try to get recordId from state
            if (pageRef.state && pageRef.state.recordId) {
                this.currentRecordId = pageRef.state.recordId;
                console.log('Record ID from state:', this.currentRecordId);
            }
            
            // Also check if recordId is passed as @api (for embedded scenarios)
            if (this.recordId) {
                this.currentRecordId = this.recordId;
                console.log('Record ID from @api:', this.recordId);
            }
        }
    }

    // Wire to get Case record and load Policy field
    @wire(getRecord, { recordId: '$currentRecordId', fields: [CASE_POLICY_FIELD] })
    wiredCaseRecord({ error, data }) {
        if (data) {
            // Load initial Policy value from Case record
            this.policyNo = getFieldValue(data, CASE_POLICY_FIELD);
            console.log('Loaded Policy No from Case:', this.policyNo);
        } else if (error) {
            console.error('Error loading Case record:', error);
        }
    }

    connectedCallback() {
        // Load contact number if recordId is available on component initialization
        if (this.currentRecordId) {
            this.loadCaseContactNumber();
        }
        // Check if user can edit email content
        this.checkEditPermission();
    }
    
    /**
     * Check if current user can edit email content
     */
    checkEditPermission() {
        canEditEmailContent()
            .then(result => {
                this.isEmailContentEditable = result;
                console.log('Can edit email content:', this.isEmailContentEditable);
            })
            .catch(error => {
                console.error('Error checking edit permission:', error);
                // Default to readonly on error
                this.isEmailContentEditable = false;
            });
    }
    
    /**
     * Load Case contact number from current record
     */
    loadCaseContactNumber() {
        getCaseContactNumber({ recordId: this.currentRecordId })
            .then(result => {
                if (result) {
                    this.defualtAddress = result;
                } else {
                    this.defualtAddress = '';
                }
            })
            .catch(error => {
                console.error('Error loading Case contact number:', error);
            });
    }

    get hasSearchResults() {
        return this.templateOptions.length > 0;
    }

    //  button disabled
    get isSendButtonDisabled() {
        return !this.selectedTemplateId || !this.emailContent;
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            this.loadTemplates(this.searchKey);
        }, 500);
    }

    loadTemplates(searchText) {
        this.isLoading = true;
        this.noTemplateFound = false;
        searchLightningEmailTemplates({ 'searchKey': searchText })
        .then(result => {
            this.templateOptions = result.map(template => ({
                label: template.Name,
                value: template.Id
            }));
            this.templateMap.clear();
            this.templateOptions.forEach(template => {
                this.templateMap.set(template.value, template);
            });

            if (this.templateOptions.length === 0 && searchText) {
                this.noTemplateFound = true;
            }
        })
        .catch(error => {
            console.error('Error loading templates:', error);
        }).finally(() => {
            this.isLoading = false;
        });
    }

    handleTemplateSelect(event) {
        this.selectedTemplateId = event.detail.value;
        const template = this.templateMap.get(this.selectedTemplateId);
        
        if (template) {
            this.selectedTemplateName = template.Name;
            this.loadTemplateContent(this.selectedTemplateId);
        }
    }

    loadTemplateContent(templateId) {
        this.isLoading = true;
        getTemplateContent({ 'templateId': templateId, 'recordId': this.currentRecordId })
        .then(result => {
            // Result is a Map with 'content', 'subject', and 'templateName'
            this.emailContent = result.content || '';
            console.log('Subject:', result.subject);
            mergeInsurancePolicyFields({ 
                'templateContent': this.emailContent, 
                'insurancePolicyId': this.policyNo 
            })
            .then(result => {
                if (result) {
                    this.emailContent = result;
                    console.log('Insurance Policy fields merged successfully');
                }
            })
            .catch(error => {
                console.error('Error merging Insurance Policy fields:', error);
                this.showToast('Error', 'Failed to merge Insurance Policy fields: ' + (error.body?.message || error.message), 'error');
            })
        })
        .catch(error => {
            console.error('Error loading template content:', error);
            this.showToast('Error', 'Failed to load template content: ' + (error.body?.message || error.message), 'error');
        }).finally(() => {
            this.isLoading = false;
        });
    }

    handleEmailContentChange(event) {
        this.emailContent = event.target.value;
    }

    handlePolicyNoChange(event) {
        const policyId = event.detail.value[0];
        console.log('Policy No changed:', policyId);
        
        // If emailContent exists and policyId is provided, merge InsurancePolicy fields
        if (this.emailContent && policyId) {
            this.isLoading = true;
            mergeInsurancePolicyFields({ 
                'templateContent': this.emailContent, 
                'insurancePolicyId': policyId 
            })
            .then(result => {
                if (result) {
                    this.emailContent = result;
                    console.log('Insurance Policy fields merged successfully');
                }
            })
            .catch(error => {
                console.error('Error merging Insurance Policy fields:', error);
                this.showToast('Error', 'Failed to merge Insurance Policy fields: ' + (error.body?.message || error.message), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
        }
    }

    handleAddressChange(event) {
        this.defualtAddress = event.target.value;
    }

    handleSendNote() {
        this.isLoading = true;
        sendSms({
            'recipientNumber': this.defualtAddress,
            'templateContent': this.emailContent,
            'recordId': this.currentRecordId
        })
        .then(result => {
            if (result.success) {
                this.showToast('Success', 'SMS sent successfully', 'success');
            } else {
                this.showToast('Error', 'Failed to send SMS: ' + (result.message || 'Unknown error'), 'error');
            }
            this.emailContent = result.message;
        })
        .catch(error => {
            console.error('Error sending SMS:', error);
            this.showToast('Error', 'Failed to send SMS: ' + (error.body?.message || error.message), 'error');
        })
        .finally(() => {
            this.isLoading = false;
            // this.clearForm();
        });
    }

    // Clear form data
    clearForm() {
        this.selectedTemplateId = '';
        this.selectedTemplateName = '';
        this.emailContent = '';
        this.searchKey = '';
    }

    // Show toast message
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}