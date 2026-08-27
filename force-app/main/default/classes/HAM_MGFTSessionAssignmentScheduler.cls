/**
 * HAM_MGFTSessionAssignmentScheduler
 * -----------------------------------
 * Thin Schedulable wrapper around HAM_MGFTSessionAssignmentService.run().
 * Schedule it to fire once an hour.
 *
 * One-time setup — run this in Execute Anonymous (adjust the cron
 * expression's minute/second if you want a different :00 offset):
 *
 *   System.schedule(
 *       'HAM MGFT Session Assignment - Hourly',
 *       '0 0 * * * ?',
 *       new HAM_MGFTSessionAssignmentScheduler()
 *   );
 *
 * That cron expression fires at the top of every hour (00 seconds,
 * 00 minutes, every hour, every day). To remove/replace the job later,
 * check Setup > Scheduled Jobs, or run:
 *
 *   for (CronTrigger ct : [SELECT Id FROM CronTrigger
 *                          WHERE CronJobDetail.Name = 'HAM MGFT Session Assignment - Hourly']) {
 *       System.abortJob(ct.Id);
 *   }
 */
public class HAM_MGFTSessionAssignmentScheduler implements Schedulable {
    public void execute(SchedulableContext ctx) {
        HAM_MGFTSessionAssignmentService.run();
    }
}