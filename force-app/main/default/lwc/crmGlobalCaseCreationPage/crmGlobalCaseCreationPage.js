import { LightningElement, api, track,wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {CurrentPageReference} from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, MessageContext } from 'lightning/messageService';
import CaseMessageChannel from "@salesforce/messageChannel/CaseMessageChannel__c";
import { getAllUtilityInfo, open, closeUtility } from 'lightning/platformUtilityBarApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import CASE_OBJECT from '@salesforce/schema/Case';
import ORIGIN_FIELD from '@salesforce/schema/Case.Origin';
import getAccountDetails from '@salesforce/apex/CRMGlobalCaseCreationPageController.getAccountDetails';
import getPolicies from '@salesforce/apex/CRMGlobalCaseCreationPageController.getPolicies';
import getWrapUpCategoryAndItems from '@salesforce/apex/CRMGlobalCaseCreationPageController.getWrapUpCategoryAndItems';
import save from '@salesforce/apex/CRMGlobalCaseCreationPageController.save';


export default class crmGlobalCaseCreationPage extends NavigationMixin(LightningElement) {
    @api recordId;
	@api recordTypeId;
	@api accountId;
	@api action;
	@track firstContactResolution = true;
	@api defaultValuesJson; // Flow 可选：JSON字符串，设置默认值
	@track defaultValues = {};
	@api createdRecordId; // Flow 输出：创建成功后的 Case Id

    @track masterCase = {};
    @track caseEntity = {};
    @track childCases = [];
    @track isModalOpen = false;
    @track isCaseOriginModalOpen = true;
    @track searchResults = [];
    @track selectedPolicies = [];
    @track currentCaseId = null;
    @track wrapUpCategoryOptions = [];
    @track allPolicies = [];
    @track wrapUpItemOptions = [];
    @track utilityId;
    @track caseOrigin;
    @track caseOriginOptions = [];
    @track mandatoryField = ['subject','enquirerName','enquirySummary'];
    @track accountDetails = {};

    // @wire(getRecord, { recordId: "$accountId", fields: ACCOUNT_FIELDS })
    // account;

    // @wire(getRecord, {
    //     recordId: "$accountId",
    //     fields: [ORIGIN_FIELD, ACCOUNT_NAME_FIELD, ID_NUMBER_FIELD]
    // })
    // account;

    // get enquirerName () {
    //     return getFieldValue(this.account.data, ACCOUNT_NAME_FIELD);
    // }

    // get IDNumber() {
    //     return getFieldValue(this.account.data, ID_NUMBER_FIELD);
    // }

    // @track caseOriginOptions = [
    //     { label: 'Letter', value: 'Letter', isSelected: false},
    //     { label: 'Walk-in', value: 'Walk-in', isSelected: false},
    //     { label: 'Defer Chat', value: 'Defer Chat', isSelected: false},
    //     { label: 'Email', value: 'Email', isSelected: false},
    //     { label: 'Call', value: 'Call', isSelected: true},
    //     { label: 'E-enquiry', value: 'E-enquiry', isSelected: false},
    //     { label: 'Virtual Meeting', value: 'Virtual Meeting', isSelected: false}
    // ];
    
    @track enquirerIdentityOptions = [
        { label: 'Policyowner', value: 'Policyowner'},
        { label: 'Beneficiary', value: 'Beneficiary'},
        { label: 'Life Assured', value: 'Life Assured'},
        { label: 'Third Party', value: 'Third Party'}
    ];
    
    @track selectedEnquirerIdentity = 'Policyowner';
    
    // Follow Up Dual Listbox 数据
    // @track followUpOptions = [
    //     { label: 'Customer Service Follow-up - Policy Information Request', value: 'Customer Service Follow-up - Policy Information Request' },
    //     { label: 'Technical Support Follow-up - System Issue Resolution', value: 'Technical Support Follow-up - System Issue Resolution' },
    //     { label: 'Claims Processing Follow-up - Document Verification Required', value: 'Claims Processing Follow-up - Document Verification Required' },
    //     { label: 'Underwriting Follow-up - Additional Information Needed for Policy Assessment', value: 'Underwriting Follow-up - Additional Information Needed for Policy Assessment' },
    //     { label: 'Compliance Follow-up - Regulatory Requirements Review', value: 'Compliance Follow-up - Regulatory Requirements Review' },
    //     { label: 'Customer Satisfaction Follow-up - Service Quality Assessment', value: 'Customer Satisfaction Follow-up - Service Quality Assessment' }
    // ];
    
    @track selectedFollowUpOptions = [];
    // @track availableFollowUpOptions = [
    //     { label: 'Customer Service Follow-up - Policy Information Request', value: 'Customer Service Follow-up - Policy Information Request' },
    //     { label: 'Technical Support Follow-up - System Issue Resolution', value: 'Technical Support Follow-up - System Issue Resolution' },
    //     { label: 'Claims Processing Follow-up - Document Verification Required', value: 'Claims Processing Follow-up - Document Verification Required' },
    //     { label: 'Underwriting Follow-up - Additional Information Needed for Policy Assessment', value: 'Underwriting Follow-up - Additional Information Needed for Policy Assessment' },
    //     { label: 'Compliance Follow-up - Regulatory Requirements Review', value: 'Compliance Follow-up - Regulatory Requirements Review' },
    //     { label: 'Customer Satisfaction Follow-up - Service Quality Assessment', value: 'Customer Satisfaction Follow-up - Service Quality Assessment' }
    // ];

