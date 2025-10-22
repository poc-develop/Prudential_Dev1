import { LightningElement, api, wire } from 'lwc';
import policyMethodAndAccountId from '@salesforce/apex/CRMPHKLPaymentMethodViewFormController.policyMethodAndAccountId';

export default class crmPHKLPaymentMethodViewForm extends LightningElement {
    // @api policyPaymentMethodRecordId = 'a0sD3000001ENqUIAW';
    // @api financialAccountRecordId = 'a0iD3000002AvBKIA0'; 
    // @api recordId = '0YTD3000000kuKeOAI';
    @api recordId;
    @api policyPaymentMethodRecordId;
    @api financialAccountRecordId;
    @api paymentMethordObjectApiName = 'FinServ__PolicyPaymentMethod__c';
    @api financialAccountObjectApiName = 'FinServ__FinancialAccount__c';
    
    paymentMethordFields = ["CRM_Global_PaymentStatus__c"
            ,"FinServ__EndDate__c"
            ,"CRM_Global_TotalCurrentModalPrem__c"
            ,"CRM_Global_PaymentMode__c"
            ,"CRM_Global_PaymentMethod__c"
            ,"CRM_Global_BillingNo__c"
            ];

    financialAccountFields = ["FinServ__Status__c"
            ,"FinServ__OpenDate__c"
            ,"FinServ__FinancialAccountNumber__c"
            ,"CRM_Global_AccountHolder__c"
            ,"FinServ__LastUpdated__c"
            ,"FinServ__PrimaryBankerName__c"
            ,"FinServ__CloseDate__c"
            ,"FinServ__SecondaryBankerName__c"
            ,"FinServ__ClosureReason__c"
            ,"CRM_Global_CreditCardExpiryDate__c"
            ];

    @wire(policyMethodAndAccountId, { insurancePolicyId: '$recordId' })
    wiredGetId({ error, data }) {
        if (data) {
            console.log('policyMethodAndAccountId:'+ JSON.stringify(data));
            this.policyPaymentMethodRecordId = data.policyPaymentMethodRecordId;
            this.financialAccountRecordId = data.financialAccountRecordId;
            
        } else if (error) {
            this.policyPaymentMethodRecordId = null;
            this.financialAccountRecordId = null;
            const errorMessage = 'getPaymentMethodId:' + (error?.body?.message || 'Failed to load coverage');
            console.log('policyMethodAndAccountId:'+ JSON.stringify(errorMessage));
        }
    }
}