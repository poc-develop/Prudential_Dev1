# CRMGlobalEnquirySyncBatch 调试指南

## 1. 代码调试增强

### 1.1 添加详细日志

在关键位置添�?`System.debug` 语句，建议在以下位置添加�?

```apex
// �?start 方法�?
public Database.QueryLocator start(Database.BatchableContext bc) {
    System.debug(LoggingLevel.INFO, '=== Batch Started ===');
    System.debug(LoggingLevel.INFO, 'Batch Job Id: ' + bc.getJobId());
    return Database.getQueryLocator([SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1]);
}

// �?execute 方法开�?
public void execute(Database.BatchableContext bc, List<SObject> scope) {
    System.debug(LoggingLevel.INFO, '=== Execute Started ===');
    System.debug(LoggingLevel.INFO, 'Scope size: ' + scope.size());
    System.debug(LoggingLevel.INFO, 'Job Id: ' + bc.getJobId());
    
    try {
        System.debug(LoggingLevel.INFO, 'Calling API...');
        CRMGlobalEnquiryAPIResponse apiResponse = callEnquiryAPI();
        
        System.debug(LoggingLevel.INFO, 'API Response received');
        System.debug(LoggingLevel.INFO, 'ReturnCode: ' + (apiResponse != null ? apiResponse.ReturnCode : 'null'));
        System.debug(LoggingLevel.INFO, 'Results count: ' + (apiResponse != null && apiResponse.Results != null ? apiResponse.Results.size() : 0));
        
        if (apiResponse != null && apiResponse.Results != null && !apiResponse.Results.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'Processing ' + apiResponse.Results.size() + ' enquiries');
            processEnquiryData(apiResponse.Results);
        } else {
            System.debug(LoggingLevel.WARN, 'No data to process');
        }
    } catch (Exception e) {
        // ... existing error handling
    }
}

// �?finish 方法�?
public void finish(Database.BatchableContext bc) {
    System.debug(LoggingLevel.INFO, '=== Batch Finished ===');
    System.debug(LoggingLevel.INFO, 'Job Id: ' + bc.getJobId());
    System.debug(LoggingLevel.INFO, 'Processed: ' + processedCount);
    System.debug(LoggingLevel.INFO, 'Success: ' + successCount);
    System.debug(LoggingLevel.INFO, 'Failed: ' + failureCount);
    // ... rest of code
}
```

### 1.2 在关键方法中添加日志

�?`callEnquiryAPI()` 方法中：
```apex
private CRMGlobalEnquiryAPIResponse callEnquiryAPI() {
    try {
        System.debug(LoggingLevel.INFO, '=== API Call Started ===');
        DateTime lastSyncTime = getLastSyncTime();
        currentSyncTime = DateTime.now();
        System.debug(LoggingLevel.INFO, 'Last Sync Time: ' + formatDateTimeForAPI(lastSyncTime));
        System.debug(LoggingLevel.INFO, 'Current Sync Time: ' + formatDateTimeForAPI(currentSyncTime));
        
        // ... API call code
        
        System.debug(LoggingLevel.INFO, 'API Response Status: ' + response.getStatusCode());
        System.debug(LoggingLevel.DEBUG, 'API Response Body: ' + response.getBody());
        
        // ... rest of code
    }
}
```

�?`processEnquiryData()` 方法中：
```apex
private void processEnquiryData(List<CRMGlobalEnquiryData> enquiryList) {
    System.debug(LoggingLevel.INFO, '=== Processing Enquiry Data ===');
    System.debug(LoggingLevel.INFO, 'Enquiry List Size: ' + enquiryList.size());
    
    // ... existing code
    
    System.debug(LoggingLevel.INFO, 'Master Cases to insert: ' + masterCasesToInsert.size());
    System.debug(LoggingLevel.INFO, 'Enquiry Cases to insert: ' + enquiryCasesToInsert.size());
}
```

## 2. 使用匿名 Apex 手动触发和调�?

