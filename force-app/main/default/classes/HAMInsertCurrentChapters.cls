/**
 * @class       HAMInsertCurrentChapters
 * @description Batch job that creates HAM_Current_Chapter__c junction records for
 *              all historical qualifying Address Relations and then refreshes the
 *              HAM_Current_Chapters__c and HAM_Current_Regions__c text fields on
 *              the associated Contacts.
 *
 *              A qualifying Address Relation is one where:
 *                  1. HAM_Chapter__c is populated.
 *                  2. ucinn_ascendv2__Status__c equals 'Current'.
 *                  3. ucinn_ascendv2__Contact__c is populated.
 *
 *              Each HAM_Current_Chapter__c record is created with:
 *                  - Chapter__c    = AR's HAM_Chapter__c
 *                  - Constituent__c = Contact Id
 *                  - Is_Active__c  = true
 *                  - Source__c     = 'Address Update'
 *
 *              Deduplication (no double inserts) and all string aggregation are
 *              handled by ContactCurrentChaptersUtility.updateContacts(), which
 *              this batch delegates to in each chunk.
 *
 *              Recommended batch size: 50–100 (updateContacts issues multiple
 *              queries + up to 2 DML calls per execution, so keep chunk size
 *              conservative to stay within governor limits).
 *
 *              To run from Anonymous Apex:
 *                  Database.executeBatch(new HAMInsertCurrentChapters(), 50);
 *
 * @author      Hamilton College - Ameya
 * @version     1.0  2026-04-28  Initial implementation.
 */
public class HAMInsertCurrentChapters implements Database.Batchable<SObject> {

    // -------------------------------------------------------------------------
    // Batch interface
    // -------------------------------------------------------------------------

    /**
     * Scope: every Contact that has at least one qualifying Address Relation.
     * Scoping over Contacts (rather than ARs) ensures each Contact is processed
     * exactly once, preventing redundant updateContacts() calls within a run.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Contact
            WHERE Id IN (
                SELECT ucinn_ascendv2__Contact__c
                FROM ucinn_ascendv2__Address_Relation__c
                WHERE HAM_Chapter__c != ''
                  AND ucinn_ascendv2__Status__c = 'Current'
                  AND ucinn_ascendv2__Contact__c != null
            )
        ]);
    }

    /**
     * For each chunk of Contacts, delegates to updateContacts() which:
     *   1. Creates missing HAM_Current_Chapter__c records.
     *   2. Builds comma-separated chapter names → HAM_Current_Chapters__c.
     *   3. Builds semicolon-separated unique regions → HAM_Current_Regions__c.
     *   4. Updates the Contacts.
     */
    public void execute(Database.BatchableContext bc, List<Contact> scope) {
        Set<Id> contactIds = new Set<Id>();
        for (Contact c : scope) {
            contactIds.add(c.Id);
        }
        ContactCurrentChaptersUtility.updateContacts(contactIds);
    }

    public void finish(Database.BatchableContext bc) {}
}