import { LightningElement,wire,api,track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createCaseReply from '@salesforce/apex/CRMGlobalCreateCaseReplyController.createCaseReply';

export default class CrmGlobalCreateCaseReply extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track replyText = '';

    // 处理回复文本变化
    handleReplyChange(event) {
        this.replyText = event.target.value;
    }

    // 判断确认按钮是否禁用
    get isConfirmDisabled() {
        return !this.replyText || this.replyText.trim().length === 0 || this.isLoading;
    }

    // 处理取消按钮点击
    handleCancel() {
        this.close();
    }

    // 处理确认按钮点击
    async handleConfirm() {
        if (!this.replyText || this.replyText.trim().length === 0) {
            this.showToast('Error', 'Please enter a reply', 'error');
            return;
        }
        this.isLoading = true;
        createCaseReply({ caseId: this.recordId, replyText: this.replyText })
        .then(result => {
            if (result) {
                this.showToast('Success', 'Reply sent successfully', 'success');
            } else {
                this.showToast('Error', 'Failed to send reply', 'error');
            }
        })
        .catch(error => {
            console.error('Error saving reply:', error);
            this.showToast(
                'Error', 
                error.body?.message || 'An error occurred while sending the reply', 
                'error'
            );
        })
        .finally(() => {
            this.close();
            this.isLoading = false;
        });

    }

    // 显示 Toast 消息
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    close() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}