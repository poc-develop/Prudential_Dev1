import { api, LightningElement, track, wire } from "lwc";
import queryCustomAndPolicy from "@salesforce/apex/CRMGlobalCustomerPolicySearchController.queryCustomAndPolicy";
import checkPolicyParticipantClickable from "@salesforce/apex/CRMGlobalCustomerPolicySearchController.checkPolicyParticipantClickable";
import { NavigationMixin } from "lightning/navigation";
import SearchLabel from "@salesforce/label/c.Search";
import ResetLabel from "@salesforce/label/c.Reset";
import SearchConditionLabel from "@salesforce/label/c.SearchCondition";
import SearchByLabel from "@salesforce/label/c.SearchBy";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import IdentityValidationLabel from "@salesforce/label/c.CaseIdentityValidation";
import VoiceBotMismatchWarningLabel from "@salesforce/label/c.VoiceBotMismatchWarning";
import CaseMessageChannel from "@salesforce/messageChannel/CaseMessageChannel__c";
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext, publish } from "lightning/messageService";
import getSearchConditionMdtList from "@salesforce/apex/CRMGlobalSearchResultColumnController.getSearchConditionMdtList";
import TabFocusedChannel from "@salesforce/messageChannel/TabFocusedChannel__c";
import getPolicySearchResultColumnMdtList from "@salesforce/apex/CRMGlobalSearchResultColumnController.getPolicySearchResultColumnMdtList";


const VB_AUTH_RESULT_PASS = 'Pass';
const VB_AUTH_RESULT_AMBER = 'Amber';
const VB_AUTH_RESULT_FAIL = 'Fail';
export default class CrmGlobalCustomerAndPolicySearch extends NavigationMixin(LightningElement) {
    selectedRow;
    loaded = true;
    searchByVehicleRegistrationNumber = false;
    // columns = [
    //     // {
    //     //     label: "",
    //     //     fieldName: "rowNumber",
    //     //     type: "number",
    //     //     initialWidth: 100,
    //     //     sortable: false,
    //     //     cellAttributes: {
    //     //         alignment: "center"
    //     //     }
    //     // },
    //     {
    //         label: "Validate",
    //         type: "button",
    //         initialWidth: 100,
    //         typeAttributes: {
    //             label: IdentityValidationLabel,
    //             name: "validate",
    //             variant: "base"
    //         }
    //     }
    // ];

    columns = [
        {
            label: "Case",
            type: "button",
            initialWidth: 100,
            typeAttributes: {
                label: IdentityValidationLabel,
                name: "validate",
                variant: "base"
            }
        }
    ];
    columnNotShow = [];
    searchParams = [];
    @api vbAuthResult;

    @api tabFocusedId;
    // Voicebot
    @api searchData;
    // Voicebot
    @track replacedTabId;
    // Voicebot
    @track validation = '';
    // Voicebot
    @track data;
    
    @track sortedBy;
    @track sortedDirection;
    errorMsg;
    // Voicebot
    @track inputsUI;
    // Voicebot

    label = {
        SearchLabel,
        SearchConditionLabel,
        SearchByLabel,
        ResetLabel,
        VoiceBotMismatchWarningLabel
    };

    tabFocusSubscription = null;

    policyParticipantClickable = true;
    // Voicebot

