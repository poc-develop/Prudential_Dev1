import { LightningElement, api, track,wire } from 'lwc';
import { getAllUtilityInfo, open, closeUtility } from 'lightning/platformUtilityBarApi';
import { subscribe, MessageContext } from 'lightning/messageService';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import {CurrentPageReference} from 'lightning/navigation';
import CaseMessageChannel from "@salesforce/messageChannel/CaseMessageChannel__c";
import getWrapUpCategoryAndItems from '@salesforce/apex/CRMGlobalCaseCreationPageController.getWrapUpCategoryAndItems';
import getEnquiryCase from '@salesforce/apex/CRMGlobalCaseCreationPageController.getEnquiryCase';
import getMasterCaseEnquiries from '@salesforce/apex/CRMGlobalCaseCreationPageController.getMasterCaseEnquiries';
import getAllEnquiries from '@salesforce/apex/CRMGlobalCaseCreationPageController.getAllEnquiries';
import getPolicies from '@salesforce/apex/CRMGlobalCaseCreationPageController.getPolicies';
import saveCaseWrapUp from '@salesforce/apex/CRMGlobalCaseCreationPageController.saveCaseWrapUp';

export default class CrmGlobalWrapUpCreationPage extends NavigationMixin(LightningElement) {
    // @api recordId = '500D300000EuJTPIA3';
    @api recordId;
    @track IDNumber;
    @track accountId;
    @track masterCaseId;
    @track childCases = [];
    @track allPolicies = [];
    @track displayEnquiries = [];
    @track masterCaseEnquiries = [];
    @track allEnquiries = [];
    @track allWrapUpOptions = [];
    @track filteredAvailableOptions = [];
    @track selectedCasesFromMaster = []; // Master Case list seleted
    @track selectedCasesFromAll = []; // All enquiry Case list seleted
    @track selectedPolicyFromCopyToCase = []; // copy to case seleted
    // @track selectedCases = []; // case pill list
    @track selectedEnquiryRows = []; //default seleted cases row
    @track activeButton = 'CurrentMasterCase';// CurrentMasterCase; AllEnquiries
    @track caseOrigin;
    @track followUpSearchTerm = '';
    @track masterCaseStatus;
    @track masterCaseStatusDisabled = false;
    @track selectedAllEnquiryRows = [];
    @track selectedMasterEnquiryRows = [];
    @track selectedPolicyRows = [];
    @track utilityId;
    @track currentCaseId = null;
    @track inquirerIdentity = null;
    @api showSpinner = false;
    @track mandatoryField = ['enquirySummary','channel'];


    @track enquiryColumns = [
        { label: 'Case Number', fieldName: 'caseNumber' },
        { label: 'Case Origin', fieldName: 'caseOrigin' },
        { label: 'Status', fieldName: 'status' },
        { label: 'Case Owner', fieldName: 'caseOwner' },
        { label: 'Created Date Time', fieldName: 'createdDateTime' }
    ];

    @track policyColumns = [
        { label: 'Policy Number', fieldName: 'name' },
        { label: 'Role', fieldName: 'participantRole' },
        { label: 'Client Code', fieldName: 'clientCode' },
        { label: 'Owner Name', fieldName: 'ownerName' },
        { label: 'Owner DOB', fieldName: 'ownerDOB' },
        { label: 'LA Name', fieldName: 'LAName' },
        { label: 'LA DOB', fieldName: 'LADOB' },
        { label: 'Policy Status', fieldName: 'status' },
        { label: 'Product Code', fieldName: 'productCode' }
    ];

    @track enquirerIdentityOptions = [
        { label: 'Policyowner', value: 'Policyowner'},
        { label: 'Beneficiary', value: 'Beneficiary'},
        { label: 'Life Assured', value: 'Life Assured'},
        { label: 'Third Party', value: 'Third Party'}
    ];

    @track reasonOptions = [
        { label: 'Customer Request', value: 'Customer Request' },
        { label: 'System Issue', value: 'System Issue' },
        { label: 'Policy Update Required', value: 'Policy Update Required' },
        { label: 'Document Verification Needed', value: 'Document Verification Needed' },
        { label: 'Compliance Review', value: 'Compliance Review' },
        { label: 'Technical Support Required', value: 'Technical Support Required' }
    ];
    
