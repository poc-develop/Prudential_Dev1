import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class CustomNavigation extends NavigationMixin(
    LightningElement
) {
    @api type;
    @api label;
    @api value;
    @api navigationName;
    @api needDispatchEvent;
    @api recordId;
    @api params;
    @api showIcon;
    @api allData;
    @api rowIndex;
    @api disableLink;

    param1;
    param2;
    param3;
    param4;
    param5;


    connectedCallback(){
        console.log('icon', this.showIcon);
    }

    navigateHandler() {
        console.log('allData:'+JSON.stringify(this.allData));
        console.log('rowIndex:'+ JSON.stringify(this.rowIndex));
        console.log('[navigateHandler] start');
        console.log('this.type: ' + JSON.stringify(this.type));
        console.log('this.label: ' + JSON.stringify(this.label));
        console.log('this.value: ' + JSON.stringify(this.value));
        console.log('this.recordId: ' + JSON.stringify(this.recordId));
        console.log(
            'this.navigationName: ' + JSON.stringify(this.navigationName)
        );
        console.log('this.params: ' + JSON.stringify(this.params));
        // console.log('this.param2: ' + JSON.stringify(this.param2));
        // console.log('this.param3: ' + JSON.stringify(this.param3));
        // console.log('this.param4: ' + JSON.stringify(this.param4));
        console.log('this.showIcon: ' + JSON.stringify(this.showIcon));
        if(this.params){
            let allParams = this.params.split(';');
            this.param1 = allParams.length>=1?allParams[0] : null;
            this.param2 = allParams.length>=2?allParams[1] : null;
            this.param3 = allParams.length>=3?allParams[2] : null;
            this.param4 = allParams.length>=4?allParams[3] : null;
            this.param5 = allParams.length>=5?allParams[4] : null;
        }
        let detail;
        if(this.allData && this.rowIndex){
            let obj = this.allData.find(ele=>{return ele.rowIndex === this.rowIndex});
            detail = JSON.stringify(obj);
        }
        let urlStr = window.location.href; 
        let isCommunity = urlStr.indexOf("/s/") !== -1;
        console.log(isCommunity+'url-->:'+urlStr);
        if (this.type == 'component') {
            if(isCommunity){
                this[NavigationMixin.Navigate]({
                    type: 'comm__namedPage',
                    attributes: {
                        name: this.navigationName
                    },
                    state: {
                        c__recordId: this.recordId,
                        c__value: this.value,
                        c__label: this.label,
                        c__param1: this.param1,
                        c__param2: this.param2,
                        c__param3: this.param3,
                        c__param4: this.param4,
                        c__param5: this.param5,
                        c__detail: detail
                    }
                });
            }else{
                this[NavigationMixin.Navigate]({
                    type: 'standard__component',
                    attributes: {
                        componentName: this.navigationName
                    },
                    state: {
                        c__recordId: this.recordId,
                        c__value: this.value,
                        c__label: this.label,
                        c__param1: this.param1,
                        c__param2: this.param2,
                        c__param3: this.param3,
                        c__param4: this.param4,
                        c__param5: this.param5,
                        c__detail: detail
                    }
                });
            }
            if (this.needDispatchEvent) {
                this.dispatchEvent(
                    new CustomEvent('navigate', {
                        bubbles: true,
                        composed: true
                    })
                );
            }
        } else if (this.type == 'recordPage') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.value,
                    actionName: 'view'
                }
            });
            if (this.needDispatchEvent) {
                this.dispatchEvent(
                    new CustomEvent('navigate', {
                        bubbles: true,
                        composed: true
                    })
                );
            }
        }
        console.log('[navigateHandler] end');
    }
}