    @api triggerSearch() {
        console.log("this.searchData in trigger search:" + this.searchData);
        if(this.searchData){
            
           let jsonObject = JSON.parse(this.searchData);
           const map = {
               'PolicyNumber': { key: 'policyNumber', flagKey: 'isPolicyNumberValid' },
               'CertificateNumber': { key: 'certificateNumber', flagKey: 'isCertificateNumberValid' },
               'HKIDPassportNumber': { key: 'identityDocumentNumber', flagKey: 'isDocumentIdValid' },
               'DateOfBirth': { key: 'dateOfBirth', flagKey: 'isDateOfBirthValid' },
               'ContactNumber': { key: 'phoneNumber', flagKey: 'isPhoneNumberValid' },
               'MobileNumber': { key: 'phoneNumber', flagKey: 'isPhoneNumberValid' }
           };

           for (let i = 0; i < this.inputsUI.length; i++) {
               const developerName = this.inputsUI[i].DeveloperName;
               const mapping = this.findMapping(developerName, map);

               if (mapping && jsonObject[mapping.flagKey] === 'N') {
                   this.inputsUI[i].notValidated = 'validation-border';
                   this.inputsUI[i].showWarning = true;
               } else {
                    this.inputsUI[i].notValidated = '';
                    this.inputsUI[i].showWarning = false;
               }
       
               this.template.querySelectorAll('lightning-input').forEach(element => {
                   if (element.name === developerName && mapping) {
                    if(mapping.key === 'identityDocumentNumber'){
                        element.value = jsonObject[mapping.key].substring(0,7);
                    }
                    else{
                        element.value = jsonObject[mapping.key];
                    }
                   }
               });
           }
           console.log('this.inputsUI with search '+JSON.stringify(this.inputsUI));
           if(this.vbAuthResult == VB_AUTH_RESULT_PASS || this.vbAuthResult == VB_AUTH_RESULT_AMBER ) {
            this.handleSearch(true);
           }
           
        }
    }
    // Voicebot

    connectedCallback() {
        //this.searchData = searchData;
        getSearchConditionMdtList().then((res) => {
            console.log("search condition:" + JSON.stringify(res));
            this.inputsUI = res;
            // Voicebot
            console.log("this.searchData:" + this.searchData);
            let inputs = res;
            this.inputsUI = inputs.map(row => ({
                ...row,
                notValidated: "",
                showWarning: false,
                options: row.IsSelect__c && row.Options__c
                    ? [{ label: "", value: "" },
                        ...row.Options__c.split(";")
                            .map(v => v && v.trim())
                            .filter(v => v)
                            .map(v => ({ label: v, value: v }))
                      ]
                    : undefined
            }));
            console.log("this.inputsUI:" + JSON.stringify(this.inputsUI));
            // Voicebot
            //this.triggerSearch();
        });
        checkPolicyParticipantClickable().then((res) => {
            console.log("policyParticipantClickable:" + JSON.stringify(res));
            this.policyParticipantClickable = res;
            getPolicySearchResultColumnMdtList().then((res) => {
                console.log("policy search result column:" + JSON.stringify(res));
                if (res) {
                    res.forEach((item) => {
                        if (item.IsShow__c) {
                            if (
                                item.DeveloperName &&
                                item.DeveloperName.toLowerCase().includes("policyparticipant") &&
                                !this.policyParticipantClickable
                            ) {
                                this.columns = [
                                    ...this.columns,
                                    {
                                        label: item.Label,
                                        fieldName: item.FieldName__c,
                                        type: "text",
                                        sortable: item.Sortable__c,
                                        initialWidth: item.InitialWidth__c
                                    }
                                ];
                            } else if (item.TypeAttribute__r) {
                                const typeAttr = item.TypeAttribute__r;
                                this.columns = [
                                    ...this.columns,
                                    {
                                        label: item.Label,
                                        fieldName: item.FieldName__c,
                                        type: item.Type__c,
                                        sortable: item.Sortable__c,
                                        initialWidth: item.InitialWidth__c,
                                        typeAttributes: {
                                            type: typeAttr.Type__c,
                                            label: { fieldName: typeAttr.FieldName__c },
                                            value: { fieldName: typeAttr.Value__c },
                                            needDispatchEvent: typeAttr.NeedDispatchEvent__c,
                                            disableLink: { fieldName: 'disableLink' }
                                        }
                                    }
                                ];
                            } else {
                                this.columns = [
                                    ...this.columns,
                                    {
                                        label: item.Label,
                                        fieldName: item.FieldName__c,
                                        type: item.Type__c,
                                        sortable: item.Sortable__c,
                                        initialWidth: item.InitialWidth__c
                                    }
                                ];
                            }
                        } else {
                            this.columnNotShow = [...this.columnNotShow, item.FieldName__c];
                        }
                    }); 
                    // Voicebot
                    /*if(this.inputsUI && this.columns  && this.searchData){
                        this.handleSearch();
                    }*/
                    // Voicebot
                }
                console.log("display column:" + JSON.stringify(this.columns));
            });
        });
        if (!this.tabFocusSubscription) {
            this.tabFocusSubscription = subscribe(this.messageContext, TabFocusedChannel, (message) => this.handleTabFocusMessage(message), {
                scope: APPLICATION_SCOPE
            });
        }
}