    @track suggestionOptions = [
        { label: 'Contact Customer Directly', value: 'Contact Customer Directly' },
        { label: 'Schedule Follow-up Call', value: 'Schedule Follow-up Call' },
        { label: 'Send Email Notification', value: 'Send Email Notification' },
        { label: 'Escalate to Supervisor', value: 'Escalate to Supervisor' },
        { label: 'Update Policy Information', value: 'Update Policy Information' },
        { label: 'Generate Report', value: 'Generate Report' }
    ];

    connectedCallback() {
        try {
            console.log('====connectedCallback111===='+this.recordId);
            this.addNewCase()
            this.getUtility();
            this.subscribeToMessageChannel();

        } catch (e) {
            console.log('connectedCallback error'+JSON.stringify(e));
        }
	}
    
    // Switch Enquiry Case
    get button1Variant() {
        return this.activeButton === 'AllEnquiries' ? 'brand' : 'brand-outline';
    }

    get button2Variant() {
        return this.activeButton === 'CurrentMasterCase' ? 'brand' : 'brand-outline';
    }

    get isAllEnquiries() {
        return this.activeButton === 'AllEnquiries';
    }

    get isCurrentMasterCase() {
        return this.activeButton === 'CurrentMasterCase';
    }

    get masterCaseStatusoptions() {
        return [
            { label: 'Active', value: 'Active' },
            { label: 'Pending to Close', value: 'Pending to Close' },
            { label: 'Completed', value: 'Completed' },
        ];
    }

    get deferChatAndEequiry() {
        return this.caseOrigin == 'Defer Chat' || this.caseOrigin == 'E-enquiry';
    }

    get walkIn() {
        return this.caseOrigin == 'Walk-in';
    }

    get letter() {
        return this.caseOrigin == 'Letter';
    }

    get virtualMeeting() {
        return this.caseOrigin == 'Virtual Meeting';
    }

    get selectedCases() {
        return [...this.selectedCasesFromMaster, ...this.selectedCasesFromAll];
    }

    @wire(MessageContext)
    messageContext;

    subscribeToMessageChannel() {
        this.subscription = subscribe(
            this.messageContext,
            CaseMessageChannel,
            (message) => this.copyToCase(message)
        );
    }

    @wire(CurrentPageReference)
    setCurrentPageReference(currentPageReference) {
        if (currentPageReference) {
            const state = currentPageReference.state || {};
            this.recordId = state.c__recordId || null;

            console.log("recordId:"+ this.recordId);

            if(this.recordId) {
                this.getEnquiryCase(this.recordId);
            }
        }
    }

    // get wrap up category and Item
    @wire(getWrapUpCategoryAndItems, {})
    getWrapUpCategoryAndItems({ data, error }){
        console.log("getWrapUpCategoryAndItems===",JSON.stringify(data));
        if(data){
            this.allWrapUpOptions = data.map(option => ({
                label: option,
                value: option
            }));
        } else if (error) {
            this.allWrapUpOptions = [];
            console.log("getWrapUpCategoryAndItems error:"+JSON.stringify(error));
        }
        this.filteredAvailableOptions = this.allWrapUpOptions;
    }

    getEnquiryCase(recordId) {
        getEnquiryCase({ caseId:recordId })
        .then(result => {
            console.log("getEnquiryCase===",JSON.stringify(result));
            if(result){
                this.accountId = result.AccountId ?? null;
                this.IDNumber = result.Account?.CRM_Global_IDNumber__pc ?? null;
                this.masterCaseId = result.ParentId ?? null;
                this.caseOrigin = result.Origin ?? null;

                this.getMasterCaseEnquiries(this.masterCaseId);
                this.getAllEnquiries(this.masterCaseId,this.accountId);
                this.getPolicies(this.accountId);
            }
        }).catch(error => {
            console.log("getAccountDetails error", "错误", '发生错误，请提交以下信息给管理员：'+error);
        })
    }

    // get Account info
    // @wire(getEnquiryCase, { caseId : '$recordId'})
    // getEnquiryCase({ data, error }){
    //     console.log("getEnquiryCase===",JSON.stringify(data));
    //     if(data){
    //         this.accountId = data.AccountId ?? null;
    //         this.IDNumber = data.Account?.CRM_Global_IDNumber__pc ?? null;
    //         this.masterCaseId = data.ParentId ?? null;
    //         this.caseOrigin = data.Origin ?? null;

