/**
 * HAMPortalUserProvisioningBatch
 *
 * Batch entry point for bulk portal user provisioning.
 * Recommended batch size: 10–20 contacts per chunk.
 *
 * Usage:
 *   Database.executeBatch(
 *       new HAMPortalUserProvisioningBatch(contactIdList), 10
 *   );
 *
 * Transaction model per chunk:
 *   execute()  → Account UPDATE + validation                [sync]
 *              → System.enqueueJob(HAMProvisioningQueueable)
 *
 *   Queueable  → User INSERT + PSA INSERT + setPassword     [async]
 *              → Per-chunk result email
 *
 *   finish()   → Batch-run summary email
 *
 * Depends on: HAMPortalProvisioningDTO  (deploy that class first)
 */
public with sharing class HAMPortalUserProvisioningBatch
    implements Database.Batchable<Id>, Database.Stateful {

    private List<Id> contactIds;
    private Integer  totalSyncSuccess = 0;
    private Integer  totalSyncFailed  = 0;
    private Integer  totalChunks      = 0;

    public HAMPortalUserProvisioningBatch(List<Id> contactIds) {
        this.contactIds = contactIds;
    }

    public Iterable<Id> start(Database.BatchableContext bc) {
        return contactIds;
    }

    public void execute(Database.BatchableContext bc, List<Id> scope) {
        totalChunks++;

        HAMPortalProvisioningDTO.SyncPhaseOutcome outcome =
            HAMPortalUserProvisioningService.provisionUsers(scope, true);

        for (HAMPortalProvisioningDTO.ProvisioningResult r : outcome.results) {
            if (String.isBlank(r.errorMessage)) {
                totalSyncSuccess++;
            } else {
                totalSyncFailed++;
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            '=== Batch Complete ==='
            + ' Chunks: '      + totalChunks
            + ' | Queued: '    + totalSyncSuccess
            + ' | SyncFail: '  + totalSyncFailed
        );
        HAMPortalProvisioningDTO.sendBatchSummaryEmail(
            totalSyncSuccess,
            totalSyncFailed,
            totalChunks
        );
    }
}