    handleTabFocusMessage(message) {
        console.log("tabFocusMessage=" + JSON.stringify(message));
        this.replacedTabId = message.currentTabId;
    }

    disconnectedCallback() {
        this.unsubscribeToMessageChannel();
    }

    unsubscribeToMessageChannel() {
        unsubscribe(this.tabFocusSubscription);
        this.tabFocusSubscription = null;
    }

    @wire(MessageContext)
    messageContext;

    handleEnter(event) {
        if (event.keyCode === 13) {
            this.handleSearch(false);
        }
    }

    handleInputBlur(event) {
        let targetName = event.target.name;
        let targetValue = event.target.value;
        this.dispatchEvent(
            new CustomEvent("refocus", {
                tabFocusedId: this.tabFocusedId
            })
        );
        if (targetName.indexOf("Date") !== -1) {
            let myReg =
                /^([\d]{4}((((0[13578]|1[02])((0[1-9])|([12][0-9])|(3[01])))|(((0[469])|11)((0[1-9])|([12][0-9])|30))|(02((0[1-9])|(1[0-9])|(2[0-8])))))|((((([02468][048])|([13579][26]))00)|([0-9]{2}(([02468][048])|([13579][26]))))(((0[13578]|1[02])((0[1-9])|([12][0-9])|(3[01])))|(((0[469])|11)((0[1-9])|([12][0-9])|30))|(02((0[1-9])|(1[0-9])|(2[0-9]))))){4})$/;
            let customValidity = "";
            if (targetValue && targetValue.trim()) {
                let birthDateTrim = targetValue.trim();
                let birthDateTemp;
                if (birthDateTrim.match(myReg)) {
                    birthDateTemp = birthDateTrim.replace(/(\d{4})(\d{2})(\d{2})/, "$1-$2-$3");
                } else {
                    birthDateTemp = birthDateTrim;
                }
                let birthDateFormatted = this.formatDate(birthDateTemp);
                if (birthDateFormatted != "Invalid Date") {
                    event.target.value = birthDateFormatted;
                } else {
                    customValidity = "Your entry does not match the allowed format YYYYMMDD";
                }
            }
            event.target.setCustomValidity(customValidity);
            event.target.reportValidity();
        } else if (targetName.indexOf("VehicleRegistrationNumber") !== -1) {
            if (targetValue && targetValue !== "") {
                this.template.querySelectorAll("lightning-input").forEach((inputField) => {
                    inputField.disabled = true;
                });
                event.currentTarget.disabled = false;
                this.searchByVehicleRegistrationNumber = true;
            } else {
                this.template.querySelectorAll("lightning-input").forEach((inputField) => {
                    inputField.disabled = false;
                });
                this.searchByVehicleRegistrationNumber = false;
            }
        }
    }

    handleReset() {
        this.template.querySelectorAll("lightning-input").forEach((inputField) => {
            inputField.value = null;
            inputField.disabled = false;
        });
        this.searchByVehicleRegistrationNumber = false;
        // Voicebot
        for(let i = 0; i < this.inputsUI.length; i++) {
            this.inputsUI[i].notValidated = '';
            this.inputsUI[i].showWarning = false;
        }
        console.log(this.inputsUI);
        // Voicebot
}