    //         this.getMasterCaseEnquiries(this.masterCaseId);
    //         this.getAllEnquiries(this.masterCaseId,this.accountId);
    //         this.getPolicies(this.accountId);
    //     } else if (error) {
    //         console.log("getEnquiryCase error:"+JSON.stringify(error));
    //     }
    // }

    addNewCase() {
        const newCase = {
            id: this.generateId(),
            // caseNumber: this.childCases.length + 1,
            policyList: [],
            active: false,
            inquirerIdentity: null,
            nonPolicy: false,
            needFollowUp: false,
            policyMaxRowSelection: '999',
            containerClass: 'pill-container',
            nextFollowUpDate: null,
            wrapUpItems: [],
            wrapUpReasons: [],
            wrapUpSuggestions: [],
            createdAt: new Date()
        };
        this.childCases = [...this.childCases, newCase];
    }
 
    // get current master case Enquiries
    getMasterCaseEnquiries(masterCaseId) {
        getMasterCaseEnquiries({ masterCaseId:masterCaseId })
        .then(result => {
            if(result){
                console.log("getMasterCaseEnquiries:",JSON.stringify(result));
                
                result.forEach((enquiryCase, index) => {

                    const caseItem = {
                        id: enquiryCase.Id,
                        caseNumber: enquiryCase.CRM_Global_EnquiryCaseNumber__c ?? null,
                        caseOrigin: enquiryCase.Origin ?? null,
                        status: enquiryCase.Status ?? null,
                        caseOwner: enquiryCase.Owner?.Name ?? null,
                        createdDateTime: enquiryCase.CreatedDate
                    };
                    console.log("master enquiry caseItem:",JSON.stringify(caseItem));
                    this.masterCaseEnquiries = [...this.masterCaseEnquiries, caseItem];
                });

                // init display Current Master Enquiries
                this.viewCurrentMasterEnquiries();


                // default select current Enquiry case
                // this.selectedMasterEnquiryRows = [...this.selectedMasterEnquiryRows, this.recordId];
                this.selectedMasterEnquiryRows = this.masterCaseEnquiries.filter(c => c.id.substr(0,15)  === this.recordId).map(row => ( row.id ));
                this.selectedCasesFromMaster = this.masterCaseEnquiries.filter(c => c.id.substr(0,15)  === this.recordId).map(row => ({ id: row.id, name: row.caseNumber, isSelected: true }));

            }
        }).catch(error => {
            console.log("getMasterCaseEnquiries error", "错误", '发生错误，请提交以下信息给管理员：'+error);
        })
    }

    // get all Enquiries
    getAllEnquiries(masterCaseId,accountId) {
        getAllEnquiries({ masterCaseId:masterCaseId, accountId:accountId})
        .then(result => {
            if(result){
                console.log("getAllEnquiries:",JSON.stringify(result));
                
                result.forEach((enquiryCase, index) => {

                    const caseItem = {
                        id: enquiryCase.Id,
                        caseNumber: enquiryCase.CRM_Global_EnquiryCaseNumber__c ?? null,
                        caseOrigin: enquiryCase.Origin ?? null,
                        status: enquiryCase.Status ?? null,
                        caseOwner: enquiryCase.Owner?.Name ?? null,
                        createdDateTime: enquiryCase.CreatedDate
                    };
                    // console.log("all caseItem:",JSON.stringify(caseItem));
                    this.allEnquiries = [...this.allEnquiries, caseItem];
                });
            }
        }).catch(error => {
            console.log("getMasterCaseEnquiries error", "错误", '发生错误，请提交以下信息给管理员：'+error);
        })
    }

