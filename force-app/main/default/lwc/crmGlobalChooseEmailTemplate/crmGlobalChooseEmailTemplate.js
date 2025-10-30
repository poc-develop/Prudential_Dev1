import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchLightningEmailTemplates from '@salesforce/apex/CRMGlobalEmailTemplateController.searchLightningEmailTemplates';
import getTemplateContent from '@salesforce/apex/CRMGlobalEmailTemplateController.getTemplateContent';

export default class CrmGlobalChooseEmailTemplate extends LightningElement {

    @track searchKey = '';
    @track templateOptions = [];
    @track selectedTemplateId = '';
    @track selectedTemplateName = '';
    @track emailContent = '';
    @track noTemplateFound = false;
    noTemplateFoundMessage = 'No Lightning Email Templates found matching your search';
    @track isLoading = false;

    templateMap = new Map();

    connectedCallback() {
        
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

    async loadTemplates(searchText) {
        this.isLoading = true;
        this.noTemplateFound = false;
        searchLightningEmailTemplates({ searchKey: searchText })
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

    async handleTemplateSelect(event) {
        this.selectedTemplateId = event.detail.value;
        const template = this.templateMap.get(this.selectedTemplateId);
        
        if (template) {
            this.selectedTemplateName = template.Name;
            await this.loadTemplateContent(this.selectedTemplateId);
        }
    }

    async loadTemplateContent(templateId) {
        this.isLoading = true;
        getTemplateContent({ templateId: templateId })
        .then(result => {
            // Extract text content from HTML
            const htmlContent = result.HtmlValue || result.Body || '';
            this.emailContent = this.extractTextFromHtml(htmlContent);
        })
        .catch(error => {
            console.error('Error loading template content:', error);
            return null;
        }).finally(() => {
            this.isLoading = false;
        });
    }

    // Extract text content from HTML string
    extractTextFromHtml(html) {
        if (!html) return '';
        
        // Create a temporary div element to parse HTML
        const tempDiv = document.createElement('div');
        tempDiv.innerHTML = html;
        
        // Get text content (automatically strips all HTML tags)
        const textContent = tempDiv.textContent || tempDiv.innerText || '';
        
        // Clean up
        return textContent.trim();
    }

    handleEmailContentChange(event) {
        this.emailContent = event.target.value;
    }

    async handleSendNote() {
        this.isLoading = true;
        try {

            this.clearForm();
        } catch (error) {
            console.error('Error sending note:', error);
            this.showToast('Error', 'Failed to send note: ' + error.body?.message, 'error');
        } finally {
            this.isLoading = false;
        }
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