    handleSearch(isInvokedByVB) {
        let inputFields = this.template.querySelectorAll("lightning-input");
        this.searchParams = [];
        inputFields.forEach((item) => {
            console.log("filedName:" + item.name);
            console.log("value:" + item.value);
            if (
                item.value &&
                item.value !== "" &&
                (!this.searchByVehicleRegistrationNumber || item.name.indexOf("VehicleRegistrationNumber") !== -1)
            ) {
                let executionLanguage;
                let matchingRule;
                let returningFields;
                let returningObjectTypeName;
                let searchTarget;
                this.inputsUI.forEach((element) => {
                    if (item.name === element.DeveloperName) {
                        if (element.ExecutionLanguage__c) {
                            executionLanguage = element.ExecutionLanguage__c;
                        }
                        if (element.MatchingRule__c) {
                            matchingRule = element.MatchingRule__c;
                        }
                        if (element.ReturningFields__c) {
                            returningFields = element.ReturningFields__c;
                        }
                        if (element.ReturningObjectTypeName__c) {
                            returningObjectTypeName = element.ReturningObjectTypeName__c;
                        }
                        if (element.SearchTarget__c) {
                            searchTarget = element.SearchTarget__c;
                        }
                    }
                });
                this.searchParams = [
                    ...this.searchParams,
                    {
                        id: item.parentElement.getAttribute("data-id"),
                        label: item.label,
                        value: item.value,
                        type: item.type,
                        name: item.name,
                        executionLanguage: executionLanguage,
                        matchingRule: matchingRule,
                        returningFields: returningFields,
                        returningObjectTypeName: returningObjectTypeName,
                        searchTarget: searchTarget
                    }
                ];
            }
        });
        console.log("searchParams:" + JSON.stringify(this.searchParams));
        if (!this.isInputvalid(inputFields)) {
            return;
        }
        this.loaded = false;
        this.data = [];

        console.log("tabfocused id in policy search" + this.tabFocusedId);

        queryCustomAndPolicy({ searchParams: this.searchParams })
            .then((result) => {
                console.log("result", JSON.stringify(result));
                let tempResult = [];
                let tempResult1 = [];
                this.translateResult(tempResult, result);
                console.log("translateResult", JSON.stringify(result));
                this.translateResult(tempResult1, tempResult);
                console.log("tempResult1", JSON.stringify(tempResult1));

                // Add row numbers and disableLink based on privacy flag to the data
                this.data = tempResult1.map((row, index) => ({
                    ...row,
                    rowNumber: index + 1,
                    disableLink: row['NameInsured.CRM_Global_PrivacyFlag__c'] === true || row['NameInsured.CRM_Global_PrivacyFlag__c'] === 'true'
                }));
                // assign the latest attribute with the sorted column fieldName and sorted direction
                this.sortedBy = "Name";
                this.sortedDirection = "asc";
                this.sortData(this.sortedBy, this.sortedDirection);
                console.log("queryCustomAndPolicy.data", this.data);
                this.template.querySelector(".accordion").activeSectionName = [];
                this.loaded = true;

                console.log('Before publish VB Event');
                console.log(tempResult1.length);
                console.log(isInvokedByVB);
                console.log('VB Check end');
                
                if(tempResult1.length > 0 && isInvokedByVB) {
                    //TO DO: add auto copy logic
                    let targetTabId = this.tabFocusedId;
                    
                    // publish(this.messageContext, CaseMessageChannel, {
                    //     targetTabId: targetTabId,
                    //     triggerVBValidation: isInvokedByVB,
                    //     isValidationDefaultOpen: false,
                    //     caseData: tempResult1[0]
                    // });
                    console.log(this.vbAuthResult);
                    
                    if(this.vbAuthResult == VB_AUTH_RESULT_PASS) {
                        this.dispatchEvent(new CustomEvent("navigate", { bubbles: true, composed: true }));
                        this.data = []; 
                    }    
                }
            })
            .catch((error) => {
                this.errorMsg = error;
                this.template.querySelector(".accordion").activeSectionName = [];
                this.loaded = true;
                console.log("this.errorMsg", this.errorMsg);
            });
    }