    getPolicies(accountId) {
        getPolicies({ accountId:accountId })
        .then(result => {
            if(result){
                console.log("getPolicies:",JSON.stringify(result));

                result.forEach((policy, index) => {
                    // contact role
                    // 提取所有role字段
                    const roles = policy.InsurancePolicyParticipants?.map(obj => obj.Role).filter(Role => Role !== undefined && Role !== null);
                    // 去重
                    const uniqueRoles = [...new Set(roles)];
                    // 用逗号拼接
                    const allRole = uniqueRoles.join(', ');

                    const roleLA = policy.InsurancePolicyParticipants?.find(Role => Role.Role === 'L');


                    console.log("roles:",JSON.stringify(roles));
                    console.log("uniqueRoles:",JSON.stringify(uniqueRoles));
                    console.log("allRole:",allRole);
                    console.log("roleLA:",roleLA);

                    const policyItem = {
                        id: policy.Id,
                        name: policy.Name,
                        participantRole: allRole,
                        clientCode: policy.NameInsured.FinServ__CustomerID__c,
                        ownerName: policy.NameInsured.Name,
                        ownerDOB: policy.NameInsured.CRM_PHKL_PersonBirthdateMask__c,
                        LAName: roleLA?.CRM_PHKL_ClientNameMask__c ?? null,
                        LADOB: roleLA?.CRM_PHKL_BirthdateMask__c ?? null,
                        status: policy.Status,
                        productCode: policy.Product?.ProductCode ?? null
                    };
                    // console.log("policyItem:",JSON.stringify(policyItem));
                    this.allPolicies = [...this.allPolicies, policyItem];
                });

            }
        }).catch(error => {
            console.log("getPolicies error", "错误", '发生错误，请提交以下信息给管理员：'+error);
        })
    }

    // get childCases() {
    //     const newCase = {
    //         id: this.generateId(),
    //         // caseNumber: this.childCases.length + 1,
    //         policyList: [],
    //         active: false,
    //         nonPolicy: false,
    //         needFollowUp: false,
    //         policyMaxRowSelection: '999',
    //         containerClass: 'pill-container',
    //         nextFollowUpDate: null,
    //         wrapUpItems: [

    //         ],
    //         wrapUpReasons: [

    //         ],
    //         wrapUpSuggestions: [

    //         ],
    //         createdAt: new Date()
    //     };
    //     return [newCase];
    // }

    viewCurrentMasterEnquiries() {
        this.displayEnquiries = this.masterCaseEnquiries;
        this.activeButton = 'CurrentMasterCase';
    }
    
    viewAllEnquiries() {
        this.displayEnquiries = this.allEnquiries;
        this.activeButton = 'AllEnquiries';
    }

    generateId() {
        return Math.random().toString(36).substr(2, 9);
    }

    handleEnquiryRowSelection(event) {
        console.log("handleEnquiryRowSelection==="+this.activeButton);
        // const caseId = event.currentTarget.dataset.caseId;
        const selectedRows = event.detail.selectedRows || [];
        const selectedRow = event.detail?.config?.value ?? null;
        console.log('selectedRows==='+ JSON.stringify(selectedRows));
        console.log('selecting row==='+ JSON.stringify(event.detail)); // rowSelect; rowDeselect; selectAllRows; deselectAllRows



        // const caseItem = this.childCases.find(c => c.id === caseId);
        // if (!caseItem) {
        //     return;
        // }

        // 同步子Case的policyList
        // this.selectedCases = selectedRows.map(row => ({ id: row.id, name: row.caseNumber, isSelected: true }));

        if(this.activeButton == 'CurrentMasterCase') {
            // default selected case from CurrentMasterCase list
            this.selectedMasterEnquiryRows = selectedRows != [] ? selectedRows.map(row => (row?.id)) : [];
            this.selectedCasesFromMaster = selectedRows.map(row => ({ id: row.id, name: row.caseNumber, isSelected: true }));
        }
        
        if(this.activeButton == 'AllEnquiries') {
            // default selected case from AllEnquiry list
            this.selectedAllEnquiryRows = selectedRows != [] ? selectedRows.map(row => (row?.id)) : [];
            this.selectedCasesFromAll = selectedRows.map(row => ({ id: row.id, name: row.caseNumber, isSelected: true }));
        }

        console.log('selectedCasesFromMaster==='+ JSON.stringify(this.selectedCasesFromMaster));
        console.log('selectedCasesFromAll==='+ JSON.stringify(this.selectedCasesFromAll));
        // this.selectedCases = [...this.selectedCasesFromMaster, ...this.selectedCasesFromAll];

    }