### 2.1 手动触发批处�?

�?Developer Console �?VS Code �?Anonymous Apex 中执行：

```apex
// 创建批处理实�?
CRMGlobalEnquirySyncBatch batch = new CRMGlobalEnquirySyncBatch();

// 执行批处理（批次大小�?，便于调试）
Id jobId = Database.executeBatch(batch, 1);

System.debug('Batch Job ID: ' + jobId);
```

### 2.2 检查批处理状�?

```apex
// 查询批处理作业状�?
AsyncApexJob job = [
    SELECT Id, Status, NumberOfErrors, JobItemsProcessed, 
           TotalJobItems, CreatedBy.Email, CreatedDate,
           CompletedDate, ExtendedStatus, ApexClass.Name
    FROM AsyncApexJob 
    WHERE Id = :jobId
    LIMIT 1
];

System.debug('Job Status: ' + job.Status);
System.debug('Job Items Processed: ' + job.JobItemsProcessed);
System.debug('Total Job Items: ' + job.TotalJobItems);
System.debug('Number of Errors: ' + job.NumberOfErrors);
System.debug('Extended Status: ' + job.ExtendedStatus);
System.debug('Completed Date: ' + job.CompletedDate);
```

### 2.3 查看最近的批处理作�?

```apex
// 查看最近的批处理作�?
List<AsyncApexJob> jobs = [
    SELECT Id, Status, NumberOfErrors, JobItemsProcessed, 
           TotalJobItems, CreatedDate, CompletedDate, 
           ExtendedStatus, ApexClass.Name
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'CRMGlobalEnquirySyncBatch'
    ORDER BY CreatedDate DESC
    LIMIT 10
];

for (AsyncApexJob job : jobs) {
    System.debug('Job ID: ' + job.Id);
    System.debug('Status: ' + job.Status);
    System.debug('Errors: ' + job.NumberOfErrors);
    System.debug('---');
}
```

## 3. 使用 Developer Console 查看日志

### 3.1 设置 Trace Flag

1. 进入 **Setup �?Debug Logs**
2. 创建新的 Trace Flag�?
   - **Traced Entity Type**: User
   - **Traced Entity**: 选择你的用户
   - **Apex Code**: DEBUG
   - **Apex Profiling**: DEBUG
   - **System**: DEBUG
3. 保存

### 3.2 查看日志

1. �?Developer Console 中打开 **Logs** 标签
2. 触发批处�?
3. 等待批处理执行完�?
4. 双击日志条目查看详细信息
5. 使用搜索功能查找特定的调试信�?

### 3.3 日志查看技�?

- 使用 `Ctrl+F` 搜索关键字，如：
  - `=== Batch Started ===`
  - `API Call Started`
  - `ERROR`
  - `Exception`

## 4. 检�?Platform Cache

### 4.1 查看缓存中的同步时间

```apex
// 检�?Platform Cache 中的上次同步时间
Cache.OrgPartition orgPartition = Cache.Org.getPartition('local.BatchSyncCache');
if (orgPartition != null) {
    Object cachedTime = orgPartition.get('CRM_PHKL_Enquiry_Last_Sync_Time');
    if (cachedTime != null) {
        System.debug('Cached Last Sync Time: ' + cachedTime);
        if (cachedTime instanceof DateTime) {
            System.debug('Formatted Time: ' + ((DateTime)cachedTime).formatGmt('yyyy-MM-dd HH:mm:ss'));
        }
    } else {
        System.debug('No cached time found');
    }
} else {
    System.debug('Platform Cache partition not available');
}
```

### 4.2 手动设置缓存值（用于测试�?

```apex
// 设置测试用的同步时间
DateTime testTime = DateTime.now().addHours(-8);
Cache.OrgPartition orgPartition = Cache.Org.getPartition('local.BatchSyncCache');
if (orgPartition != null) {
    orgPartition.put('CRM_PHKL_Enquiry_Last_Sync_Time', testTime);
    System.debug('Test sync time set to: ' + testTime.formatGmt('yyyy-MM-dd HH:mm:ss'));
}
```