    isInputvalid(inputFields) {
        let isValid = true;
        inputFields.forEach((inputField) => {
            console.log(inputField.name + "=" + inputField.value + " " + inputField.checkValidity());
            if (!inputField.checkValidity()) {
                inputField.reportValidity();
                isValid = false;
            }
        });
        //console.log();
        if (!isValid) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "WARNING",
                    message: "Please update the invalid form entries and try again.",
                    variant: "error"
                })
            );
        }
        return isValid;
    }

    callRowAction(event) {
        this.selectedRow = "";
        //const recId =  event.detail.row.Id;
        const row = event.detail.row;
        const actionName = event.detail.action.name;
        console.log("action row:" + JSON.stringify(row));
        console.log("actionName:" + actionName);
        console.log("column:" + JSON.stringify(this.columns));
        console.log("column not show:" + JSON.stringify(this.columnNotShow));
        this.columns.forEach((column) => {
            if (column.fieldName && row[column.fieldName] === undefined) {
                row[column.fieldName] = "";
            }
        });
        this.columnNotShow.forEach((column) => {
            if (row[column] === undefined) {
                row[column] = "";
            }
        });
        console.log("row data:" + JSON.stringify(row));
        if (actionName === "validate") {
            this.selectedRow = row;
            this.replacedTabId = "HomeTab";
            let targetTabId = typeof this.tabFocusedId === "undefined" || this.tabFocusedId == null ? this.replacedTabId : this.tabFocusedId;
            console.log("[customerAndPolicySearchComponent] this.tabFocusedId=" + this.tabFocusedId);
            console.log("rowaction publish targetTabId" + targetTabId);
            publish(this.messageContext, CaseMessageChannel, {
                targetTabId: targetTabId,
                triggerVBValidation: false,
                isValidationDefaultOpen: true,
                caseData: row
            });
            this.dispatchEvent(new CustomEvent("navigate", { bubbles: true, composed: true }));
            this.handleReset();
            this.searchParams=[];
            this.data=null;
            this.template.querySelector(".accordion").activeSectionName = ['A'];
        }
    }

    _flatten = (nodeValue, flattenedRow, nodeName) => {
        let rowKeys = Object.keys(nodeValue);
        rowKeys.forEach((key) => {
            let finalKey = nodeName + "." + key;
            flattenedRow[finalKey] = nodeValue[key];
        });
    };

    translateResult = (resultList, targetList) => {
        for (let row of targetList) {
            let flattenedRow = {};
            let rowKeys = Object.keys(row);
            rowKeys.forEach((rowKey) => {
                let singleNodeValue = row[rowKey];
                if (singleNodeValue.constructor === Object) {
                    //if it's an object flatten it
                    this._flatten(singleNodeValue, flattenedRow, rowKey);
                } else {
                    //if it’s a normal string push it to the flattenedRow array
                    flattenedRow[rowKey] = singleNodeValue;
                }
            });
            resultList.push(flattenedRow);
        }
    };

    formatDate = (date) => {
        let myDate = new Date(date);
        if (myDate.toString() === "Invalid Date") {
            return "Invalid Date";
        }
        let y = myDate.getFullYear();
        let m = myDate.getMonth() + 1;
        let d = myDate.getDate();
        let mm = m < 10 ? "0" + m : m;
        let dd = d < 10 ? "0" + d : d;
        return "" + y + "-" + mm + "-" + dd;
    };

    // The method onsort event handler
    handleColumnSorting(event) {
        let fieldName = event.detail.fieldName;
        let sortDirection = event.detail.sortDirection;
        // assign the latest attribute with the sorted column fieldName and sorted direction
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        console.log("fieldName=", fieldName);
        console.log("sortDirection=", sortDirection);
        this.sortData(fieldName, sortDirection);
    }

    sortData(fieldName, sortDirection) {
        //Deep clone for rerender
        let parseData = JSON.parse(JSON.stringify(this.data));
        if (parseData && typeof parseData === "object" && parseData.length > 0) {
            // console.log('parseData[0]=' + JSON.stringify(parseData[0]));
            console.log("this.data[0]=" + JSON.stringify(this.data[0]));
            let keyValue = function (x) {
                return x[fieldName];
            };
            let isReverse = sortDirection === "asc" ? 1 : -1;
            parseData.sort((a, b) => {
                return (a = keyValue(a) ? keyValue(a) : ""), (b = keyValue(b) ? keyValue(b) : ""), isReverse * ((a > b) - (b > a));
            });
            // Reassign row numbers after sorting
            parseData = parseData.map((row, index) => ({
                ...row,
                rowNumber: index + 1
            }));
            // console.log('parseData[0]=' + JSON.stringify(parseData[0]));
            this.data = parseData;
            console.log("this.data[0]=" + JSON.stringify(this.data[0]));
        }
    }

    findMapping(developerName, map) {
       const prefixes = ['PolicyNumber', 'CertificateNumber', 'HKIDPassportNumber', 'DateOfBirth', 'ContactNumber', 'MobileNumber'];
   
       for (const prefix of prefixes) {
           if (developerName.startsWith(prefix)) {
               return map[prefix];
           }
       }
   
       return null;
   }
   
}