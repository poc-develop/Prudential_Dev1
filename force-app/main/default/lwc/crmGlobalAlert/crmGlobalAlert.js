import { LightningElement, api, track, wire } from 'lwc';
import getAlerts from '@salesforce/apex/CRMGlobalAlertController.getAlerts';
import dismissTask from '@salesforce/apex/CRMGlobalAlertController.dismissTask';
import getRecordTypeId from '@salesforce/apex/CRMGlobalAlertController.getRecordTypeId';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
export default class Alert extends NavigationMixin(LightningElement) {
    @api recordId; 
    @api objectApiName;
    tasks = []; 
    wiredTasksResult; 
    @track isLoading = false;
    @track isConfirmationOpen = false;
    @track currentTaskId;

    
    @wire(getAlerts, { accountId: '$recordId' })
    wiredTasks(result) {
        console.error('start');
        this.wiredTasksResult = result;
        this.isLoading = result.data === undefined;
        
        if (result?.data) {
            
            this.tasks = result.data.map(task => ({
                ...task,
                expanded: false,
                icon: 'utility:notification',
                chevronIcon: 'utility:chevronright',
                expandText: 'Expand'
            }));
            console.log('bb'+JSON.stringify(this.tasks));
        } else if (result?.error) {
            this.tasks = []; 
            console.error('加载任务失败:', result.error);
        }
    }
    connectedCallback() {
        getRecordTypeId({ developerName: 'CRM_GLOBAL_Alert_Task' })
            .then((result) => {
                this.recordTypeId = result;
            })
            .catch((error) => {
                this.showToast('Error', 'Failed to get Record Type ID', 'error');
                console.error(error);
            });
    }

    
    get hasTasks() {
        
        return this.tasks.length > 0 
    }
    get hasError(){
        return this.wiredTasksResult?.error;
    }
    get alertCount() {
        return this.tasks ? this.tasks.length : 0;
    }
    get alertCountText() {
        return `Alerts (${this.alertCount})`;
    }

    
    handleExpand(event) {
        const taskId = event.target.dataset.taskid || event.target.closest('[data-taskid]')?.dataset.taskid;
        if (!taskId) return; 

        this.tasks = this.tasks.map(task => {
            if (task.Id === taskId) {
                const isExpanded = !task.expanded;
                return {
                    ...task,
                    expanded: isExpanded,
                    chevronIcon: isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                    expandText: isExpanded ? 'Collapse' : 'Expand'
                };
            }
            return task;
        });
    }


    async handleConfirmDismiss() {
        this.isConfirmationOpen = false    
        if (!this.currentTaskId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Task ID is missing',
                variant: 'error'
            }));
            return;
        }
        
        try {
            this.isLoading = true
            await dismissTask({ taskId: this.currentTaskId });
            this.isLoading = false
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Task Completed',
                variant: 'success'
            }));
            await refreshApex(this.wiredTasksResult);
        } catch (error) {
            console.log(error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'update task failed: ' + (error?.message || 'known error'),
                variant: 'error'
            }));
        }
    }

    handleRefresh() {
        
        this.isLoading = true;
        return refreshApex(this.wiredTasksResult).then(() => {
            this.tasks = this.tasks.map(task => {
            return {
                ...task,
                expanded: false,
                chevronIcon: 'utility:chevronright',
                expandText: 'Expand'
            };
         
        });
            this.isLoading = false;
        }).catch(error => {
            this.error = error;
            this.isLoading = false;
            console.log(this.isLoading);
        })
    }

     openTaskQuickAction() {
        console.log("openTaskQuickAction");
        if (!this.recordTypeId) {
            this.showToast('Error', 'Record Type ID is not available yet', 'error');
            return;
        }
        // this[NavigationMixin.Navigate]({
        //     type: 'standard__objectPage',
        //     attributes: {
        //         objectApiName: 'Task', // Task object
        //         actionName: 'new' // Go to "New Task" page
        //     },
        //     state: {
        //         recordTypeId: this.recordTypeId, // Set the Record Type
        //         defaultFieldValues: `WhatId=${this.recordId}`
        //     }
        // });
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: 'Account.CRM_Global_CreateCustomerAlert' // Task object
            },
            state: {
                recordId: this.recordId // Set the Record Type
            }
        });
    }

    // Open confirmation modal when dismiss button is clicked
    handleDismissClick(event) {
        const taskId = event.target.dataset.taskid || event.target.closest('[data-taskid]')?.dataset.taskid;
        if (!taskId) return;

        this.currentTaskId = taskId;
        this.isConfirmationOpen = true;
    }

    // Close modal without dismissing
    handleCancelDismiss() {
        this.isConfirmationOpen = false;
    }

    // Handle backdrop click to close modal
    handleBackdropClick() {
        this.isConfirmationOpen = false;
    }

        
}