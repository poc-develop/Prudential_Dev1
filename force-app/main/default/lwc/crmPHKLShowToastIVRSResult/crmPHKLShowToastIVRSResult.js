import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CrmPHKLShowToastIVRSResult extends LightningElement {
    @api isVisible = false;

    connectedCallback() {
        // 获取URL参数
        const urlParams = new URLSearchParams(window.location.search);
        const authResult = urlParams.get('c__IVRSAuthResult');
        
        if (authResult) {
            this.showToast(authResult.toUpperCase());
        }
    }
    
    showToast(result) {
        let variant, title, message;
        
        switch(result) {
            case 'Y (ID, DOB, PN)':
                variant = 'success';
                title = 'The call is authenticated!(DOB, ID, Phone checked)';
                message = '';
                break;
            case 'P (ID, DOB)':
                variant = 'warning';
                title = 'Partial Authen (ID, DOB checked)';
                message = 'Please verify Full Name, ID and 1 of below info(Corr address, phone no.)';
                break;
            case 'P (DOB, PN)':
                variant = 'warning';
                title = 'Partial Authen (DOB, PN checked)';
                message = 'Please verify Full Name, ID and 1 of below info(Corr address, phone no.)';
                break;
            case 'N':
                variant = 'error';
                title = 'Authentication Failed';
                message = '';
                break;
            case 'C':
                variant = 'warning';
                title = 'Corporate Case, PN & Phone Checked!';
                message = '';
                break;
            case 'AUTHENTICATION TIMEOUT':
                variant = 'warning';
                title = 'The authentication has timeout.';
                message = '';
                break;
            default:
                // 对于未知值不显示提示
                return;
        }
        
        // 显示Toast提示
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'sticky'
        });
        
        this.dispatchEvent(event);
    }
}