### 4.3 清除缓存

```apex
// 清除缓存（用于重新开始）
Cache.OrgPartition orgPartition = Cache.Org.getPartition('local.BatchSyncCache');
if (orgPartition != null) {
    orgPartition.remove('CRM_PHKL_Enquiry_Last_Sync_Time');
    System.debug('Cache cleared');
}
```

## 5. 测试 API 调用

### 5.1 独立测试 API 调用

创建一个测试方法或匿名 Apex 来测�?API 调用�?

```apex
// 测试 API 调用（不通过批处理）
public static void testAPICall() {
    // 模拟批处理的 API 调用逻辑
    Http http = new Http();
    HttpRequest request = new HttpRequest();
    request.setEndpoint('callout:CRM_PHKL_APIM_AES' + '/getAESeEnquiry');
    request.setMethod('POST');
    
    Map<String, String> body = new Map<String, String>();
    body.put('createDtFrom', '2025-01-01T00:00:00Z');
    body.put('createDtTo', DateTime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
    // ... other fields
    
    String bodyString = JSON.serialize(body);
    System.debug('Request Body: ' + bodyString);
    request.setBody(bodyString);
    request.setTimeout(60000);
    
    HttpResponse response = http.send(request);
    System.debug('Response Status: ' + response.getStatusCode());
    System.debug('Response Body: ' + response.getBody());
}
```

## 6. 检�?CRMGlobalLogManager 日志

### 6.1 查询日志记录

```apex
// 查询最近的错误日志
List<CRM_Global_ApexLog__c> logs = [
    SELECT Id, Name, Error_Message__c, Stack_Trace__c, 
           CreatedDate, Log_Level__c
    FROM CRM_Global_ApexLog__c
    WHERE CreatedDate = TODAY
    AND Error_Message__c LIKE '%Enquiry%'
    ORDER BY CreatedDate DESC
    LIMIT 50
];

for (CRM_Global_ApexLog__c log : logs) {
    System.debug('Log: ' + log.Name);
    System.debug('Level: ' + log.Log_Level__c);
    System.debug('Message: ' + log.Error_Message__c);
    System.debug('---');
}

// 查询 Web Service 调用日志
List<CRM_Global_Webservice_Call_Log__c> wsLogs = [
    SELECT Id, Name, Request_URL__c, Response_Status__c, 
           Duration__c, CreatedDate
    FROM CRM_Global_Webservice_Call_Log__c
    WHERE CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 50
];

for (CRM_Global_Webservice_Call_Log__c log : wsLogs) {
    System.debug('WS Log: ' + log.Name);
    System.debug('URL: ' + log.Request_URL__c);
    System.debug('Status: ' + log.Response_Status__c);
    System.debug('Duration: ' + log.Duration__c + 'ms');
    System.debug('---');
}
```

## 7. 创建测试类进行单元测�?

### 7.1 基本测试类结�?

```apex
@isTest
private class CRMGlobalEnquirySyncBatchTest {
    
    @testSetup
    static void setupTestData() {
        // 设置测试数据
        // 例如：创建测试用�?RecordType、测试用户等
    }
    
    @isTest
    static void testBatchExecution() {
        Test.startTest();
        
        // 设置 Mock HTTP 响应（如果需要）
        // Test.setMock(HttpCalloutMock.class, new YourMockHttpResponse());
        
        // 执行批处�?
        CRMGlobalEnquirySyncBatch batch = new CRMGlobalEnquirySyncBatch();
        Id jobId = Database.executeBatch(batch, 1);
        
        Test.stopTest();
        
        // 验证结果
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors 
            FROM AsyncApexJob 
            WHERE Id = :jobId
        ];
        
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
        
        // 验证创建的记�?
        // List<Case> cases = [SELECT Id FROM Case WHERE ...];
        // System.assert(cases.size() > 0);
    }
    
    @isTest
    static void testAPICallFailure() {
        // 测试 API 调用失败的情�?
    }
    
    @isTest
    static void testEmptyResponse() {
        // 测试 API 返回空结果的情况
    }
}
```

