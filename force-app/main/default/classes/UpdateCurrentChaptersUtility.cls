public with sharing class UpdateCurrentChaptersUtility {
    @InvocableMethod(label='Build and Update Current Chapters & regions on Constituent')
    public static void updateCurrentChapterOnContact(List<Id> contacts) {
       set<ID> contactIds = new Set<ID>(contacts);
        // 4. Query ALL HAM_Current_Chapter__c records for these Contacts
        //    (pre-existing + newly inserted), ordered by chapter name for a sorted output.
        List<HAM_Current_Chapter__c> allChapterRecords = [
            SELECT
                Constituent__c,
                Chapter__r.Name,
                Region__c
            FROM HAM_Current_Chapter__c
            WHERE Constituent__c IN :contactIds
            AND Is_Active__c = TRUE
            ORDER BY Chapter__r.Name ASC
        ];

        // 5 & 6. Aggregate chapter names and collect unique region values per Contact.
        Map<Id, String> contactChapterStringMap = new Map<Id, String>();
        Map<Id, Set<String>> contactRegionSetMap = new Map<Id, Set<String>>();

        for (HAM_Current_Chapter__c hcc : allChapterRecords) {
            Id conId = hcc.Constituent__c;
            String chapterName = hcc.Chapter__r.Name;

            if (!contactChapterStringMap.containsKey(conId)) {
                contactChapterStringMap.put(conId, chapterName);
            } else {
                String existing = contactChapterStringMap.get(conId);
                if (!existing.contains(chapterName)) {
                    contactChapterStringMap.put(conId, existing + ', ' + chapterName);
                }
            }

            if (String.isNotBlank(hcc.Region__c)) {
                if (!contactRegionSetMap.containsKey(conId)) {
                    contactRegionSetMap.put(conId, new Set<String>{ hcc.Region__c });
                } else {
                    contactRegionSetMap.get(conId).add(hcc.Region__c);
                }
            }

            contactIds.remove(conId);
        }

        // 7. Build the Contact update list for Contacts that have chapter records.
        List<Contact> processedCons = new List<Contact>();

        for (Id contactId : contactChapterStringMap.keySet()) {
            String regionString = '';
            if (contactRegionSetMap.containsKey(contactId)) {
                regionString = String.join(new List<String>(contactRegionSetMap.get(contactId)), '; ');
            }
            processedCons.add(new Contact(
                Id                      = contactId,
                HAM_Current_Chapters__c = contactChapterStringMap.get(contactId),
                HAM_Current_Regions__c  = regionString
            ));
        }

        // Any Ids remaining in contactIds had no HAM_Current_Chapter__c records;
        // clear both fields explicitly.
        for (Id contactId : contactIds) {
            processedCons.add(new Contact(
                Id                      = contactId,
                HAM_Current_Chapters__c = '',
                HAM_Current_Regions__c  = ''
            ));
        }

        // 8. Single bulk DML for all affected Contacts.
        update processedCons;

        Results response = new Results();
        response.updatedContacts = processedCons;
    }

    // -------------------------------------------------------------------------
    // Output wrapper
    // -------------------------------------------------------------------------

    /**
     * @class   Results
     * @description Output wrapper exposed to the Flow via @InvocableVariable.
     *              Holds the list of Contact records updated by updateContacts()
     *              so that downstream Flow elements can reference the post-update
     *              state if needed (e.g. for logging or conditional branching).
     */
    public class Results {

        /**
         * The Contact records written during this invocation, each populated with
         * the new HAM_Current_Chapters__c value (or empty string if cleared).
         */
        @InvocableVariable(label='Updated Contacts Output')
        public List<Contact> updatedContacts;
    }
}