    @track availableFollowUpOptions = [
        { label: 'UI Enquiry > UI Procedure', value: 'UI Enquiry > UI Procedure' },
        { label: 'UI Enquiry > UI Status', value: 'UI Enquiry > UI Status' },
        { label: 'PA Enquiry > PA Procedure', value: 'PA Enquiry > PA Procedure' },
        { label: 'PA Enquiry > PA Status', value: 'PA Enquiry > PA Status' },
        { label: 'PA Enquiry > Termination', value: 'PA Enquiry > Termination' },
        { label: 'Claims Enquiry > CL Procedure', value: 'Claims Enquiry > CL Procedure' },
        { label: 'Claims Enquiry > CL status', value: 'Claims Enquiry > CL status' },
        { label: 'Policy Enquiry > Policy Status, premium amount and PTD', value: 'Policy Enquiry > Policy Status, premium amount and PTD' },
        { label: 'Policy Enquiry > Plan Coverage & Sum Assured', value: 'Policy Enquiry > Plan Coverage & Sum Assured' },
        { label: 'Policy Enquiry > Policy Value & Surrender Value', value: 'Policy Enquiry > Policy Value & Surrender Value' },
        { label: 'Policy Enquiry > Lumpsum Top-up', value: 'Policy Enquiry > Lumpsum Top-up' },
        { label: 'Policy Enquiry > APL & Loan', value: 'Policy Enquiry > APL & Loan' },
        { label: 'Policy Enquiry > PDA/Suspense', value: 'Policy Enquiry > PDA/Suspense' },
        { label: 'Policy Enquiry > Bonus Enquiry', value: 'Policy Enquiry > Bonus Enquiry' },
        { label: 'Policy Enquiry > Fund Enquiry', value: 'Policy Enquiry > Fund Enquiry' },
        { label: 'PX & Cashiering > DDA set up & status', value: 'PX & Cashiering > DDA set up & status' },
        { label: 'PX & Cashiering > Payment method', value: 'PX & Cashiering > Payment method' },
        { label: 'PX & Cashiering > Payment status & Receipt', value: 'PX & Cashiering > Payment status & Receipt' },
        { label: 'PX & Cashiering > Overpayment & Refund', value: 'PX & Cashiering > Overpayment & Refund' },
        { label: 'PX & Cashiering > Floating Rate', value: 'PX & Cashiering > Floating Rate' },
        { label: 'REQ Documents > REQ AVY statement', value: 'REQ Documents > REQ AVY statement' },
        { label: 'REQ Documents > REQ Premium Notices & Receipts', value: 'REQ Documents > REQ Premium Notices & Receipts' },
        { label: 'REQ Documents > REQ Tax Letter', value: 'REQ Documents > REQ Tax Letter' },
        { label: 'REQ Documents > REQ Policy Change Confirmation', value: 'REQ Documents > REQ Policy Change Confirmation' },
        { label: 'REQ Documents > REQ Claims Confirmation', value: 'REQ Documents > REQ Claims Confirmation' },
        { label: 'REQ Documents > REQ Other documents', value: 'REQ Documents > REQ Other documents' },
        { label: 'myPrudential > Registration & login issue', value: 'myPrudential > Registration & login issue' },
        { label: 'myPrudential > App Performance', value: 'myPrudential > App Performance' },
        { label: 'myPrudential - DIY > Change Of Contact Details', value: 'myPrudential - DIY > Change Of Contact Details' },
        { label: 'myPrudential - DIY > Fund Switching', value: 'myPrudential - DIY > Fund Switching' },
        { label: 'myPrudential - DIY > Change Payment Mode & Frequency', value: 'myPrudential - DIY > Change Payment Mode & Frequency' },
        { label: 'myPrudential - DIY > Beneficiary Appointment', value: 'myPrudential - DIY > Beneficiary Appointment' },
        { label: 'myPrudential - DIY > Autopay Setup', value: 'myPrudential - DIY > Autopay Setup' },
        { label: 'myPrudential - DIY > Loan', value: 'myPrudential - DIY > Loan' },
        { label: 'myPrudential - DIY > PDA withdrawal', value: 'myPrudential - DIY > PDA withdrawal' },
        { label: 'myPrudential - DIY > Change BPO', value: 'myPrudential - DIY > Change BPO' },
        { label: 'myPrudential - DIY > Change of Dividend Payout Option', value: 'myPrudential - DIY > Change of Dividend Payout Option' },
        { label: 'myPrudential - DIY > Dividend Withdrawal', value: 'myPrudential - DIY > Dividend Withdrawal' },
        { label: 'myPrudential - DIY > Change of Fund Allocation', value: 'myPrudential - DIY > Change of Fund Allocation' },
        { label: 'myPrudential - DIY > Yearly cash back', value: 'myPrudential - DIY > Yearly cash back' },
        { label: 'myPrudential - DIY > Change of Dividend Allocation', value: 'myPrudential - DIY > Change of Dividend Allocation' },
        { label: 'myPrudential - DIY > Update Simplified Chinese Name', value: 'myPrudential - DIY > Update Simplified Chinese Name' },
        { label: 'Others > Look for CS Staff', value: 'Others > Look for CS Staff' },
        { label: 'Others > Pru mailing address & email address', value: 'Others > Pru mailing address & email address' },
        { label: 'Others > CSC Info', value: 'Others > CSC Info' },
        { label: 'Others > GI, EB and MPF', value: 'Others > GI, EB and MPF' },
        { label: 'Administrative > Document Exp', value: 'Administrative > Document Exp' },
        { label: 'Administrative > Confirm Receipt of Document', value: 'Administrative > Confirm Receipt of Document' },
        { label: 'Opt in > Opt In', value: 'Opt in > Opt In' },
        { label: 'Opt in > Opt Out', value: 'Opt in > Opt Out' },
        { label: 'Incident > (eg: autopay collection)', value: 'Incident > (eg: autopay collection)' }
    ];

    
    // 搜索相关属性
    @track followUpSearchTerm = '';
    @track filteredAvailableOptions = [];
    