## 8. 监控和检查清�?

### 8.1 执行前检�?

- [ ] Platform Cache Partition 已创建并配置
- [ ] Named Credential `CRM_PHKL_APIM_AES` 已配�?
- [ ] Custom Metadata `CRM_PHKL_AES_Enquiry` 已配�?
- [ ] Case RecordType `Master_Inbound` �?`Enquiry` 存在且激�?
- [ ] 所有必需的字段在 Case 对象上存�?

### 8.2 执行后检�?

- [ ] 批处理状态为 `Completed` �?`Failed`
- [ ] 检查错误日志（`AsyncApexJob.ExtendedStatus`�?
- [ ] 检查创建的 Case 记录数量
- [ ] 验证 Master Case �?Enquiry Case 的父子关�?
- [ ] 检�?Platform Cache 中保存的同步时间
- [ ] 查看 `CRMGlobalLogManager` 的日�?

### 8.3 常见问题排查

#### 问题 1: Debug 日志没有打印出来

**症状**: `=== Execute Started ===` 或其�?DEBUG 日志没有出现在日志中

**解决方法**:
1. **设置 Trace Flag**（必须）:
   - 进入 **Setup �?Debug Logs**
   - 点击 **New** 创建新的 Trace Flag
   - **Traced Entity Type**: User
   - **Traced Entity**: 选择当前用户
   - **Apex Code**: DEBUG
   - **Apex Profiling**: DEBUG  
   - **System**: DEBUG
   - **Database**: INFO
   - 保存

2. **检查日志级�?*:
   - 确保代码中使�?`System.debug(LoggingLevel.INFO, ...)` 或更高级�?
   - `System.debug()`（无级别）默认为 DEBUG 级别，需�?Trace Flag 支持

3. **等待批处理完�?*:
   - 批处理是异步执行的，需要等待完成后才能查看日志
   - �?Developer Console 中，等待批处理完成后刷新日志列表

4. **查看正确的日�?*:
   - Developer Console �?**Logs** 标签
   - 找到对应的批处理作业时间的日�?
   - 双击打开日志，使�?`Ctrl+F` 搜索关键�?

#### 问题 2: API 调用返回 404 错误

**症状**: `API call failed with status code: 404`

**可能原因和解决方�?*:

1. **Named Credential 不存在或未配�?*:
   ```apex
   // 检�?Named Credential 是否存在
   // Setup �?Named Credentials �?查找 "CRM_PHKL_APIM_AES"
   ```
   - 进入 **Setup �?Named Credentials**
   - 确认 `CRM_PHKL_APIM_AES` 存在且已激�?
   - 检�?URL 是否正确（不应该包含路径，只包含 base URL�?

2. **Endpoint 路径错误**:
   - 代码中使�? `'callout:CRM_PHKL_APIM_AES' + '/getAESeEnquiry'`
   - 验证路径 `/getAESeEnquiry` 是否正确
   - 检查是否需要添加前缀（如 `/api/v1`�?

3. **Named Credential URL 配置错误**:
   - Named Credential �?URL 应该是基础 URL（如: `https://api.example.com`�?
   - 不应包含路径部分
   - 如果 API 需要路径，应该在代码中添加

4. **验证方法**:
   ```apex
   // 测试 Named Credential 配置
   HttpRequest req = new HttpRequest();
   req.setEndpoint('callout:CRM_PHKL_APIM_AES');
   req.setMethod('GET');
   
   // 这会显示完整�?resolved URL（在日志中查看）
   // 注意：实际调用需要在允许 Callout 的上下文�?
   ```

5. **检�?HTTP 方法**:
   - 确认 API 是否需�?POST（当前使用）
   - 某些 API 可能需�?GET 或其他方�?

