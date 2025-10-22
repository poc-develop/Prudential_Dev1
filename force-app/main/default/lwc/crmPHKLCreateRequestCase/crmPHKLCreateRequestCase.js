import { LightningElement, api, track, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import getPicklistValues from '@salesforce/apex/CRMPHKLCreateRequestCaseController.getPicklistValues';
import createRequestCase from '@salesforce/apex/CRMPHKLCreateRequestCaseController.createRequestCase';
import searchUsers from '@salesforce/apex/CRMPHKLCreateRequestCaseController.searchUsers';
import getDueDatetime from '@salesforce/apex/CRMPHKLCreateRequestCaseController.getDueDatetime';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import CASE_NUMBER_FIELD from '@salesforce/schema/Case.CaseNumber';

export default class CrmPHKLCreateRequestCase extends LightningElement {
    @api recordId; // 当前页面的Case记录ID
    
    // Form fields
    @track requestType = '';
    @track status = 'New';
    @track requestEnquiryCase = null;
    @track relatedRequest = null;
    @track recipient1 = '';
    @track recipient1Department = '';
    @track recipient1External = '';
    @track requestSummary1 = '';
    @track dueDate1 = '';
    @track autoProceed = false;
    @track recipient2 = '';
    @track recipient2Department = '';
    @track recipient2External = '';
    @track requestSummary2 = '';
    @track dueDate2 = '';
    
    // Locate Payment fields
    @track policyNumber = '';
    @track nameOfAssured = '';
    // @track followUpActionRequestToFIN = '';
    // @track other = '';
    @track refundChannel = '';
    @track refundDate = '';
    @track amount = '';
    // @track supportingDocuments = '';
    
    @track isShowLocatePaymentPart = false;
    
    // Loading state
    @track isLoading = false;
    
    // Validation
    @track validationErrors = [];
    @track recipient1Required = false;
    @track recipient2Required = false;
    @track financeRequired = false;

    // Current case information
    @track currentCaseNumber = '';
    @track requestTypeOptions = [];
    @track statusOptions = [];
    @track refundChannelOptions = [];

    // Copy To functionality
    @track selectedUsers = [];
    @track isModalOpen = false;
    @track users = [];
    @track searchTerm = '';

    @track errorMessage = '';

    // Wire adapter to get current case record
    @wire(getRecord, { recordId: '$recordId', fields: [CASE_NUMBER_FIELD] })
    wiredCaseRecord({ error, data }) {
        if (data) {
            this.currentCaseNumber = getFieldValue(data, CASE_NUMBER_FIELD);
            // Set the current case as the default value for the lookup
            this.requestEnquiryCase = this.recordId;
        } else if (error) {
            console.error('Error loading current case info:', error);
        }
    }

    connectedCallback() {
        this.loadPicklistValues();
    }

    loadPicklistValues() {
        getPicklistValues({ 
            fieldNames: [
                'Case.CRM_Global_RequestCaseType__c',
                'Case.Status',
                'Case.CRM_Global_RefundChannel__c'
            ]
        })
        .then(result => {
            this.requestTypeOptions = [ { label: '', value: '', selected: true }, ...result.Case_CRM_Global_RequestCaseType__c ];
            this.statusOptions = [ { label: 'New', value: 'New', selected: true } ];
            this.refundChannelOptions = result.Case_CRM_Global_RefundChannel__c;
        })
        .catch(error => {
            console.error('Error loading picklist values:', error);
        });
    }

    // Event handlers for form fields
    handleRequestTypeChange(event) {
        this.requestType = event.detail.value;
        this.isShowLocatePaymentPart = (this.requestType === 'Locate Payment' || this.requestType === 'Stop and Reissue Cheque' || this.requestType === 'CFI');
        this.financeRequired = this.requestType === 'CFI';
        if(this.requestType != '' && this.recipient1 != '' && this.recipient1 != null){
            this.loadDueDatetime();
        }
    }

    handleRequestEnquiryCaseChange(event) {
        this.requestEnquiryCase = event.detail.value;
    }

    handleRelatedRequestChange(event) {
        const relatedRequestArr = event.detail.value;
        this.relatedRequest = relatedRequestArr[0];
    }

    handleRecipient1Change(event) {
        const recipient1Arr = event.detail.value;
        this.recipient1 = recipient1Arr[0];
        this.recipient1Required = !!this.recipient1;
        
        // 如果Recipient1被清空，则清除相关字段的验证错误
        if (!this.recipient1) {
            this.dueDate1 = '';
        }else{
            this.loadDueDatetime();
        }
    }

    loadDueDatetime() {
        if(this.requestType === '' || this.recipient1 === '' || this.recipient1 === null){
            return;
        }
        getDueDatetime({
            requestType: this.requestType,
            caseStatus: '1st Round Processing' 
        })
        .then(result => {
            if (result === null || result === '') {
                this.dueDate1 = '';
                return;
            }   
            this.dueDate1 = result;
        });
    }

    handleRecipient1DepartmentChange(event) {
        this.recipient1Department = event.detail.value;
    }

    handleRecipient1ExternalChange(event) {
        this.recipient1External = event.detail.value;
    }

    handleRequestSummary1Change(event) {
        this.requestSummary1 = event.detail.value;
    }

    handleDueDate1Change(event) {
        this.dueDate1 = event.detail.value;
    }

    handleAutoProceedChange(event) {
        this.autoProceed = event.detail.checked;
    }

    handleRecipient2Change(event) {
        const recipient2Arr = event.detail.value;
        this.recipient2 = recipient2Arr[0];
        this.recipient2Required = !!this.recipient2;
        // 如果Recipient2被清空，则清除相关字段的验证错误
        if (!this.recipient2) {
            this.dueDate2 = '';
        }
    }

    handleRecipient2DepartmentChange(event) {
        this.recipient2Department = event.detail.value;
    }

    handleRecipient2ExternalChange(event) {
        this.recipient2External = event.detail.value;
    }

    handleRequestSummary2Change(event) {
        this.requestSummary2 = event.detail.value;
    }

    handleDueDate2Change(event) {
        this.dueDate2 = event.detail.value;
    }

    // Locate Payment字段的事件处理
    handlePolicyNumberChange(event) {
        this.policyNumber = event.detail.value;
    }

    handleNameOfAssuredChange(event) {
        this.nameOfAssured = event.detail.value;
    }

    handleRefundChannelChange(event) {
        this.refundChannel = event.detail.value;
    }

    handleFollowUpActionRequestToFINChange(event) {
        this.followUpActionRequestToFIN = event.detail.value;
    }

    handleOtherChange(event) {
        this.other = event.detail.value;
    }

    handleRefundDateChange(event) {
        this.refundDate = event.detail.value;
    }

    handleAmountChange(event) {
        this.amount = event.detail.value;
    }

    handleSupportingDocumentsChange(event) {
        this.supportingDocuments = event.detail.value;
    }

    // Close modal (for Quick Action, this will close the action)
    handleCloseModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // 字段验证方法
    validateField(fieldName, value, errorMessage) {
        // 对于标准组件，使用setCustomValidity
        const field = this.template.querySelector(`[data-field="${fieldName}"]`);
        if (field && field.setCustomValidity) {
            if (!value) {
                field.setCustomValidity(errorMessage);
            } else {
                field.setCustomValidity('');
            }
            field.reportValidity();
        }
    }

    // 清除字段验证
    clearValidation(fieldName) {
        const field = this.template.querySelector(`[data-field="${fieldName}"]`);
        if (field) {
            field.setCustomValidity('');
            field.reportValidity();
        }
    }

    // 表单验证
    validateForm() {
        // Check required fields
        const inputs = [...this.template.querySelectorAll('lightning-input, lightning-input-field, lightning-combobox, lightning-textarea')];
        const isValid = inputs.reduce((valid, input) => {
            if (input.reportValidity) {
                return input.reportValidity() && valid;
            }
            return valid;
        }, true);
        
        if (!isValid) {
            this.errorMessage = 'Please complete all required fields.';
            return false;
        }
        
        return isValid;
    }


    // Create request
    async createRequest() {
        if (!this.validateForm()) {
            this.showError(this.errorMessage || 'Please complete all required fields.');
            return;
        }

        // Set loading state
        this.isLoading = true;

        // Prepare copyTo field from selected users
        let copyTo = '';
        if (this.selectedUsers.length > 0) {
            copyTo = this.selectedUsers.map(user => user.Email).join(';');
        }

        let refundChannelStr = '';
        if(this.refundChannel.length > 0){
            refundChannelStr = this.refundChannel.join(';');
        }

        try {
            // Prepare request data
            const requestData = {
                requestType: this.requestType,
                status: this.status,
                requestEnquiryCase: this.requestEnquiryCase,
                relatedRequest: this.relatedRequest,
                recipient1: this.recipient1,
                recipient1Department: this.recipient1Department,
                recipient1External: this.recipient1External,
                requestSummary1: this.requestSummary1,
                dueDate1: this.dueDate1,
                autoProceed: this.autoProceed,
                recipient2: this.recipient2,
                recipient2Department: this.recipient2Department,
                recipient2External: this.recipient2External,
                requestSummary2: this.requestSummary2,
                dueDate2: this.dueDate2,
                copyTo: copyTo,
                // Locate Payment fields
                policyNumber: this.policyNumber,
                nameOfAssured: this.nameOfAssured,
                // followUpActionRequestToFIN: this.followUpActionRequestToFIN,
                // other: this.other,
                refundChannel: refundChannelStr,
                refundDate: this.refundDate,
                amount: this.amount,
                // supportingDocuments: this.supportingDocuments
            };

            console.log('requestData: ' + JSON.stringify(requestData));

            // Call Apex method to create Case record
            const result = await createRequestCase({ requestDataJsonStr: JSON.stringify(requestData) });

            // Check if creation was successful
            if (result.isSuccess) {
                // Show success message
                this.showToast('Success', result.message, 'success');
                
                window.location.href = '/' + result.caseId;
                // Reset form and close modal
                this.handleCloseModal();
            } else {
                // Show error message from Apex
                this.showError(result.message);
            }

        } catch (error) {
            console.error('Error creating request case:', error);
            this.showError('Failed to create request case: ' + (error.body?.message || error.message));
        } finally {
            // Reset loading state
            this.isLoading = false;
        }
    }

    // Reset form fields
    resetForm() {
        this.requestType = '';
        this.status = 'New';
        this.requestEnquiryCase = this.recordId || null;
        this.relatedRequest = null;
        this.recipient1 = '';
        this.recipient1Department = '';
        this.requestSummary1 = '';
        this.dueDate1 = '';
        this.autoProceed = false;
        this.caseOwner = '';
        this.recipient2Department = '';
        this.requestSummary2 = '';
        this.dueDate2 = '';
        // Locate Payment fields
        this.policyNumber = '';
        this.nameOfAssured = '';
        // this.followUpActionRequestToFIN = '';
        // this.other = '';
        this.refundChannel = '';
        this.refundDate = '';
        this.amount = '';
        // this.supportingDocuments = '';
        
        this.isShowLocatePaymentPart = false;
        this.selectedUsers = [];
        this.validationErrors = [];
        this.recipient1Required = false;
        this.recipient2Required = false;
        this.financeRequired = false;

        // 清除所有验证错误
        this.clearAllValidations();
    }

    // 清除所有验证错误
    clearAllValidations() {
        const fields = this.template.querySelectorAll('lightning-input, lightning-input-field, lightning-combobox, lightning-textarea');
        fields.forEach(field => {
            field.setCustomValidity('');
            field.reportValidity();
        });
    }

    // Show error message
    showError(message) {
        console.error('Validation Error:', message);
        this.showToast('Error', message, 'error');
    }

    // Show toast notification
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    // Public method to set case ID
    @api
    setCaseId(caseId) {
        this.requestEnquiryCase = caseId;
    }

    // Public method to set record ID
    @api
    setRecordId(recordId) {
        this.recordId = recordId;
    }

    // Copy To functionality methods
    openModal() {
        this.isModalOpen = true;
        this.searchUsers();
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.searchUsers();
    }

    searchUsers() {
        searchUsers({ searchTerm: this.searchTerm })
        .then(result => {
            this.users = result.map(user => {
                return {
                    ...user,
                    checked: this.selectedUsers.some(selectedUser => selectedUser.Id === user.Id)
                };
            });
        })
        .catch(error => {
            console.error('Error searching users', error);
        });
    }

    handleUserSelection(event) {
        const userId = event.target.dataset.id;
        const isChecked = event.target.checked;
        
        const userIndex = this.users.findIndex(user => user.Id === userId);
        if (userIndex !== -1) {
            this.users[userIndex].checked = isChecked;
        }
    }

    handleConfirm() {
        // Add newly selected users
        const newlySelectedUsers = this.users.filter(user => user.checked && !this.selectedUsers.some(u => u.Id === user.Id));
        this.selectedUsers = [...this.selectedUsers, ...newlySelectedUsers];
        
        // Remove users that were deselected
        const usersToRemove = this.selectedUsers.filter(user => 
            this.users.some(u => u.Id === user.Id && !u.checked)
        );
        
        usersToRemove.forEach(user => {
            this.selectedUsers = this.selectedUsers.filter(u => u.Id !== user.Id);
        });
        
        this.closeModal();
    }

    removeUser(event) {
        const userId = event.detail.name;
        this.selectedUsers = this.selectedUsers.filter(user => user.Id !== userId);
        
        // Update users array to reflect the change
        const userIndex = this.users.findIndex(user => user.Id === userId);
        if (userIndex !== -1) {
            this.users[userIndex].checked = false;
        }
    }
}