    // delete Policy pill
    handleRemoveCase(event) {
        console.log('remove case:'+ event.detail.name);
        const caseToRemove = event.detail.name;

        console.log('before remove:'+ JSON.stringify(this.selectedCases));
        // this.selectedCases = this.selectedCases.filter(
        //     c => c.id !== caseToRemove
        // );

        this.selectedCasesFromMaster = this.selectedCasesFromMaster.filter(
            c => c.id !== caseToRemove
        );

        this.selectedCasesFromAll = this.selectedCasesFromAll.filter(
            c => c.id !== caseToRemove
        );
        console.log('after remove:'+ JSON.stringify(this.selectedCases));


        // unCheck enquiry case list
        console.log('remove selectedMasterEnquiryRows:'+ JSON.stringify(this.selectedMasterEnquiryRows));
        console.log('remove selectedAllEnquiryRows:'+ JSON.stringify(this.selectedAllEnquiryRows));
        this.selectedMasterEnquiryRows = this.selectedMasterEnquiryRows.filter(
            c => c !== caseToRemove
        );
        this.selectedAllEnquiryRows = this.selectedAllEnquiryRows.filter(
            c => c !== caseToRemove
        );

        console.log('after remove selectedMasterEnquiryRows:'+ JSON.stringify(this.selectedMasterEnquiryRows));
        console.log('after remove selectedAllEnquiryRows:'+ JSON.stringify(this.selectedAllEnquiryRows));
    }