#### 问题 3: 批处理一直处�?Queued 状�?
   - 检查是否有其他批处理正在运�?
   - 查看系统限制（最�?5 个批处理并发�?
   - 等待其他批处理完�?

#### 问题 4: 数据未创�?
   - 检�?API 响应是否有数�?
   - 验证字段映射是否正确
   - 检查验证规则和必填字段
   - 查看错误日志中的具体错误信息

#### 问题 5: Platform Cache 未保�?
   - 确认 Platform Cache Partition 已创�?
   - 检查分配的缓存大小是否足够
   - 验证分区名称是否正确（`local.BatchSyncCache`�?

## 9. 快速调试脚�?

### 9.1 完整调试脚本

�?Developer Console �?Anonymous Apex 中执行：

```apex
// ===== 完整调试脚本 =====

// 1. 清除缓存（如果需要重新开始）
Cache.OrgPartition orgPartition = Cache.Org.getPartition('local.BatchSyncCache');
if (orgPartition != null) {
    orgPartition.remove('CRM_PHKL_Enquiry_Last_Sync_Time');
    System.debug('Cache cleared');
}

// 2. 设置 Trace Flag（如果还没有设置�?
// 进入 Setup �?Debug Logs 手动设置

// 3. 执行批处�?
CRMGlobalEnquirySyncBatch batch = new CRMGlobalEnquirySyncBatch();
Id jobId = Database.executeBatch(batch, 1);
System.debug('Batch Job ID: ' + jobId);

// 4. 等待几秒后检查状�?
// （在 Developer Console 中等待，然后执行下面的代码）

// 5. 检查批处理状�?
AsyncApexJob job = [
    SELECT Id, Status, NumberOfErrors, JobItemsProcessed, 
           TotalJobItems, ExtendedStatus, ApexClass.Name
    FROM AsyncApexJob 
    WHERE Id = :jobId
    LIMIT 1
];

System.debug('=== Batch Status ===');
System.debug('Status: ' + job.Status);
System.debug('Processed: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
System.debug('Errors: ' + job.NumberOfErrors);
System.debug('Extended Status: ' + job.ExtendedStatus);

// 6. 检查创建的记录
List<Case> masterCases = [
    SELECT Id, Subject, RecordType.DeveloperName, CreatedDate
    FROM Case
    WHERE CreatedDate = TODAY
    AND RecordType.DeveloperName = 'Master_Inbound'
    ORDER BY CreatedDate DESC
    LIMIT 10
];
System.debug('Master Cases created: ' + masterCases.size());

List<Case> enquiryCases = [
    SELECT Id, Subject, ParentId, RecordType.DeveloperName, CreatedDate
    FROM Case
    WHERE CreatedDate = TODAY
    AND RecordType.DeveloperName = 'Enquiry'
    ORDER BY CreatedDate DESC
    LIMIT 10
];
System.debug('Enquiry Cases created: ' + enquiryCases.size());

// 7. 检查日�?
List<CRM_Global_ApexLog__c> logs = [
    SELECT Id, Name, Log_Level__c, Error_Message__c, CreatedDate
    FROM CRM_Global_ApexLog__c
    WHERE CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 10
];
System.debug('Recent Logs: ' + logs.size());

// 8. 检�?Platform Cache
if (orgPartition != null) {
    Object cachedTime = orgPartition.get('CRM_PHKL_Enquiry_Last_Sync_Time');
    if (cachedTime != null) {
        System.debug('Cached Sync Time: ' + cachedTime);
    }
}
```

## 10. 最佳实�?

1. **逐步调试**：先测试 API 调用，再测试数据处理
2. **使用小批�?*：调试时使用 `Database.executeBatch(batch, 1)` 便于追踪
3. **检查日�?*：同时查�?System.debug �?CRMGlobalLogManager 的日�?
4. **验证数据**：检查每个步骤创建的数据是否符合预期
5. **模拟错误**：测试异常情况，确保错误处理正确

