import { LightningElement, track, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import JOB_OBJECT from '@salesforce/schema/CRM_Global_Data_Ingestion_Job__c';
import CALL_TYPE_FIELD from '@salesforce/schema/CRM_Global_Data_Ingestion_Job__c.CRM_Global_Call_Type__c';
import TARGET_OBJECT_FIELD from '@salesforce/schema/CRM_Global_Data_Ingestion_Job__c.CRM_Global_TargetObject__c';
import SUB_TYPE_1_FIELD from '@salesforce/schema/CRM_Global_Data_Ingestion_Job__c.CRM_Global_Sub_Type_1__c';
import CHANNEL_FIELD from '@salesforce/schema/CRM_Global_Data_Ingestion_Job__c.CRM_Global_Channel__c';
import sheetJS from '@salesforce/resourceUrl/sheetjs';
import parseExcelAndSaveRecords from '@salesforce/apex/CRMGlobalExcelParserController.parseExcelAndSaveRecords';

export default class DragAndDropExcel extends LightningElement {
    @track fileInfo = '';
    @track fileData = null;
    @track isLoading = false;
    @track disableParseButton = true;
    @track processingStats = null;
    @track selectedCallType = '';
    @track selectedTargetObject = '';
    @track subType1 = '';
    @track subType2 = '';
    
    @track channel = '';
    @track callTypeOptions = [];
    @track targetObjectOptions = [];
    @track subTypeOptions = [];
    @track channelOptions = [];
    @track showPreviewModal = false;
    @track previewJsonData = null;
    @track maxPreviewRecords = 50;
    @track maxRecordNumber = 10000;

    @track selectedSubType = '';
    @track selectedChannel = '';

    recordTypeName = 'File Import';
    
    sheetJSLoaded = false;

    // 获取对象信息
    @wire(getObjectInfo, { objectApiName: JOB_OBJECT })
    objectInfo;

    // 获取Call Type字段的picklist值
    @wire(getPicklistValues, {
        recordTypeId: '$fileImportRecordTypeId',
        fieldApiName: CALL_TYPE_FIELD
    })
    wiredPicklistValues({ error, data }) {
        if (data) {
            this.callTypeOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
        } else if (error) {
            console.error('Error loading picklist values:', error);
            this.showToast('Error', 'Failed to load call type options', 'error');
        }
    }

    // 获取Ingestion Job表的File_Import类型的record type id
    get fileImportRecordTypeId() {
        if (!this.objectInfo.data) {
            return null;
        }

        const rtis = this.objectInfo.data.recordTypeInfos;
        const recordTypeId = Object.keys(rtis).find(
            rtid => rtis[rtid].name === this.recordTypeName
        );

        return recordTypeId;
    }

    // 获取Target_Object__c字段的picklist值
    @wire(getPicklistValues, {
        recordTypeId: '$fileImportRecordTypeId',
        fieldApiName: TARGET_OBJECT_FIELD
    })
    wiredTargetObjectValues({ error, data }) {
        if (data) {
            this.targetObjectOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
        } else if (error) {
            console.error('Error loading target object picklist values:', error);
            this.showToast('Error', 'Failed to load target object options', 'error');
        }
    }

    // 获取Sub Type 1字段的picklist值
    @wire(getPicklistValues, {
        recordTypeId: '$fileImportRecordTypeId',
        fieldApiName: SUB_TYPE_1_FIELD
    })
    wiredSubTypeValues({ error, data }) {
        if (data) {
            this.subTypeOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
        } else if (error) {
            console.error('Error loading sub type 1 picklist values:', error);
            this.showToast('Error', 'Failed to load sub type 1 options', 'error');
        }
    }

    // 获取Channel字段的picklist值
    @wire(getPicklistValues, {
        recordTypeId: '$fileImportRecordTypeId',
        fieldApiName: CHANNEL_FIELD
    })
    wiredChannelValues({ error, data }) {
        if (data) {
            this.channelOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
        } else if (error) {
            console.error('Error loading channel picklist values:', error);
            this.showToast('Error', 'Failed to load channel options', 'error');
        }
    }

    // Load SheetJS
    connectedCallback() {
        loadScript(this, sheetJS)
            .then(() => {
                console.log('SheetJS loaded successfully');
                this.sheetJSLoaded = true;
            })
            .catch(error => {
                this.showToast('Error', 'Load SheetJS failed: ' + error.message, 'error');
                console.error('Load SheetJS failed:', error);
            });
    }

    // 预览Excel数据
    async previewExcelData() {
        if (!this.fileData || !this.sheetJSLoaded) {
            this.showToast('Warning', 'Please Upload Excel File First', 'warning');
            return;
        }

        this.isLoading = true;
        
        try {
            const workbook = XLSX.read(this.fileData.arrayBuffer, { 
                type: 'array',
                cellDates: true,
                cellText: false
            });
            
            const recordsData = this.convertWorkbookToRecords(workbook);
            
            if (recordsData.records.length === 0) {
                this.showToast('Warning', 'No valid data found in Excel file', 'warning');
                this.isLoading = false;
                return;
            }
            
            const previewData = {
                ...recordsData,
                records: recordsData.records.slice(0, this.maxPreviewRecords)
            };
            
            this.previewJsonData = previewData;
            this.showPreviewModal = true;
            
        } catch (error) {
            console.error('Preview error:', error);
            this.showToast('Error', 'Preview failed: ' + error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // 关闭预览模态框
    closePreviewModal() {
        this.showPreviewModal = false;
        this.previewJsonData = null;
    }

    // 复制JSON到剪贴板
    async copyJsonToClipboard() {
        try {
            await navigator.clipboard.writeText(JSON.stringify(this.previewJsonData, null, 2));
            this.showToast('Success', 'JSON copied to clipboard', 'success');
        } catch (error) {
            console.error('Copy failed:', error);
            this.showToast('Error', 'Failed to copy JSON', 'error');
        }
    }

    // 格式化显示的JSON
    get formattedJson() {
        if (!this.previewJsonData) return '';
        return JSON.stringify(this.previewJsonData, null, 2);
    }

    // 获取预览记录数量
    get previewRecordCount() {
        return this.previewJsonData?.records?.length || 0;
    }

    // 拖拽事件处理
    handleDragOver(event) {
        event.preventDefault();
        event.stopPropagation();
        event.dataTransfer.dropEffect = 'copy';
        this.template.querySelector('.drop-area').classList.add('dragover');
    }

    handleDragLeave(event) {
        event.preventDefault();
        event.stopPropagation();
        this.template.querySelector('.drop-area').classList.remove('dragover');
    }

    handleDrop(event) {
        event.preventDefault();
        event.stopPropagation();
        this.template.querySelector('.drop-area').classList.remove('dragover');
        
        const files = event.dataTransfer.files;
        if (files.length > 0) {
            const file = files[0];
            
            if (!this.isValidExcelFile(file)) {
                this.showToast('Error', 'Please upload Excel file (.xlsx, .xls, .csv)', 'error');
                return;
            }
            
            this.fileInfo = `File Name: ${file.name}, File Size: ${this.formatFileSize(file.size)}`;
            this.readFileContent(file);
        }
    }

    // 处理下拉菜单选择变化
    handleCallTypeChange(event) {
        this.selectedCallType = event.detail.value;
    }

    handleTargetObjectChange(event) {
        this.selectedTargetObject = event.detail.value;
    }

    handleChannelChange(event){
        this.selectedChannel = event.detail.value;
    }

    handleSubTypeChange(event){
        this.selectedSubType = event.detail.value;
    }

    handleSubType1Change(event) {
        this.subType1 = event.detail.value;
    }

    handleSubType2Change(event) {
        this.subType2 = event.detail.value;
    }

    isValidExcelFile(file) {
        const validTypes = [
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'application/vnd.ms-excel',
            'application/vnd.ms-excel.sheet.macroEnabled.12',
            'text/csv',
            'application/csv'
        ];
        return validTypes.includes(file.type) || 
               file.name.endsWith('.xlsx') || 
               file.name.endsWith('.xls') ||
               file.name.endsWith('.csv');
    }

    readFileContent(file) {
        this.isLoading = true;
        const reader = new FileReader();
        
        reader.onload = (e) => {
            try {
                const arrayBuffer = e.target.result;
                
                this.fileData = {
                    name: file.name,
                    size: file.size,
                    type: file.type,
                    arrayBuffer: arrayBuffer,
                    uploadDate: new Date().toISOString()
                };
                
                this.disableParseButton = false;
                this.showToast('Success', 'File read successfully', 'success');
                
            } catch (error) {
                this.showToast('Error', 'Encountered error when reading file: ' + error.message, 'error');
                console.error('Encountered Error:', error);
            } finally {
                this.isLoading = false;
            }
        };
        
        reader.onerror = (error) => {
            this.showToast('Error', 'Encountered error when reading file: ' + error.message, 'error');
            console.error('Encountered error when reading file: ', error);
            this.isLoading = false;
        };
        
        reader.readAsArrayBuffer(file);
    }

    async parseAndSaveExcel() {
        if (!this.fileData || !this.sheetJSLoaded) {
            this.showToast('Warning', 'Please Upload Excel File First', 'warning');
            return;
        }

        if (!this.selectedCallType) {
            this.showToast('Warning', 'Please select a Call Type before saving', 'warning');
            return;
        }

        if (!this.selectedTargetObject) {
            this.showToast('Warning', 'Please select a Target Object before saving', 'warning');
            return;
        }

        if (!this.selectedChannel) {
            this.showToast('Warning', 'Please select a Channel before saving', 'warning');
            return;
        }

        if (!this.selectedSubType) {
            this.showToast('Warning', 'Please select a Sub Type before saving', 'warning');
            return;
        }

        this.isLoading = true;
        this.processingStats = null;
        
        try {
            const workbook = XLSX.read(this.fileData.arrayBuffer, { 
                type: 'array',
                cellDates: true,
                cellText: false
            });
            
            const recordsData = this.convertWorkbookToRecords(workbook);
            
            if (recordsData.records.length === 0) {
                this.showToast('Warning', 'No valid data found in Excel file', 'warning');
                this.isLoading = false;
                return;
            }

            if (recordsData.records.length > this.maxRecordNumber) {
                this.showToast('Warning', 'The number of Excel file uploaded at once cannot exceed ' + this.maxRecordNumber, 'warning');
                this.isLoading = false;
                return;
            }

            console.log('recordsData:', recordsData);
            console.log('this.selectedSubType:', this.selectedSubType);

            const result = await parseExcelAndSaveRecords({ 
                recordsData: JSON.stringify(recordsData),
                fileName: this.fileData.name,
                callType: this.selectedCallType,
                targetObject: this.selectedTargetObject,
                channel: this.selectedChannel,
                subType: this.selectedSubType
            });
            
            this.processingStats = {
                totalRecords: result.totalRecords,
                successfulRecords: result.successfulRecords,
                failedRecords: result.failedRecords,
                recordIds: result.recordIds
            };
            
            this.showToast(
                'Success', 
                `Process completed: ${result.successfulRecords} successful, ${result.failedRecords} failed, ${result.totalRecords} total`,
                'success'
            );
            
        } catch (error) {
            console.error('Error details:', error);
            const errorMessage = error.body?.message || error.message || 'Unknown Error';
            this.showToast('Error', 'Saving data failed: ' + errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    convertWorkbookToRecords(workbook) {
        const result = {
            fileName: this.fileData.name,
            uploadDate: new Date().toISOString(),
            totalSheets: workbook.SheetNames.length,
            records: []
        };
        
        workbook.SheetNames.forEach(sheetName => {
            const worksheet = workbook.Sheets[sheetName];
            
            if (!worksheet || !XLSX.utils.sheet_to_json(worksheet, { header: 1 }).length) {
                return;
            }
            
            const headers = [];
            const range = XLSX.utils.decode_range(worksheet['!ref']);
            
            for (let C = range.s.c; C <= range.e.c; ++C) {
                const cellAddress = XLSX.utils.encode_cell({ r: range.s.r, c: C });
                const cell = worksheet[cellAddress];
                headers.push(cell ? String(cell.v).trim() : `Column_${C + 1}`);
            }
            
            for (let R = range.s.r + 1; R <= range.e.r; ++R) {
                const rowData = {};
                let hasData = false;
                
                for (let C = range.s.c; C <= range.e.c; ++C) {
                    const cellAddress = XLSX.utils.encode_cell({ r: R, c: C });
                    const cell = worksheet[cellAddress];
                    
                    if (cell) {
                        let cellValue = cell.v;
                        
                        if (cell.t === 'd') {
                            if (typeof cellValue === 'number') {
                                cellValue = new Date((cellValue - 25569) * 86400 * 1000).toISOString();
                            } else if (cellValue instanceof Date) {
                                cellValue = cellValue.toISOString().slice(0, 10);
                            }
                        }
                        
                        const fieldName = headers[C] || `field_${C + 1}`;
                        rowData[fieldName] = cellValue;
                        hasData = true;
                    }
                }
                
                if (hasData) {
                    result.records.push({
                        sheetName: sheetName,
                        rowNumber: R + 1,
                        data: rowData,
                        originalData: JSON.stringify(rowData)
                    });
                }
            }
        });
        
        return result;
    }

    // Reset
    resetFileInfo() {
        this.fileInfo = '';
        this.fileData = null;
        this.disableParseButton = true;
        this.processingStats = null;
        this.selectedCallType = '';
        this.selectedTargetObject = '';
        this.subType1 = '';
        this.subType2 = '';
        this.selectedSubType = '';
        this.selectedChannel = '';
    }

    // Formatting
    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    // Display toast
    showToast(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(toastEvent);
    }

    // Get stats
    get statsText() {
        if (!this.processingStats) return '';
        return `Process result: Total ${this.processingStats.totalRecords} records, ` +
               `success ${this.processingStats.successfulRecords}, ` +
               `Failed ${this.processingStats.failedRecords}`;
    }
}