    handleInquirerIdentityChange(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const selectedInquirerIdentity = event.detail.value;
        console.log("Inquirer Identity changed to:", JSON.stringify(selectedInquirerIdentity));
        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === caseId);
        if (childIndex !== -1) {
            this.childCases[childIndex].inquirerIdentity = selectedInquirerIdentity;
        }
    }

    handlePolicyRowSelection(event) {
        console.log("handlePolicyRowSelection===");
        const caseId = event.currentTarget.dataset.caseId;
        const selectedRows = event.detail.selectedRows || [];
        console.log('selectedRows==='+ JSON.stringify(selectedRows));
        console.log('selecting row==='+ event.detail?.config?.value);

        const caseItem = this.childCases.find(c => c.id === caseId);
        if (!caseItem) {
            return;
        }

        caseItem.policyList = selectedRows.map(row => ({ id: row.id, name: row.name, isSelected: true }));
        caseItem.policyList = [...caseItem.policyList, ...this.selectedPolicyFromCopyToCase];

        this.selectedPolicyRows = selectedRows != [] ? selectedRows.map(row => (row?.id)) : [];
    }

    handleRemovePolicy(event) {
        console.log('remove policy:'+ event.detail.name);
        const policyToRemove = event.detail.name;
        const caseItem = this.childCases.find(
            c => c.id === event.currentTarget.dataset.caseId
        );
        console.log('before remove:'+ JSON.stringify(caseItem.policyList));
        caseItem.policyList = caseItem.policyList.filter(
            p => p.id !== policyToRemove
        );
        this.selectedPolicyFromCopyToCase = this.selectedPolicyFromCopyToCase.filter(
            p => p.id !== policyToRemove
        );
        console.log('after remove:'+ JSON.stringify(caseItem.policyList));
        if(this.allPolicies.find(p => p.id === policyToRemove)) this.allPolicies.find(p => p.id === policyToRemove).isSelected = false;
        this.allPolicies = [...this.allPolicies];

        this.selectedPolicyRows = this.selectedPolicyRows.filter(
            p => p !== policyToRemove
        );
    }

    handleNonPolicyChange(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const checked = event.detail.checked;
        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === caseId);
        if (childIndex !== -1) {
            this.childCases[childIndex].nonPolicy = checked;
            if(checked) this.childCases[childIndex].policyMaxRowSelection = '0';
            else this.childCases[childIndex].policyMaxRowSelection = '999';

            // clean selected policy
            this.childCases[childIndex].policyList = [];
            this.childCases = [...this.childCases];
        }
    }

    handleOpenPolicyModal(event) {
        const caseId = event.currentTarget.dataset.caseId;
        this.currentCaseId = caseId;
        this.openUtility();// open "Customer and Policy Search" utility

        this.pillContainerClass();// change pill-container style
    }

    pillContainerClass() {        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === this.currentCaseId);
        if (childIndex !== -1) {
            this.childCases[childIndex].containerClass = 'pill-container container-highlight';
            this.childCases = [...this.childCases];
        }

        const otherCases = this.childCases.findIndex(caseItem => caseItem.id != this.currentCaseId);
        this.childCases.forEach((caseItem, index) => {
            if(caseItem.id != this.currentCaseId){
                caseItem.containerClass = 'pill-container';
                this.childCases = [...this.childCases];
            }
        });
    }

    copyToCase(message) {
        console.log('search message:' + JSON.stringify(message));
        console.log('message.caseData:' + JSON.stringify(message.caseData));

        const caseItem = this.childCases.find(
            c => c.id === this.currentCaseId
        );
        const policy = { 
            id: message.caseData.Id, 
            name: message.caseData.Name, 
            isSelected: true 
        };
        this.selectedPolicyFromCopyToCase.push(policy);
        caseItem.policyList.push(policy);
        caseItem.policyList = [...caseItem.policyList];

    }

    // search wrap up
    handleFollowUpSearch(event) {
        this.followUpSearchTerm = event.target.value.toLowerCase();
        this.filterAvailableOptions();
    }

    filterAvailableOptions() {
        if (!this.followUpSearchTerm) {
            this.filteredAvailableOptions = this.allWrapUpOptions;
        } else {
            this.filteredAvailableOptions = this.allWrapUpOptions.filter(option =>
                option.label.toLowerCase().includes(this.followUpSearchTerm) ||
                option.value.toLowerCase().includes(this.followUpSearchTerm)
            );
        }
        console.log('Filtered options:', this.filteredAvailableOptions);
    }

    // wrap up item change
    handleWrapUphange(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const selectedWrapUp = event.detail.value;
        console.log("Wrap Up changed to:", JSON.stringify(selectedWrapUp));
        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === caseId);
        if (childIndex !== -1) {
            this.childCases[childIndex].wrapUpItems = selectedWrapUp;
        }
    }

    // Reason change
    handleReasonChange(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const selectedReason = event.detail.value;
        console.log("Reason changed to:", JSON.stringify(selectedReason));
        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === caseId);
        if (childIndex !== -1) {
            this.childCases[childIndex].wrapUpReasons = selectedReason;
        }
    }

    // Suggestion change
    handleSuggestionChange(event) {
        this.selectedSuggestion = event.detail.value;
        console.log("Suggestion changed to:", this.selectedSuggestion);
    }

    // enquiry active change
    handleActiveChange(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const checked = event.detail.checked;
        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === caseId);
        if (childIndex !== -1) {
            this.childCases[childIndex].active = checked;
            this.childCases = [...this.childCases];
        }

        // control master case status disabled
        if(checked == true){
            this.masterCaseStatus = 'Active';
            this.masterCaseStatusDisabled = true;
        }else{
            this.masterCaseStatus = null;
            this.masterCaseStatusDisabled = false;
        }
    }

    // next follow up date change
    handleNextFollowUpDateChange(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const followUpDate = event.detail.value;
        console.log('followUpDate1:',event.detail);
        console.log('followUpDate2:',event.detail.value);
        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === caseId);
        if (childIndex !== -1) {
            this.childCases[childIndex].nextFollowUpDate = followUpDate;
            this.childCases = [...this.childCases];
        }
    }

    handleMasterCaseStatusChange(event) {
        this.masterCaseStatus = event.detail.value;
        console.log("handleMasterCaseStatusChange:"+this.masterCaseStatus);
    }

    buildCases() {
        this.caseEntity = {
            id: this.recordId,
            enquirySummary: this.template.querySelector("lightning-input-field[data-id='enquirySummary']")?.value ?? null,
            channel: this.template.querySelector("lightning-input-field[data-id='channel']")?.value ?? null,
            selectedCases: this.selectedCases,
            masterCaseStatus: this.masterCaseStatus,
            createdAt: new Date(),
            childCases: this.childCases
        };
    }

    validation() {
        // if (!this.caseEntity.subject ||) {
        //     this.showToast('Error', 'Subject is required', 'error');
        //     return false;
        // }
        let passValidation = true;
        let blankFields = [];

        // validate mandatory Fields
        this.mandatoryField.forEach(field => {
            console.log("validation "+field+":",this.caseEntity[field]);
            if (this.caseEntity && !this.caseEntity[field]) {
                blankFields.push(field);
                passValidation = false;
            }
        })

        // validate Case mandatory
        if(this.selectedCases.length == 0){
            blankFields.push('Enquiry Case');
            passValidation = false;
        }

        // validate inquirerIdentity mandatory
        const inquirerIdentity_mandatory = this.childCases.filter(caseItem => !caseItem.inquirerIdentity);
        console.log('inquirerIdentity_mandatory:'+JSON.stringify(inquirerIdentity_mandatory));
        if(inquirerIdentity_mandatory.length > 0){
            blankFields.push('inquirer Identity');
            passValidation = false;
        }

        // validate policy mandatory
        const policy_mandatory = this.childCases.filter(caseItem => caseItem.nonPolicy == false && caseItem.policyList.length == 0);
        console.log('policy_mandatory:'+JSON.stringify(policy_mandatory));
        if(policy_mandatory.length > 0){
            blankFields.push('Policy');
            passValidation = false;
        }

        // validate Wrap Up mandatory
        const wrapUp_mandatory = this.childCases.filter(caseItem => caseItem.wrapUpItems.length == 0);
        console.log('wrapUp_mandatory:'+JSON.stringify(wrapUp_mandatory));
        if(wrapUp_mandatory.length > 0){
            blankFields.push('Wrap Up Category and Item');
            passValidation = false;
        }

        if (!passValidation) {
            this.showSpinner = false;
            this.showToast('Error', 'Please fill in the required fields: ' + blankFields.join(', '), 'error');

            // 必填字段报红
            const inputs = [...this.template.querySelectorAll('lightning-input, lightning-input-field, lightning-combobox, lightning-dual-listbox')];
            const isValid = inputs.reduce((valid, input) => {
                if (input.reportValidity) {
                    return input.reportValidity() && valid;
                }
                return valid;
            }, true);
        }
        return passValidation;
    }

    handleSave() {
        this.showSpinner = true;

        this.buildCases();
        console.log('caseEntity====>' , JSON.stringify(this.caseEntity));

        // 验证数据
        const passValidation = this.validation(); 
        console.log("passValidation:"+passValidation);

        // 通过验证
        if(passValidation){
            console.log("pass validation!!!!");

            saveCaseWrapUp({ caseWrapUpEntityString: JSON.stringify(this.caseEntity) })
            .then(result => {
                console.log("save result:",JSON.stringify(result));
                if(result && result.statusCode == '0'){
                    
                    const caseId = result.data?.caseId ?? null;
                    console.log("CaseId:",result.data?.caseId); 

                    this.showToast('Success', 'Case created successfully', 'success');

                    window.location.href = '/' + this.recordId;

                }else{
                    this.showToast('Error', 'Please contact your system admin: '+result?.message, 'error');
                }
            }).catch(error => {
                console.log("save error", "错误", '发生错误，请提交以下信息给管理员：'+JSON.stringify(error));
            })
        }
	}

    handleCancel() {
		this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        },{
            replace: true
        });
	}

    async openUtility() {
        if (this.utilityId) {
            try {
                await open(this.utilityId, { autoFocus: true });
                console.log('Utility 已打开');
            } catch (error) {
                console.error('打开 Utility 失败: ', JSON.stringify(error));
            }
        }
    }

    async getUtility() {
        try {
            const utilityInfo = await getAllUtilityInfo();
            console.error('getAllUtilityInfo:'+JSON.stringify(utilityInfo));
            // 3. search Utility Item
            for (let i = 0; i < utilityInfo.length; i++) {
                if (utilityInfo[i].utilityLabel === 'Customer And Policy Search') {
                    this.utilityId = utilityInfo[i].id;
                    console.log('找到 Utility Item, ID: ', this.utilityId);
                    break;
                }
            }
            if (!this.utilityId) {
                console.error('未找到指定的 Utility Item');
            }
            } catch (error) {
                console.error('获取 Utility 信息失败: ', error);
        }
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }
}