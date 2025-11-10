// ============================================
// 批处理 Debug 日志排查脚本
// 在 Developer Console 的 Anonymous Apex 中执行
// ============================================

System.debug('=== 开始排查批处理日志问题 ===');

// ===== 步骤 1: 检查 Trace Flag 设置 =====
System.debug('\n--- 步骤 1: 检查 Trace Flag ---');
List<TraceFlag> traceFlags = [
    SELECT Id, TracedEntityId, TracedEntity.Name, 
           ApexCode, ApexProfiling, System, Database,
           LogType, ExpirationDate, IsDeleted
    FROM TraceFlag
    WHERE TracedEntityId = :UserInfo.getUserId()
    AND IsDeleted = false
];

if (traceFlags.isEmpty()) {
    System.debug('❌ 没有找到 Trace Flag！');
    System.debug('请执行以下步骤：');
    System.debug('1. Setup → Debug Logs');
    System.debug('2. 点击 "New"');
    System.debug('3. Traced Entity Type: User');
    System.debug('4. Traced Entity: 选择你的用户');
    System.debug('5. Apex Code: DEBUG');
    System.debug('6. System: DEBUG');
    System.debug('7. 保存');
} else {
    System.debug('✓ 找到 ' + traceFlags.size() + ' 个 Trace Flag');
    for (TraceFlag tf : traceFlags) {
        System.debug('  - Entity: ' + tf.TracedEntity.Name);
        System.debug('    Apex Code: ' + tf.ApexCode);
        System.debug('    System: ' + tf.System);
        System.debug('    Expiration: ' + tf.ExpirationDate);
        
        if (tf.ApexCode != 'DEBUG' && tf.ApexCode != 'FINEST') {
            System.debug('    ⚠ Apex Code 级别可能不够，建议设置为 DEBUG');
        }
    }
}

// ===== 步骤 2: 检查批处理作业状态 =====
System.debug('\n--- 步骤 2: 检查最近的批处理作业 ---');
List<AsyncApexJob> recentJobs = [
    SELECT Id, Status, NumberOfErrors, JobItemsProcessed,
           TotalJobItems, CreatedDate, CompletedDate,
           ExtendedStatus, ApexClass.Name
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'CRMPHKLEnquirySyncBatch'
    ORDER BY CreatedDate DESC
    LIMIT 5
];

if (recentJobs.isEmpty()) {
    System.debug('⚠ 没有找到最近的批处理作业');
    System.debug('提示: 执行批处理后需要等待几分钟才能看到作业记录');
} else {
    System.debug('✓ 找到 ' + recentJobs.size() + ' 个最近的批处理作业');
    for (AsyncApexJob job : recentJobs) {
        System.debug('\n  Job ID: ' + job.Id);
        System.debug('  Status: ' + job.Status);
        System.debug('  Created: ' + job.CreatedDate);
        System.debug('  Completed: ' + job.CompletedDate);
        System.debug('  Processed: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
        System.debug('  Errors: ' + job.NumberOfErrors);
        System.debug('  Extended Status: ' + job.ExtendedStatus);
    }
}

// ===== 步骤 3: 查看最近的 Debug 日志 =====
System.debug('\n--- 步骤 3: 查看日志信息 ---');
System.debug('提示: 在 Developer Console 中：');
System.debug('1. 打开 Logs 标签');
System.debug('2. 查找时间戳在批处理作业创建时间之后的日志');
System.debug('3. 双击打开日志');
System.debug('4. 使用 Ctrl+F 搜索 "=== Batch" 或 "Execute Started"');

// ===== 步骤 4: 手动执行批处理并检查 =====
System.debug('\n--- 步骤 4: 执行新的批处理测试 ---');
System.debug('准备执行批处理...');

try {
    CRMPHKLEnquirySyncBatch batch = new CRMPHKLEnquirySyncBatch();
    Id jobId = Database.executeBatch(batch, 1);
    
    System.debug('✓ 批处理已提交');
    System.debug('Job ID: ' + jobId);
    System.debug('\n重要提示：');
    System.debug('1. 批处理是异步执行的，需要等待 10-60 秒');
    System.debug('2. 等待完成后，执行下面的代码查看状态');
    System.debug('3. 然后在 Developer Console → Logs 中查找对应的日志');
    
    // 等待几秒后检查
    System.debug('\n等待 30 秒后执行下面的代码来检查状态...');
    
} catch (Exception e) {
    System.debug('❌ 执行批处理失败: ' + e.getMessage());
    System.debug('Stack Trace: ' + e.getStackTraceString());
}

// ===== 步骤 5: 检查日志查看方法 =====
System.debug('\n--- 步骤 5: 如何查看批处理日志 ---');
System.debug('方法 1: Developer Console');
System.debug('  - 打开 Developer Console');
System.debug('  - 点击 "Logs" 标签');
System.debug('  - 查找最新的日志（根据时间戳）');
System.debug('  - 双击打开日志');
System.debug('  - 使用 Ctrl+F 搜索关键字：');
System.debug('    * "=== Batch Start Method Called"');
System.debug('    * "=== Execute Started ==="');
System.debug('    * "=== API Call Started ==="');
System.debug('    * "ERROR"');

System.debug('\n方法 2: Setup → Debug Logs');
System.debug('  - Setup → Debug Logs');
System.debug('  - 查看 "Apex Debug Logs"');
System.debug('  - 查找最近的日志条目');

System.debug('\n方法 3: Workbench');
System.debug('  - 访问 workbench.developerforce.com');
System.debug('  - Login → Debug → Debug Logs');
System.debug('  - 查看最近的日志');

// ===== 步骤 6: 验证日志级别 =====
System.debug('\n--- 步骤 6: 验证代码中的日志级别 ---');
System.debug('代码中使用的是: System.debug(LoggingLevel.INFO, ...)');
System.debug('Trace Flag 需要设置: Apex Code = DEBUG 或 FINEST');
System.debug('如果设置为 INFO 或 WARN，可能看不到某些日志');

System.debug('\n=== 排查完成 ===');
System.debug('如果仍然看不到日志，请检查：');
System.debug('1. Trace Flag 是否正确设置并已保存');
System.debug('2. Trace Flag 是否已过期');
System.debug('3. 是否在正确的组织环境中查看日志');
System.debug('4. 批处理作业是否真的执行了（检查 AsyncApexJob 状态）');