    // Reason 和 Suggestion 相关属性
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
    
    // 新增：Policy DataTable 列定义
    policyColumns = [
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

    get defaultOpenSections(){
        return ['Case Details','Enquiry Details'];
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

	connectedCallback() {
        try {
            this.subscribeToMessageChannel();
            // this.defaultValues = JSON.parse(this.defaultValuesJson);
            this.initializeData();
            this.addNewCase();
            // 获取Utility
            this.getUtility();

            // 设置CSS变量，确保不遮挡Utility Bar
		    // this.setUtilityBarCssVar();
            
            // 初始化 Follow Up 选项
            // this.initializeFollowUpOptions();
        } catch (e) {
            // ignore parse error
        }
	}

    // 获取URL参数
    @wire(CurrentPageReference)
    setCurrentPageReference(currentPageReference) {
        if (currentPageReference) {
            const state = currentPageReference.state || {};
            this.recordId = state.c__Id || null;
            this.accountId = state.c__AccountId || null;
            this.action = state.c__action || null;

            console.log("c__Id:"+ (state.c__Id || null));
            console.log("c__action:"+ (state.c__action || null));
            console.log("c__AccountId:"+ (state.c__AccountId || null));

            if(this.accountId) {
                this.getAccountDetails(this.accountId);
                this.getPolicies(this.accountId);
            }

            this.isCaseOriginModalOpen = this.action == 'InboundCall' ? false : true;
            this.caseOrigin = this.action == 'InboundCall' ? 'Call' : null;
        }
    }
    
    // 获取Enquiry recordTypeId
    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    objectInfo({error, data}) {
        if(data) {
            const recordTypes = data.recordTypeInfos;
            console.log("getObjectInfo===",JSON.stringify(recordTypes));
            this.recordTypeId = Object.keys(recordTypes).find(
                (recordTypeId) => recordTypes[recordTypeId].name === 'Enquiry'
            );
        } else if (error) {
            console.log('find Case object info error.', JSON.stringify(error));
        }
    }


    // 获取Origin picklist值
    @wire(getPicklistValues, {
        recordTypeId: '$recordTypeId',
        fieldApiName: ORIGIN_FIELD
    })
    getCaseOriginOptions({ error, data }) {
        console.log("getCaseOriginOptions===",JSON.stringify(data));
        if (data) {
            this.caseOriginOptions = data.values.map(option => ({
                label: option.label,
                value: option.value
            }));
        } else if (error) {
            this.caseOriginOptions = [];
            console.log(error);
        }
    }

    // 获取wrap up category和Item
    @wire(getWrapUpCategoryAndItems, {})
    getWrapUpCategoryAndItems({ data, error }){
        console.log("getWrapUpCategoryAndItems===",JSON.stringify(data));
        if(data){
            this.filteredAvailableOptions = data.map(option => ({
                label: option,
                value: option
            }));
        } else if (error) {
            this.filteredAvailableOptions = [];
            console.log("getWrapUpCategoryAndItems error:"+JSON.stringify(error));
        }
    }

    
    getAccountDetails(accountId) {
        getAccountDetails({ accountId:accountId })
        .then(result => {
            if(result){
                console.log("getAccountDetails:",JSON.stringify(result));
                console.log("Account Name:",result.Name); 

                this.accountDetails = result;
            }
        }).catch(error => {
            console.log("getAccountDetails error", "错误", '发生错误，请提交以下信息给管理员：'+error);
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
                    console.log("policyItem:",JSON.stringify(policyItem));
                    this.allPolicies = [...this.allPolicies, policyItem];
                });

            }
        }).catch(error => {
            console.log("getPolicies error", "错误", '发生错误，请提交以下信息给管理员：'+error);
        })
    }

    get enquirerName () {
        return this.accountDetails?.Name ?? null;
    }

    get IDNumber() {
        return this.accountDetails?.CRM_Global_IDNumber__pc ?? null;
    }

    get clientCode() {
        return this.accountDetails?.FinServ__CustomerID__c ?? null;
    }

    get contactEmail() {
        return this.accountDetails?.PersonEmail ?? null;
    }

    get contactNumber() {
        return this.accountDetails?.PersonMobilePhone ?? null;
    }

    get Subject() {
        return this.caseOrigin + " from " + this.enquirerName;
    }

    get isCaseDetail() {
        return this.action == 'CaseDetail'? true : false;
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

    get PersonContactId() {
        return this.accountDetails?.PersonContactId ?? null;
    }

    // get isCaseOriginModalOpen() {
    //     return this.action == 'InboundCall' ? false : true;
    // }

    // get caseOrigin() {
    //     return this.action == 'InboundCall' ? 'Call' : null;
    // }


    handleRadioChange(event) {
        this.caseOrigin = event.detail.value || event.target.value;
        console.log("Case Origin changed to:", this.caseOrigin);
        
        // 更新所有选项的选中状态
        this.caseOriginOptions.forEach(option => {
            option.isSelected = option.value === this.caseOrigin;
        });
        
        // 触发重新渲染
        this.caseOriginOptions = [...this.caseOriginOptions];
    }

    handleEnquirerIdentityChange(event) {
        this.selectedEnquirerIdentity = event.detail.value;
        console.log("Enquirer Identity changed to:", this.selectedEnquirerIdentity);
    }

    // 处理 Wrap Up 变化
    handleWrapUphange(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const selectedWrapUp = event.detail.value;
        console.log("Wrap Up changed to:", JSON.stringify(selectedWrapUp));
        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === caseId);
        if (childIndex !== -1) {
            this.childCases[childIndex].wrapUpItems = selectedWrapUp;
        }
    }
    
    // 处理 Reason 变化
    handleReasonChange(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const selectedReason = event.detail.value;
        console.log("Reason changed to:", JSON.stringify(selectedReason));
        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === caseId);
        if (childIndex !== -1) {
            this.childCases[childIndex].wrapUpReasons = selectedReason;
        }
    }

    // 处理 Suggestion 变化
    handleSuggestionChange(event) {
        this.selectedSuggestion = event.detail.value;
        console.log("Suggestion changed to:", this.selectedSuggestion);
    }

    // 初始化 Follow Up 选项
    initializeFollowUpOptions() {
        console.log('initializeFollowUpOptions===');
        // this.availableFollowUpOptions = [...this.followUpOptions];
        this.selectedFollowUpOptions = [];
        this.filteredAvailableOptions = [...this.availableFollowUpOptions];
    }

    // 搜索 Follow Up 选项
    handleFollowUpSearch(event) {
        this.followUpSearchTerm = event.target.value.toLowerCase();
        this.filterAvailableOptions();
    }

    // 筛选可用选项
    filterAvailableOptions() {
        if (!this.followUpSearchTerm) {
            this.filteredAvailableOptions = [...this.availableFollowUpOptions];
        } else {
            this.filteredAvailableOptions = this.availableFollowUpOptions.filter(option =>
                option.label.toLowerCase().includes(this.followUpSearchTerm) ||
                option.value.toLowerCase().includes(this.followUpSearchTerm)
            );
        }
        console.log('Filtered options:', this.filteredAvailableOptions);
    }

    // 移动选项到已选择列表
    moveToSelected() {
        console.log("moveToSelected called");
        console.log("Available options:", this.availableFollowUpOptions);
        console.log("Selected options:", this.selectedFollowUpOptions);
        
        // 获取所有选中的可用选项
        const availableSection = this.template.querySelector('.listbox-section:first-child');
        if (!availableSection) {
            console.log("Available section not found");
            return;
        }
        
        const checkboxes = availableSection.querySelectorAll('.follow-up-checkbox input[type="checkbox"]:checked');
        console.log("Found checkboxes:", checkboxes.length);
        
        const selectedValues = Array.from(checkboxes).map(cb => {
            console.log("Checkbox value:", cb.value, "checked:", cb.checked);
            return cb.value;
        });
        
        console.log("Selected values:", selectedValues);
        
        if (selectedValues.length === 0) {
            console.log("No items selected to move");
            return;
        }
        
        const selectedItems = this.availableFollowUpOptions.filter(option => 
            selectedValues.includes(option.value)
        );
        
        console.log("Items to move:", selectedItems);
        
        this.selectedFollowUpOptions = [...this.selectedFollowUpOptions, ...selectedItems];
        this.availableFollowUpOptions = this.availableFollowUpOptions.filter(option => 
            !selectedValues.includes(option.value)
        );
        
        // 更新筛选后的选项
        this.filterAvailableOptions();
        
        console.log("After move - Available:", this.availableFollowUpOptions);
        console.log("After move - Selected:", this.selectedFollowUpOptions);
    }

    // 移动选项到可用列表
    moveToAvailable() {
        // 获取所有选中的已选择选项
        const selectedSection = this.template.querySelector('.listbox-section:last-child');
        if (!selectedSection) return;
        
        const checkboxes = selectedSection.querySelectorAll('.follow-up-checkbox input[type="checkbox"]:checked');
        const selectedValues = Array.from(checkboxes).map(cb => cb.value);
        
        if (selectedValues.length === 0) {
            console.log("No items selected to move back");
            return;
        }
        
        const selectedItems = this.selectedFollowUpOptions.filter(option => 
            selectedValues.includes(option.value)
        );
        
        this.availableFollowUpOptions = [...this.availableFollowUpOptions, ...selectedItems];
        this.selectedFollowUpOptions = this.selectedFollowUpOptions.filter(option => 
            !selectedValues.includes(option.value)
        );
        
        console.log("Moved to available:", selectedItems);
    }

    initializeData() {
        // 初始化Wrap-up Category选项
        this.wrapUpCategoryOptions = [
            { label: 'GDPR', value: 'GDPR' },
            { label: 'PIPL', value: 'PIPL' },
            { label: 'CCPA', value: 'CCPA' },
            { label: 'LGPD', value: 'LGPD' }
        ];

        // 初始化Wrap-up Item选项
        this.wrapUpItemOptions = [
            { label: 'SUC-CFI', value: 'SUC-CFI' },
            { label: 'SUC-DPI', value: 'SUC-DPI' },
            { label: 'SUC-RTI', value: 'SUC-RTI' },
            { label: 'SUC-ATI', value: 'SUC-ATI' }
        ];

        // this.allPolicies = [
        //     { id: 'pol-001', name: 'PL-001-SBC', Status: 'Draft', PolicyType: 'Home', isSelected: false },
        //     { id: 'pol-002', name: 'PL-001-SLO', Status: 'Applied', PolicyType: 'Life', isSelected: false },
        //     { id: 'pol-003', name: 'PL-002-SBC', Status: 'Final', PolicyType: 'Home', isSelected: false },
        //     { id: 'pol-004', name: 'PL-002-SLO', Status: 'Draft', PolicyType: 'Life', isSelected: false },
        //     { id: 'pol-005', name: 'PL-003-SBC', Status: 'Terminated', PolicyType: 'Annuity', isSelected: false },
        //     { id: 'pol-006', name: 'PL-003-SLO', Status: 'Applied', PolicyType: 'Home', isSelected: false },
        //     { id: 'pol-007', name: 'PL-004-SBC', Status: 'Applied', PolicyType: 'Home', isSelected: false },
        //     { id: 'pol-008', name: 'PL-004-SLO', Status: 'Final', PolicyType: 'Home', isSelected: false },
        //     { id: 'pol-009', name: 'PL-005-SBC', Status: 'Draft', PolicyType: 'Life', isSelected: false },
        //     { id: 'pol-010', name: 'PL-005-SLO', Status: 'Final', PolicyType: 'Life', isSelected: false },
        //     { id: 'pol-011', name: 'PL-006-SLO', Status: 'Final', PolicyType: 'Life', isSelected: false },
        //     { id: 'pol-012', name: 'PL-007-SLO', Status: 'Final', PolicyType: 'Life', isSelected: false },
        //     { id: 'pol-013', name: 'PL-008-SLO', Status: 'Final', PolicyType: 'Life', isSelected: false },
        //     { id: 'pol-014', name: 'PL-009-SLO', Status: 'Final', PolicyType: 'Life', isSelected: false },
        //     { id: 'pol-015', name: 'PL-010-SLO', Status: 'Final', PolicyType: 'Life', isSelected: false },
        //     { id: 'pol-016', name: 'PL-011-SLO', Status: 'Final', PolicyType: 'Life', isSelected: false },
        //     { id: 'pol-017', name: 'PL-012-SLO', Status: 'Final', PolicyType: 'Life', isSelected: false },
        //     { id: 'pol-018', name: 'PL-013-SLO', Status: 'Final', PolicyType: 'Life', isSelected: false },
        //     { id: 'pol-019', name: 'PL-014-SLO', Status: 'Final', PolicyType: 'Life', isSelected: false },
        // ];
    }

    addNewCase() {
        const newCase = {
            id: this.generateId(),
            caseNumber: this.childCases.length + 1,
            policyList: [],
            active: false,
            nonPolicy: false,
            needFollowUp: false,
            policyMaxRowSelection: '999',
            containerClass: 'pill-container',
            nextFollowUpDate: null,
            wrapUpItems: [

            ],
            wrapUpReasons: [

            ],
            wrapUpSuggestions: [

            ],
            createdAt: new Date()
        };
        this.childCases = [...this.childCases, newCase];
    }

    handleNewChildCase() {
        this.addNewCase();
        this.showToast('Success', 'New case added successfully', 'success');
    }

    handleDeleteCase(event) {
        const caseId = event.currentTarget.dataset.caseId;
        this.childCases = this.childCases.filter(caseItem => caseItem.id !== caseId);
        
        // 重新编号cases
        this.childCases.forEach((caseItem, index) => {
            caseItem.caseNumber = index + 1;
        });
        
        this.showToast('Success', 'Case deleted successfully', 'success');
    }

    handleFollowUpChange(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const checked = event.detail.checked;
        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === caseId);
        if (childIndex !== -1) {
            this.childCases[childIndex].needFollowUp = checked;
            this.childCases = [...this.childCases];
        }
    }

    handleActiveChange(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const checked = event.detail.checked;
        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === caseId);
        if (childIndex !== -1) {
            this.childCases[childIndex].active = checked;
            this.childCases = [...this.childCases];
        }
        this.firstContactResolution = !checked;
    }

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

    handleNonPolicyChange(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const checked = event.detail.checked;
        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === caseId);
        if (childIndex !== -1) {
            this.childCases[childIndex].nonPolicy = checked;
            if(checked) this.childCases[childIndex].policyMaxRowSelection = '0';
            else this.childCases[childIndex].policyMaxRowSelection = '999';

            // 清空selected policy
            this.childCases[childIndex].policyList = [];
            this.childCases = [...this.childCases];
        }
    }

    handleAddWrapUp(event) {
        const caseId = event.currentTarget.dataset.caseId;
        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === caseId);
        if (childIndex !== -1) {
            const newWrapUpItem = {
                id: this.generateId(),
                serialNumber: this.childCases[childIndex].wrapUpItems.length + 1,
                wrapUpCategory: '',
                wrapUpItem: '',
                wrapUp: ''
            };
            
            this.childCases[childIndex].wrapUpItems.push(newWrapUpItem);
            this.childCases = [...this.childCases];
        }
    }

    handleRemoveWrapUp(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const wrapUpIndex = parseInt(event.currentTarget.dataset.wrapUpIndex);
        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === caseId);
        if (childIndex !== -1) {
            this.childCases[childIndex].wrapUpItems.splice(wrapUpIndex, 1);
            // 重新编号
            this.childCases[childIndex].wrapUpItems.forEach((row, i) => {
                row.serialNumber = i + 1;
            });
            this.childCases = [...this.childCases];
        }
    }

    handleWrapUpCategoryChange(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const wrapUpIndex = parseInt(event.currentTarget.dataset.wrapUpIndex);
        const category = event.detail.value;
        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === caseId);
        if (childIndex !== -1) {
            this.childCases[childIndex].wrapUpItems[wrapUpIndex].wrapUpCategory = category;
            this.childCases = [...this.childCases];
        }
    }

    handleWrapUpItemChange(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const wrapUpIndex = parseInt(event.currentTarget.dataset.wrapUpIndex);
        const item = event.detail.value;
        
        const childIndex = this.childCases.findIndex(caseItem => caseItem.id === caseId);
        if (childIndex !== -1) {
            this.childCases[childIndex].wrapUpItems[wrapUpIndex].wrapUpItem = item;
            this.childCases = [...this.childCases];
        }
    }

    // 处理Wrap Up变化
	handleWrapUpChange(event) {
		const childIndex = parseInt(event.currentTarget.dataset['child-index']);
		const rowIndex = parseInt(event.currentTarget.dataset['row-index']);
		const childCase = this.childCases[childIndex];
		childCase.wrapUpRows[rowIndex].wrapUp = event.detail.value;
		this.childCases = [...this.childCases];
	}

    generateId() {
        return Math.random().toString(36).substr(2, 9);
    }

    // 打开弹窗时初始化数据
    handleOpenPolicyModal(event) {
        const caseId = event.currentTarget.dataset.caseId;
        this.currentCaseId = caseId;
        // this.isModalOpen = true;
        // 初始化搜索结果
        this.searchResults = this.getPolicyOptions(); // 获取初始选项
        this.openUtility();// open "Customer and Policy Search" utility

        this.pillContainerClass();// 点击改变pill-container样式
    }

    // 改变当前点击的pill container样式
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

    // 根据当前子case计算pill box样式
    computePillBoxClass(caseId) {
        const isActive = this.currentCaseId === caseId;
        return `pill-box ${isActive ? 'pill-box-active' : ''}`;
    }

    getPolicyOptions() {
        return this.allPolicies.filter(policy => policy.isSelected);
    }

    // 搜索Policy
    handlePolicySearch(event) {
        const searchTerm = event.target.value.toLowerCase();
        this.searchResults = this.allPolicies.filter(policy => 
            policy.name.toLowerCase().includes(searchTerm)
        );
    }

    // 选择Policy
    handlePolicySelect(event) {
        const selectedPolicy = event.target.name;
        const isChecked = event.target.checked;
        const policy = this.allPolicies.find(p => p.id === selectedPolicy);
        policy.isSelected = isChecked;
        this.allPolicies = [...this.allPolicies];

        if (isChecked) {
            this.selectedPolicies.push(policy);
        } else {
            this.selectedPolicies = this.selectedPolicies.filter(
                p => p.id !== selectedPolicy
            );
        }
    }

    // 确认选择
    handleConfirmPolicy() {
        const caseItem = this.childCases.find(
            c => c.id === this.currentCaseId
        );
        caseItem.policyList = [...this.selectedPolicies];
        this.isModalOpen = false;
    }

    // Case Origin Next
    handleCaseOriginNext() {
        if(!this.caseOrigin){
            this.showToast('error', 'Please select a case origin.', 'Error');
            return;
        }
        this.isCaseOriginModalOpen = false;
    }

    // 新增：Policy DataTable 多选处理
    handlePolicyRowSelection(event) {
        console.log("handlePolicyRowSelection===");
        const caseId = event.currentTarget.dataset.caseId;
        const selectedRows = event.detail.selectedRows || [];
        console.log('selectedRows==='+ JSON.stringify(selectedRows));

        const caseItem = this.childCases.find(c => c.id === caseId);
        if (!caseItem) {
            return;
        }

        // 同步子Case的policyList
        caseItem.policyList = selectedRows.map(row => ({ id: row.id, name: row.name, isSelected: true }));
        // caseItem.policyIdList = selectedRows.map(row => ( row.id ));
        
        // const selectedPolicies = selectedRows.map(row => ( row.id ));
        // caseItem.policyList = [...caseItem.policyList, ...selectedPolicies];
        // console.log('selectedPolicies:'+ JSON.stringify(selectedPolicies));

        // for (const row of selectedPolicies) {
        //     // 检查array1中是否已存在相同name的对象
        //     const exists = caseItem.policyList.some(obj => obj.name === row.name);
            
        //     // 如果不存在，则添加到合并后的数组
        //     if (!exists) {
        //         caseItem.policyList.push(row);
        //     }
        // }


        // 同步全局 allPolicies 的 isSelected 标记（仅用于搜索与UI一致）
        const selectedIdSet = new Set(selectedRows.map(r => r.id));
        this.allPolicies.forEach(p => { p.isSelected = selectedIdSet.has(p.id); });

        // 触发界面刷新
        this.childCases = [...this.childCases];
        this.allPolicies = [...this.allPolicies];
    }

    // 删除单个Policy
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
        console.log('after remove:'+ JSON.stringify(caseItem.policyList));
        if(this.allPolicies.find(p => p.id === policyToRemove)) this.allPolicies.find(p => p.id === policyToRemove).isSelected = false;
        this.allPolicies = [...this.allPolicies];
    }

    // 关闭模态框
    handleCloseModal() {
        this.isModalOpen = false;
        // 可选：重置搜索和选择状态
        // this.searchResults = [...this.allPolicies];
        // this.selectedPolicies = [];

        console.log('handleCloseModal:'+this.action);
        // 导航到Case listview页面
        if(this.action && this.action == 'CaseListview'){
            // 导航到新创建的Case记录页面
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Case',
                    actionName: 'list'
                },
                state: {       
                    filterName: 'Recent' 
                }
            });
            return;
        }

        history.back();
    }

	handleSubmit(event) {
		event.preventDefault();
		const fields = event.detail.fields;
		
		// 设置默认值
		if (this.recordTypeId) {
			fields.RecordTypeId = this.recordTypeId;
		}
		
		Object.keys(this.defaultValues || {}).forEach(key => {
			fields[key] = this.defaultValues[key];
		});

		// 设置默认的Case Owner为当前用户
		if (!fields.OwnerId) {
			fields.OwnerId = this.defaultValues.OwnerId || null;
		}

		this.template.querySelector('lightning-record-edit-form').submit(fields);
	}

	handleSuccess(event) {
		const recordId = event.detail.id;
		this.createdRecordId = recordId;
		
		this.dispatchEvent(
			new ShowToastEvent({
				title: 'Success',
				message: 'Case created successfully',
				variant: 'success'
			})
		);

		// 导航到新创建的Case记录页面
		this[NavigationMixin.Navigate]({
			type: 'standard__recordPage',
			attributes: {
				recordId: recordId,
				objectApiName: 'Case',
				actionName: 'view'
			}
		});
	}

    buildCases() {
        this.caseEntity = {
            id: this.recordId,
            recordTypeId: this.recordTypeId,
            status: this.template.querySelector("lightning-input-field[data-id='Status']")?.value ?? null,
            subject: this.template.querySelector("lightning-input-field[data-id='Subject']")?.value ?? null,
            caseOrigin: this.caseOrigin,
            ownerId: this.template.querySelector("lightning-input-field[data-id='ownerId']")?.value ?? null,
            priority: this.template.querySelector("lightning-input-field[data-id='priority']")?.value ?? null,
            enquirerName: this.template.querySelector("lightning-input-field[data-id='enquirerName']")?.value ?? null,
            contactEmail: this.template.querySelector("lightning-input-field[data-id='contactEmail']")?.value ?? null,
            accountId: this.template.querySelector("lightning-input-field[data-id='accountId']")?.value ?? null,
            clientCode: this.template.querySelector("lightning-input-field[data-id='clientCode']")?.value ?? null,
            contactNo: this.template.querySelector("lightning-input-field[data-id='contactNo']")?.value ?? null,
            IDNumber: this.template.querySelector("lightning-input-field[data-id='IDNumber']")?.value ?? null,
            agentCode: this.template.querySelector("lightning-input-field[data-id='agentCode']")?.value ?? null,
            enquirySummary: this.template.querySelector("lightning-input-field[data-id='enquirySummary']")?.value ?? null,
            ticketNumber: this.template.querySelector("lightning-input-field[data-id='ticketNumber']")?.value ?? null,
            counterNumber: this.template.querySelector("lightning-input-field[data-id='counterNumber']")?.value ?? null,
            startTime: this.template.querySelector("lightning-input-field[data-id='startTime']")?.value ?? null,
            locationOfTheCentre: this.template.querySelector("lightning-input-field[data-id='locationOfTheCentre']")?.value ?? null,
            accompanyBy: this.template.querySelector("lightning-input-field[data-id='accompanyBy']")?.value ?? null,
            endTime: this.template.querySelector("lightning-input-field[data-id='endTime']")?.value ?? null,
            letterSender: this.template.querySelector("lightning-input-field[data-id='letterSender']")?.value ?? null,
            forwardedTheLetterTo: this.template.querySelector("lightning-input-field[data-id='forwardedTheLetterTo']")?.value ?? null,
            channelOfReceipt: this.template.querySelector("lightning-input-field[data-id='channelOfReceipt']")?.value ?? null,
            logNumber: this.template.querySelector("lightning-input-field[data-id='logNumber']")?.value ?? null,
            letterRecipient: this.template.querySelector("lightning-input-field[data-id='letterRecipient']")?.value ?? null,
            dateOfReceipt: this.template.querySelector("lightning-input-field[data-id='dateOfReceipt']")?.value ?? null,
            documentType: this.template.querySelector("lightning-input-field[data-id='documentType']")?.value ?? null,
            scheduledTime: this.template.querySelector("lightning-input-field[data-id='scheduledTime']")?.value ?? null,
            attendance: this.template.querySelector("lightning-input-field[data-id='attendance']")?.value ?? null,
            meetingLink: this.template.querySelector("lightning-input-field[data-id='meetingLink']")?.value ?? null,
            firstContactResolution: this.firstContactResolution,
            personContactId: this.PersonContactId,
            ignoreMaster: this.action == 'CaseDetail'? true : false,
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

        this.mandatoryField.forEach(field => {
            console.log("validation "+field+":",this.caseEntity[field]);
            if (this.caseEntity && !this.caseEntity[field]) {
                blankFields.push(field);
                passValidation = false;
            }
        })
        if (!passValidation) {
            this.showToast('Error', 'Please fill in the required fields: ' + blankFields.join(', '), 'error');

            // 必填字段报红
            const inputs = [...this.template.querySelectorAll('lightning-input, lightning-input-field, lightning-combobox')];
            const isValid = inputs.reduce((valid, input) => {
                if (input.reportValidity) {
                    return input.reportValidity() && valid;
                }
                return valid;
            }, true);
        }
        return passValidation;
    }

	handleCancel() {
		// 导航回Case列表页面
		this[NavigationMixin.Navigate]({
			type: 'standard__objectPage',
			attributes: {
				objectApiName: 'Case',
				actionName: 'home'
			}
		});

        // history.back();
	}

    handleSave() {
		// let Subject = this.template.querySelector("lightning-input-field[data-id='Subject']");
		// let enquirerName = this.template.querySelector("lightning-input-field[data-id='enquirerName']");
        // console.log('e1====>' , Subject.value);// reltime value
        // console.log('e2====>' , enquirerName.value);// reltime value
        // console.log('enquirerName====>' , this.enquirerName);// 需要配合onchange方法重写它的值

        this.buildCases();
        console.log('caseEntity====>' , JSON.stringify(this.caseEntity));

        // 验证数据
        const passValidation = this.validation(); 
        console.log("passValidation:"+passValidation);

        // 通过验证
        if(passValidation){
            console.log("pass validation!!!!");

            save({ caseEntityString: JSON.stringify(this.caseEntity) })
            .then(result => {
                console.log("save result:",JSON.stringify(result));
                if(result && result.statusCode == '0'){
                    
                    const caseId = result.data?.caseId ?? null;
                    console.log("CaseId:",result.data?.caseId); 

                    this.showToast('Success', 'Case created successfully', 'success');

                    // 导航到新创建的Case记录页面
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: caseId,
                            objectApiName: 'Case',
                            actionName: 'view'
                        }
                    });

                }else{
                    this.showToast('Error', 'Please contact your system admin: '+result?.message, 'error');
                }
            }).catch(error => {
                console.log("save error", "错误", '发生错误，请提交以下信息给管理员：'+JSON.stringify(error));
            })
        }

        // save({ caseEntityString: JSON.stringify(this.caseEntity) })
        // .then(result => {
        //     console.log("save result:",JSON.stringify(result));
        //     if(result && result.statusCode == '0'){
                
        //         const caseId = result.data?.caseId ?? null;
        //         console.log("CaseId:",result.data?.caseId); 

        //         this.showToast('Success', 'Case created successfully', 'success');

        //         // 导航到新创建的Case记录页面
        //         this[NavigationMixin.Navigate]({
        //             type: 'standard__recordPage',
        //             attributes: {
        //                 recordId: caseId,
        //                 objectApiName: 'Case',
        //                 actionName: 'view'
        //             }
        //         });

        //     }
        // }).catch(error => {
        //     console.log("save error", "错误", '发生错误，请提交以下信息给管理员：'+JSON.stringify(error));
        // })
	}

    copyToCase(message) {
        console.log('search message:' + JSON.stringify(message));
        console.log('message.caseData:' + JSON.stringify(message.caseData));

        if(!this.currentCaseId){
            this.showToast('Error', 'Please click "Add New Policy" Button first', 'error');
            return;
        }

        const caseItem = this.childCases.find(
            c => c.id === this.currentCaseId
        );
        const policy = { 
            id: message.caseData.Id, 
            name: message.caseData.Name, 
            isSelected: true 
        };
        // this.selectedPolicies.push(policy);
        caseItem.policyList.push(policy);
        caseItem.policyList = [...caseItem.policyList];

        // 如果Account Id为空，需要copy to AccountId
        if (!this.accountId) {
            console.log('NameInsuredId:' + message.caseData.NameInsuredId);
            this.accountId = message.caseData.NameInsuredId;
            this.getAccountDetails(this.accountId);
        }
    }

    async getUtility() {
        try {
            const utilityInfo = await getAllUtilityInfo();
            console.error('getAllUtilityInfo:'+JSON.stringify(utilityInfo));
            // 3. 遍历查找特定的 Utility Item，这里以标签 "呼叫控制台" 为例
            for (let i = 0; i < utilityInfo.length; i++) {
                if (utilityInfo[i].utilityLabel === 'Customer And Policy Search') { // 请替换为你的 Utility Item 的标签
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

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }

	// 刷新Hotline Group
	handleRefreshHotlineGroup() {
		// 这里可以添加刷新Hotline Group的逻辑
		// 例如重新获取相关数据或重置字段值
		this.dispatchEvent(
			new ShowToastEvent({
				title: 'Info',
				message: 'Hotline Group refreshed',
				variant: 'info'
			})
		);
	}

	// 查看依赖关系
	handleViewDependencies() {
		// 这里可以添加查看依赖关系的逻辑
		// 例如打开一个模态框或导航到相关页面
		this.dispatchEvent(
			new ShowToastEvent({
				title: 'Info',
				message: 'Opening dependencies view...',
				variant: 'info'
			})
		);
	}

    // @api utilityBarHeightPx = 56;

    // // 根据传入的utilityBarHeightPx设置CSS变量
	// setUtilityBarCssVar() {
	// 	try {
	// 		const host = this.template.host;
	// 		host.style.setProperty('--nwd-utility-bar-height', `${this.utilityBarHeightPx}px`);
	// 	} catch (e) {
	// 		/* ignore */
	// 	}
	// }
}