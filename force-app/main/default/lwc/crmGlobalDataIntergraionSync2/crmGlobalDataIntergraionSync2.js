import { LightningElement, track, api, wire } from 'lwc';
import syncWithIntegration from '@salesforce/apex/CRMGlobalDataIntegrationController.syncWithIntegration';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { RefreshEvent } from 'lightning/refresh';
import { publish, subscribe, MessageContext, COMPONENT_SCOPE, APPLICATION_SCOPE } from 'lightning/messageService';
import DataIntegrationMessageChannel from '@salesforce/messageChannel/CRMGlobalDataIntegrationMessageChannel__c';

export default class CRMGlobalDataIntergraionSync2 extends LightningElement {
    @api recordId;
    @api componentId;
    @api configName;
    @api buttonLabel;
    // @api updateConfigName;
    // @api relatedListApiName;
    @api autoTriggerOnLoad = false;
    @api isVisible = false;
    @api targetComponentIds;
    @track isLoading = false;
    @track label;
    @track successMessage;
    @track errorMessage;

    @wire(MessageContext) messageContext;
    subscription = null;

    connectedCallback() {
        this.subscribeToMessageChannel();
        if (this.autoTriggerOnLoad) {
            console.info(`[${this.componentId}] auto trigger data sync with: ${this.configName}`);
            this.initiateSync();
        }
    }

    async handleClick() {
        console.info(`${this.componentId} manually trigger data sync with: ${this.configName}`);
        this.initiateSync();
    }

    async initiateSync() {
        if (this.isLoading) {
            return;
        }
        this.isLoading = true;
        this.errorMessage = undefined;
        this.successMessage = undefined;

        try {
            const result = await syncWithIntegration({
                recordId: this.recordId,
                configName: this.configName
            });
            console.log("result:",JSON.stringify(result));
            if(result.isSuccess) {
                this.successMessage = `[${this.componentId}] sync data with ${this.configName} successfully completed`;
                console.info(this.successMessage);

                // Refresh the view after successful sync
                getRecordNotifyChange([{ recordId: this.recordId }]);
                const refreshEvent = new RefreshEvent();
                this.dispatchEvent(refreshEvent);

                if(this.targetComponentIds) {
                    console.info(`${this.componentId} trigger other components: [${this.targetComponentIds}]`);
                    publish(this.messageContext, DataIntegrationMessageChannel, {
                        sourceComponentId: this.componentId,
                        targetComponentIds: this.targetComponentIds
                    });
                }
            } else {
                console.error(`[${this.componentId}] failed to sync data with ${this.configName}: `, result.message);
                if (result.message && result.message.startsWith('API')) {
                    const parts = result.message.split('|');
                    const title = parts[0] ? parts[0].trim() : 'API Error';
                    const message = parts[1] ? parts[1].trim() : 'Unknown error';
                    this.showToast(title, message, 'error');
                }
            }
        } catch (error) {
            this.errorMessage = this.parseError(error);
            console.error(`[${this.componentId}] failed to sync data with ${this.configName}: `, this.errorMessage);
        } finally {
            this.isLoading = false;
        }
    }

    parseError(error) {
        if (typeof error === 'string') return error;
        if (error.body?.message) return error.body.message;
        if (error.message) return error.message;
        return 'Unknown error occurred';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ 
            title: title, 
            message: message, 
            variant: variant,
            mode: 'sticky'
        }));
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                DataIntegrationMessageChannel,
                (message) => this.handleMessage(message),
                { scope: COMPONENT_SCOPE }
            );
        }
    }

    handleMessage(message) {
        const { sourceComponentId, targetComponentIds } = message;
        if (sourceComponentId === this.componentId) {
            return;
        }
        if (targetComponentIds && targetComponentIds.includes(this.componentId)) {
            console.info(`[${this.componentId}] received message from [${sourceComponentId}]`);
            this.initiateSync();
        }
    }
}