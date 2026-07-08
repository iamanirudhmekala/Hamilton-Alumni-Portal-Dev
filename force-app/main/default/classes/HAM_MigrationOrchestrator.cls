/**
 * HAM_MigrationOrchestrator
 * ─────────────────────────────────────────────────────────────────────────────
 * Schedulable entry point for the Blackthorn → Cvent migration pipeline.
 * Accepts a date range and fires HAM_EventMigrationBatch, which chains all
 * subsequent child batches via their respective finish() methods.
 *
 * SCHEDULING — run from Developer Console (Anonymous Apex):
 *
 *   // Iteration 1: Jan 2024 – Feb 2026
 *   System.schedule(
 *       'HAM Migration Iter 1',
 *       '0 0 2 * * ?',
 *       new HAM_MigrationOrchestrator(
 *           Date.newInstance(2024, 1, 1),
 *           Date.newInstance(2026, 2, 28)
 *       )
 *   );
 *
 *   // Iteration 2: Mar 2026 – Apr 2026
 *   System.schedule(
 *       'HAM Migration Iter 2',
 *       '0 0 2 * * ?',
 *       new HAM_MigrationOrchestrator(
 *           Date.newInstance(2026, 3, 1),
 *           Date.newInstance(2026, 4, 30)
 *       )
 *   );
 *
 *   // Immediate execution (no schedule):
 *   Database.executeBatch(
 *       new HAM_EventMigrationBatch(
 *           Date.newInstance(2024, 1, 1),
 *           Date.newInstance(2026, 2, 28)
 *       ), 200
 *   );
 *
 *   // Abort a scheduled job:
 *   CronTrigger ct = [SELECT Id FROM CronTrigger
 *                     WHERE CronJobDetail.Name = 'HAM Migration Iter 1'];
 *   System.abortJob(ct.Id);
 *
 * Change Log:
 *   v1.0  2026-04-09  Initial deployment
 *   v1.1  2026-04-14  PMD static analysis fixes
 * @description Schedulable orchestrator that launches the HAM migration batch pipeline for a given date range.
 */
public without sharing class HAM_MigrationOrchestrator implements Schedulable {

    private Date rangeStart;
    private Date rangeEnd;

    /**
     * @description Constructor — pass the inclusive date range for this migration iteration.
     * @param startDate Start of date range (inclusive)
     * @param endDate   End of date range (inclusive)
     */
    public HAM_MigrationOrchestrator(Date startDate, Date endDate) {
        this.rangeStart = startDate;
        this.rangeEnd   = endDate;
    }

    /**
     * @description Schedulable entry point. Fires HAM_EventMigrationBatch with the date range.
     * @param sc SchedulableContext
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(
            new HAM_EventMigrationBatch(rangeStart, rangeEnd),
            200
        );
    }
}