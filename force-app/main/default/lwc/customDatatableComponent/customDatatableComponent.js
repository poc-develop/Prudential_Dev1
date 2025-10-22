import LightningDatatable from 'lightning/datatable';
import customNavigationTemplate from './customNavigationType.html';
// import caseValidationCustomTableTemplate from './caseValidationCustomTableComponent.html';
export default class customDatatableComponent extends LightningDatatable {
    static customTypes = {
        navigation: {
            template: customNavigationTemplate,
            standardCellLayout: true,
            // Provide template data here if needed
            typeAttributes: [
                'type',
                'label',
                'value',
                'allData',
                'rowIndex',
                'navigationName',
                'needDispatchEvent',
                'showIcon',
                'recordId',
                'disableLink',
                'params'
            ]
        } /* ,
        Answer: {
            template: caseValidationCustomTableTemplate,
            standardCellLayout: true,
            typeAttributes: ['columnQuestion', 'id', 'label', 'value', 'navigationName', 'needDispatchEvent']
        } */
        //more custom types here
    };
}