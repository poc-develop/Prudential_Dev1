/**
 * @description       : Scheduler for Enquiry Data Sync
 * @author            : hank
 * @group             : 
 * @last modified on  : 2025-10-28
 * @last modified by  : hank
**/
public class CRMPHKLEnquiryScheduler implements Schedulable {
    
    /**
     * 调度入口
     */
    public void execute(SchedulableContext sc) {
        // 启动批处理
        CRMPHKLEnquirySyncBatch batch = new CRMPHKLEnquirySyncBatch();
        Database.executeBatch(batch, 200);
    }
    
    /**
     * 配置定时任务
     * 在 Developer Console 或 Anonymous Apex 中执行一次即可
     */
    public static void scheduleJobs() {
        // 删除已存在的任务（如果有）
        List<CronTrigger> existingJobs = [
            SELECT Id, CronJobDetail.Name 
            FROM CronTrigger 
            WHERE CronJobDetail.Name LIKE 'Enquiry Sync%'
        ];
        
        for (CronTrigger job : existingJobs) {
            System.abortJob(job.Id);
        }
        
        // 配置每天 00:00 执行
        String cronExp1 = '0 0 0 * * ?';
        System.schedule('Enquiry Sync - Midnight', cronExp1, new CRMPHKLEnquiryScheduler());
        
        // 配置每天 16:00 执行
        String cronExp2 = '0 0 16 * * ?';
        System.schedule('Enquiry Sync - 4PM', cronExp2, new CRMPHKLEnquiryScheduler());
        
        System.debug('Scheduled jobs created successfully');
    }
}

