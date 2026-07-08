/**
 * ============================================================
 * @class       HAMReceiptLineItemService
 * @description Invocable Apex service for creating HAM_Receipt_Line_Item__c
 *              records and updating PRM details on Receipt__c.
 *
 *              Exposes a single Flow-invocable entry point:
 *                1. createLineItems — Routes to the correct sub-method
 *                                     based on Request.receiptType:
 *                   - "Pledge Reminder" → createPaymentLineItems
 *                                         (Designation Detail-based + PRM update)
 *                   - All other types  → createReceiptLineItems
 *                                         (Hard/Soft Credit-based)
 *
 *              All SOQL is bulkified (no queries in loops).
 *              All DML is consolidated to a single operation per type.
 *              Maximum batch size: 200 Receipt records per invocation.
 *
 * ─────────────────────────────────────────────────────────────
 * Change Log
 * ─────────────────────────────────────────────────────────────
 * Version  Date          Author  Description
 * ───────  ────────────  ──────  ────────────────────────────────────────────
 * 1.0      [prior]       Me      Initial — Hard/Soft Credit line item creation
 * 1.1      2026-03-30    Me      Added createPaymentLineItems: Designation Detail
 *                                (Pledge) line item creation filtered by
 *                                Remaining_Amt_Same_Designation_Formula__c > 0.
 *                                Added updateReceiptPrmDetails: PRM User → Contact
 *                                email match → Receipt field update.
 *                                Refactored shared logic into private helper methods
 *                                for modularity and reuse.
 * 1.2      2026-03-30    Me      Consolidated to a single @InvocableMethod entry point
 *                                (createLineItems). Routes internally to
 *                                createPaymentLineItems or createReceiptLineItems
 *                                based on Request.receiptType field.
 *                                Added receiptType to Request wrapper.
 * ============================================================
 *
 * Routing Logic
 * ─────────────────────────────────────────────────────────────
 * Request.receiptType = "Pledge Reminder"
 *   └─► createPaymentLineItems  (Designation Detail, remaining balance > 0, + PRM update)
 * Request.receiptType = anything else / blank
 *   └─► createReceiptLineItems  (Hard/Soft Credit mapping)
 *
 * ─────────────────────────────────────────────────────────────
 * Objects & Fields Referenced
 * ─────────────────────────────────────────────────────────────
 * Receipt__c
 *   HAM_Credit_Line_Ids__c              — CSV of Credit/Opportunity Ids (input)
 *   PRM_ID__c                           — Id of the PRM User
 *   HAM_Email_of_PRM__c                 — PRM email (updated from Contact)
 *   PRM_Name__c                         — PRM name w/suffix (updated from Contact)
 *   HAM_Phone__c                        — PRM phone (updated from Contact)
 *   HAM_Job_title__c                    — PRM job title (updated from Contact)
 *
 * HAM_Receipt_Line_Item__c
 *   HAM_Receipt__c                      — Lookup: Receipt__c
 *   HAM_Hard_and_Soft_Credit__c         — Lookup: ucinn_ascendv2__Hard_and_Soft_Credit__c
 *   HAM_Designation__c                  — Lookup: ucinn_ascendv2__Designation__c
 *   HAM_Designation_Detail__c           — Lookup: ucinn_ascendv2__Designation_Detail__c
 *   HAM_Gift_Pledge__c                  — Lookup: Opportunity
 *   Amount__c                           — Currency (16,2)
 *   HAM_Amount_Paid_to_Date__c          — Currency (16,2)
 *   Remaining_Amount_due__c             — Currency (16,2)
 *
 * ucinn_ascendv2__Hard_and_Soft_Credit__c
 *   ucinn_ascendv2__Designation__c
 *   ucinn_ascendv2__Opportunity__c
 *   ucinn_ascendv2__Credit_Amount__c
 *
 * ucinn_ascendv2__Designation_Detail__c
 *   ucinn_ascendv2__Opportunity__c
 *   ucinn_ascendv2__Designation__c
 *   ucinn_ascendv2__Remaining_Amt_Same_Designation_Formula__c
 *   ucinn_ascendv2__Amt_Paid_to_Date_Same_Desig_Roll_Up__c
 *   HAM_Opportunity_Amount__c
 *
 * Contact
 *   Email, Phone, HAM_Name_w_Suffix__c, Job_Title__c
 *   ucinn_ascendv2__Contact_Type__c     — multipicklist, filter: INCLUDES 'Employee'
 * ============================================================
 */
public with sharing class HAMReceiptLineItemService {

    // ================================================================
    // CONSTANTS
    // ================================================================

    /** @description Receipt type value that triggers the Pledge Reminder / PRM flow. */
    private static final String RECEIPT_TYPE_PLEDGE_REMINDER = 'Pledge Reminder';


    // ================================================================
    // INNER CLASSES — Request / Response wrappers for Flow Invocables
    // ================================================================

    /**
     * @description Input wrapper for the Flow invocable entry point.
     *              receiptType drives internal routing:
     *                "Pledge Reminder" → Designation Detail flow + PRM update
     *                all other values  → Hard/Soft Credit flow
     */
    public class Request {
        @InvocableVariable(required=true)
        public Id receiptId;

        @InvocableVariable(required=true)
        public String creditIdsCsv;

        /** @description Receipt type (e.g. "Pledge Reminder", "Hard Credit"). Drives routing. */
        @InvocableVariable(required=true)
        public String receiptType;
    }

    /** @description Output wrapper returned to Flow after processing. */
    public class Response {
        @InvocableVariable public Id      receiptId;
        @InvocableVariable public Integer createdCount;
        @InvocableVariable public Integer skippedExistingCount;
        @InvocableVariable public Integer invalidIdCount;
        @InvocableVariable public String  errorMessage;
    }


    // ================================================================
    // SINGLE INVOCABLE ENTRY POINT — Routes by Receipt Type
    // ================================================================

    /**
     * @description Single Flow-invocable entry point.
     *              Splits the incoming request list by receiptType and routes:
     *                - "Pledge Reminder" requests → createPaymentLineItems
     *                - All other requests          → createReceiptLineItems
     *              Merges both result lists and returns them in original request order.
     *
     * @param  requests  List of Request (receiptId + creditIdsCsv + receiptType)
     * @return           List of Response with per-receipt tallies, in original order
     */
    @InvocableMethod(
        label='Create Receipt Line Items'
        description='Routes to Pledge Reminder (Designation Detail + PRM) or Hard/Soft Credit line item creation based on the receiptType field on each Request.'
    )
    public static List<Response> createLineItems(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return new List<Response>();
        }

        // ── Partition requests by type, preserving original index for result merge ──
        List<Request> pledgeRequests        = new List<Request>();
        List<Request> creditRequests        = new List<Request>();
        Map<Integer, Integer> pledgeIndexMap = new Map<Integer, Integer>(); // pledge list index → original index
        Map<Integer, Integer> creditIndexMap = new Map<Integer, Integer>(); // credit list index → original index

        for (Integer i = 0; i < requests.size(); i++) {
            Request req = requests[i];
            if (req != null && RECEIPT_TYPE_PLEDGE_REMINDER.equalsIgnoreCase(req.receiptType)) {
                pledgeIndexMap.put(pledgeRequests.size(), i);
                pledgeRequests.add(req);
            } else {
                creditIndexMap.put(creditRequests.size(), i);
                creditRequests.add(req);
            }
        }

        // ── Pre-size the results list with nulls to allow index-based placement ──
        List<Response> results = new List<Response>();
        for (Integer i = 0; i < requests.size(); i++) {
            results.add(null);
        }

        // ── Route pledge requests ─────────────────────────────────────
        if (!pledgeRequests.isEmpty()) {
            List<Response> pledgeResults = createPaymentLineItems(pledgeRequests);
            for (Integer i = 0; i < pledgeResults.size(); i++) {
                results.set(pledgeIndexMap.get(i), pledgeResults[i]);
            }
        }

        // ── Route credit requests ─────────────────────────────────────
        if (!creditRequests.isEmpty()) {
            List<Response> creditResults = createReceiptLineItems(creditRequests);
            for (Integer i = 0; i < creditResults.size(); i++) {
                results.set(creditIndexMap.get(i), creditResults[i]);
            }
        }

        return results;
    }


    // ================================================================
    // PRIVATE ROUTING TARGETS — not directly invocable from Flow
    // ================================================================

    /**
     * @description Creates HAM_Receipt_Line_Item__c records from Hard/Soft Credits.
     *              Called internally by createLineItems for non-Pledge-Reminder receipts.
     *
     * @param  requests  List of Request (receiptId + creditIdsCsv)
     * @return           List of Response with per-receipt tallies
     */
    private static List<Response> createReceiptLineItems(List<Request> requests) {
        List<Response> results = new List<Response>();

        // ── 1. Parse and aggregate all requests ──────────────────────
        Set<Id>          allReceiptIds      = new Set<Id>();
        Map<Id, Set<Id>> receiptToCreditIds = new Map<Id, Set<Id>>();
        Map<Id, Integer> invalidIdTally     = new Map<Id, Integer>();

        Set<Id> allCreditIds = aggregateRequests(
            requests, results, allReceiptIds, receiptToCreditIds, invalidIdTally
        );

        if (allCreditIds.isEmpty()) {
            return earlyReturn(results, invalidIdTally);
        }

        // ── 2. Query Hard/Soft Credits ────────────────────────────────
        Map<Id, ucinn_ascendv2__Hard_and_Soft_Credit__c> creditById =
            queryHardSoftCredits(allCreditIds);

        // ── 3. Guard: no valid credits found ─────────────────────────
        if (!hasAnyValidPairs(receiptToCreditIds, creditById.keySet())) {
            return earlyReturn(results, invalidIdTally);
        }

        // ── 4. Query existing line items (duplicate guard) ────────────
        Map<String, HAM_Receipt_Line_Item__c> existingPairs =
            queryExistingByCredit(allReceiptIds, allCreditIds);

        // ── 5. Build line items to insert ─────────────────────────────
        List<HAM_Receipt_Line_Item__c> toInsert   = new List<HAM_Receipt_Line_Item__c>();
        Map<Id, Integer>               createdTally = new Map<Id, Integer>();
        Map<Id, Integer>               skippedTally = new Map<Id, Integer>();

        for (Id receiptId : receiptToCreditIds.keySet()) {
            Integer created = 0;
            Integer skipped = 0;

            for (Id creditId : receiptToCreditIds.get(receiptId)) {
                ucinn_ascendv2__Hard_and_Soft_Credit__c credit = creditById.get(creditId);
                if (credit == null) {
                    continue; // not found — counted as invalid earlier
                }
                String key = makeKey(receiptId, creditId);
                if (existingPairs.containsKey(key)) {
                    skipped++;
                    continue;
                }
                toInsert.add(buildHardSoftCreditLineItem(receiptId, creditId, credit));
                created++;
            }

            createdTally.put(receiptId, created);
            skippedTally.put(receiptId, skipped);
        }

        // ── 6. DML insert + populate response ─────────────────────────
        return commitAndRespond(toInsert, results, createdTally, skippedTally, invalidIdTally);
    }


    /**
     * @description Creates HAM_Receipt_Line_Item__c records from Designation Details
     *              where Remaining_Amt_Same_Designation_Formula__c > 0.
     *              Also updates PRM contact details on each Receipt.
     *              Called internally by createLineItems for "Pledge Reminder" receipts.
     *
     * @param  requests  List of Request (receiptId + CSV of Opportunity Ids)
     * @return           List of Response with per-receipt tallies
     */
    private static List<Response> createPaymentLineItems(List<Request> requests) {
        List<Response> results = new List<Response>();

        // ── 1. Parse and aggregate all requests ──────────────────────
        Set<Id>          allReceiptIds      = new Set<Id>();
        Map<Id, Set<Id>> receiptToCreditIds = new Map<Id, Set<Id>>();
        Map<Id, Integer> invalidIdTally     = new Map<Id, Integer>();

        Set<Id> allCreditIds = aggregateRequests(
            requests, results, allReceiptIds, receiptToCreditIds, invalidIdTally
        );

        if (allCreditIds.isEmpty()) {
            return earlyReturn(results, invalidIdTally);
        }

        // ── 2. Validate Opportunity Ids ───────────────────────────────
        Set<Id> validOpportunityIds = queryValidOpportunityIds(allCreditIds);
        if (validOpportunityIds.isEmpty()) {
            return earlyReturn(results, invalidIdTally);
        }

        // ── 3. Query Designation Details (remaining balance > 0) ──────
        Map<Id, List<ucinn_ascendv2__Designation_Detail__c>> oppToDesigDetails =
            queryDesignationDetails(validOpportunityIds);
        if (oppToDesigDetails.isEmpty()) {
            return earlyReturn(results, invalidIdTally);
        }

        // ── 4. Query existing line items (duplicate guard) ────────────
        Set<Id> allDesigDetailIds = collectDesigDetailIds(oppToDesigDetails);
        Map<String, HAM_Receipt_Line_Item__c> existingPairs =
            queryExistingByDesigDetail(allReceiptIds, allDesigDetailIds);

        // ── 5. Build line items to insert ─────────────────────────────
        List<HAM_Receipt_Line_Item__c> toInsert   = new List<HAM_Receipt_Line_Item__c>();
        Map<Id, Integer>               createdTally = new Map<Id, Integer>();
        Map<Id, Integer>               skippedTally = new Map<Id, Integer>();

        for (Id receiptId : receiptToCreditIds.keySet()) {
            Integer created = 0;
            Integer skipped = 0;

            for (Id opportunityId : receiptToCreditIds.get(receiptId)) {
                if (!validOpportunityIds.contains(opportunityId)) {
                    continue;
                }
                if (!oppToDesigDetails.containsKey(opportunityId)) {
                    continue; // no qualifying designation details for this opportunity
                }

                for (ucinn_ascendv2__Designation_Detail__c dd : oppToDesigDetails.get(opportunityId)) {
                    String key = makeKey(receiptId, dd.Id);
                    if (existingPairs.containsKey(key)) {
                        skipped++;
                        continue;
                    }
                    toInsert.add(buildDesigDetailLineItem(receiptId, opportunityId, dd));
                    created++;
                }
            }

            createdTally.put(receiptId, created);
            skippedTally.put(receiptId, skipped);
        }

        // ── 6. DML insert + populate response ─────────────────────────
        List<Response> response = commitAndRespond(
            toInsert, results, createdTally, skippedTally, invalidIdTally
        );

        // ── 7. Update PRM details on Receipt records ──────────────────
        updateReceiptPrmDetails(allReceiptIds);

        return response;
    }


    // ================================================================
    // LINE ITEM BUILDERS — one method per line item "type"
    // ================================================================

    /**
     * @description Builds a HAM_Receipt_Line_Item__c from a Hard/Soft Credit.
     *
     * @param  receiptId  Receipt__c Id
     * @param  creditId   ucinn_ascendv2__Hard_and_Soft_Credit__c Id
     * @param  credit     Queried Hard/Soft Credit record
     * @return            Unsaved HAM_Receipt_Line_Item__c
     */
    private static HAM_Receipt_Line_Item__c buildHardSoftCreditLineItem(
        Id receiptId,
        Id creditId,
        ucinn_ascendv2__Hard_and_Soft_Credit__c credit
    ) {
        HAM_Receipt_Line_Item__c li = new HAM_Receipt_Line_Item__c();
        li.HAM_Receipt__c              = receiptId;
        li.HAM_Hard_and_Soft_Credit__c = creditId;
        li.HAM_Designation__c          = credit.ucinn_ascendv2__Designation__c;
        li.HAM_Gift_Pledge__c          = credit.ucinn_ascendv2__Opportunity__c;
        li.Amount__c                   = credit.ucinn_ascendv2__Credit_Amount__c;
        return li;
    }

    /**
     * @description Builds a HAM_Receipt_Line_Item__c from a Designation Detail (pledge).
     *
     * @param  receiptId     Receipt__c Id
     * @param  opportunityId Opportunity Id (pledge)
     * @param  dd            Queried Designation Detail record
     * @return               Unsaved HAM_Receipt_Line_Item__c
     */
    private static HAM_Receipt_Line_Item__c buildDesigDetailLineItem(
        Id receiptId,
        Id opportunityId,
        ucinn_ascendv2__Designation_Detail__c dd
    ) {
        HAM_Receipt_Line_Item__c li = new HAM_Receipt_Line_Item__c();
        li.HAM_Receipt__c             = receiptId;
        li.HAM_Gift_Pledge__c         = opportunityId;
        li.HAM_Designation__c         = dd.ucinn_ascendv2__Designation__c;
        li.HAM_Designation_Detail__c  = dd.Id;
        li.Amount__c                  = dd.HAM_Opportunity_Amount__c;
        li.HAM_Amount_Paid_to_Date__c = dd.ucinn_ascendv2__Amt_Paid_to_Date_Same_Desig_Roll_Up__c;
        li.Remaining_Amount_due__c    = dd.ucinn_ascendv2__Remaining_Amt_Same_Designation_Formula__c;
        return li;
    }


    // ================================================================
    // PRM UPDATE — Receipt.PRM_ID__c → User → Contact → Receipt fields
    // ================================================================

    /**
     * @description Resolves PRM details from Receipt.PRM_ID__c (User Id),
     *              matches that User's email to a Contact with Contact Type 'Employee',
     *              and updates the four PRM fields on the Receipt.
     *
     *              Steps:
     *                1. Query Receipts for PRM_ID__c
     *                2. Collect PRM User Ids
     *                3. Query Users for Email
     *                4. Collect User emails
     *                5. Query Contacts (email match + Employee type filter)
     *                6. Map Contact fields → Receipt PRM fields
     *                7. DML update Receipts
     *
     * @param  receiptIds  Set of Receipt__c Ids to process
     */
    private static void updateReceiptPrmDetails(Set<Id> receiptIds) {

        // Step 1 — Query Receipts that have a PRM User assigned
        Map<Id, Receipt__c> receiptById = queryReceiptsWithPrm(receiptIds);
        if (receiptById.isEmpty()) {
            return;
        }

        // Step 2 — Collect unique PRM User Ids
        Set<Id> prmUserIds = collectPrmUserIds(receiptById);

        // Step 3 — Query Users for their email addresses
        Map<Id, User> userById = queryPrmUsers(prmUserIds);
        if (userById.isEmpty()) {
            return;
        }

        // Step 4 — Collect PRM User emails
        Set<String> prmEmails = collectUserEmails(userById);

        // Step 5 — Query Contacts matching PRM email + 'Employee' Contact Type
        Map<String, Contact> contactByEmail = queryPrmContacts(prmEmails);
        if (contactByEmail.isEmpty()) {
            return;
        }

        // Step 6 — Map Contact fields onto Receipt PRM fields
        List<Receipt__c> toUpdate = buildReceiptPrmUpdates(receiptById, userById, contactByEmail);

        // Step 7 — DML: update Receipt records
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    // ── PRM sub-helpers ───────────────────────────────────────────────

    /** @description Queries Receipts with a non-null PRM_ID__c within the given Id set. */
    private static Map<Id, Receipt__c> queryReceiptsWithPrm(Set<Id> receiptIds) {
        Map<Id, Receipt__c> result = new Map<Id, Receipt__c>();
        // Fetch all receipts — including those with no PRM assigned
        for (Receipt__c r : [
            SELECT Id, PRM_ID__c
            FROM Receipt__c
            WHERE Id IN :receiptIds
        ]) {
            // Fall back to the org-configured default PRM if the field is blank
            if (r.PRM_ID__c == null) {
                r.PRM_ID__c = (Id) Label.Default_PRM_For_Pledge;
            }
            result.put(r.Id, r);
        }
        return result;
    }

    /** @description Collects unique PRM User Ids from a map of Receipt records. */
    private static Set<Id> collectPrmUserIds(Map<Id, Receipt__c> receiptById) {
        Set<Id> prmUserIds = new Set<Id>();
        for (Receipt__c r : receiptById.values()) {
            prmUserIds.add((Id) r.PRM_ID__c);
        }
        return prmUserIds;
    }

    /** @description Queries Users by Id, returning only those with a non-null Email. */
    private static Map<Id, User> queryPrmUsers(Set<Id> userIds) {
        Map<Id, User> result = new Map<Id, User>();
        for (User u : [
            SELECT Id, Email
            FROM User
            WHERE Id IN :userIds
              AND Email != null
        ]) {
            result.put(u.Id, u);
        }
        return result;
    }

    /** @description Collects the email addresses from a map of User records. */
    private static Set<String> collectUserEmails(Map<Id, User> userById) {
        Set<String> emails = new Set<String>();
        for (User u : userById.values()) {
            emails.add(u.Email);
        }
        return emails;
    }

    /**
     * @description Queries Contacts whose Email matches a PRM User email
     *              and whose Contact Type includes 'Employee'.
     *              Returns a map keyed by Email (first match per email wins).
     */
    private static Map<String, Contact> queryPrmContacts(Set<String> emails) {
        Map<String, Contact> result = new Map<String, Contact>();
        for (Contact c : [
            SELECT Id,
                   Email,
                   HAM_Name_w_Suffix__c,
                   Job_Title__c,
                   Phone
            FROM Contact
            WHERE Email IN :emails
              AND ucinn_ascendv2__Contact_Type__c INCLUDES ('Employee')
        ]) {
            if (!result.containsKey(c.Email)) {
                result.put(c.Email, c); // first match per email wins
            }
        }
        return result;
    }

    /**
     * @description Builds Receipt update stubs by walking:
     *              Receipt → PRM User (via PRM_ID__c) → Contact (via email match).
     *              Maps four PRM fields onto each Receipt stub.
     */
    private static List<Receipt__c> buildReceiptPrmUpdates(
        Map<Id, Receipt__c>  receiptById,
        Map<Id, User>        userById,
        Map<String, Contact> contactByEmail
    ) {
        List<Receipt__c> toUpdate = new List<Receipt__c>();

        for (Receipt__c r : receiptById.values()) {
            User prmUser = userById.get((Id) r.PRM_ID__c);
            if (prmUser == null) {
                continue;
            }
            Contact prmContact = contactByEmail.get(prmUser.Email);
            if (prmContact == null) {
                continue;
            }

            Receipt__c stub          = new Receipt__c(Id = r.Id);
            stub.HAM_Email_of_PRM__c = prmContact.Email;
            stub.PRM_Name__c         = prmContact.HAM_Name_w_Suffix__c;
            stub.HAM_Phone__c        = prmContact.Phone;
            stub.HAM_Job_title__c    = prmContact.Job_Title__c;
            toUpdate.add(stub);
        }

        return toUpdate;
    }


    // ================================================================
    // SHARED REQUEST AGGREGATION
    // ================================================================

    /**
     * @description Iterates all requests, initialises Response stubs, and populates
     *              the receipt/credit maps and invalid Id tallies.
     *
     * @param  requests           Input request list
     * @param  results            Response list to populate (modified in place)
     * @param  allReceiptIds      Set to populate with valid Receipt Ids
     * @param  receiptToCreditIds Map to populate: Receipt Id → Set of Credit Ids
     * @param  invalidIdTally     Map to populate: Receipt Id → invalid Id count
     * @return                    Flat set of all parsed Credit/Opportunity Ids
     */
    private static Set<Id> aggregateRequests(
        List<Request>    requests,
        List<Response>   results,
        Set<Id>          allReceiptIds,
        Map<Id, Set<Id>> receiptToCreditIds,
        Map<Id, Integer> invalidIdTally
    ) {
        Set<Id> allCreditIds = new Set<Id>();

        for (Request req : requests) {
            Response res          = new Response();
            res.receiptId         = req != null ? req.receiptId : null;
            res.createdCount      = 0;
            res.skippedExistingCount = 0;
            res.invalidIdCount    = 0;
            results.add(res);

            if (req == null || req.receiptId == null) {
                res.errorMessage = 'Missing receiptId.';
                continue;
            }
            allReceiptIds.add(req.receiptId);

            Set<Id>  parsedIds    = new Set<Id>();
            Integer  invalidCount = parseCreditIdCsv(req.creditIdsCsv, parsedIds);

            receiptToCreditIds.put(req.receiptId, parsedIds);
            invalidIdTally.put(req.receiptId, invalidCount);
            allCreditIds.addAll(parsedIds);
        }

        return allCreditIds;
    }

    /**
     * @description Parses a comma-separated string of Salesforce Ids.
     *              Tokens must be 15 or 18 characters and coercible to Id type.
     *
     * @param  csv       Raw CSV string from the request
     * @param  parsedIds Set to populate with valid Ids (modified in place)
     * @return           Count of invalid/unparseable tokens
     */
    private static Integer parseCreditIdCsv(String csv, Set<Id> parsedIds) {
        Integer invalidCount = 0;
        if (String.isBlank(csv)) {
            return invalidCount;
        }
        for (String token : csv.split('\\s*,\\s*')) {
            if (String.isBlank(token)) {
                continue;
            }
            String t = token.trim();
            if (t.length() == 15 || t.length() == 18) {
                try {
                    parsedIds.add((Id) t);
                } catch (Exception e) {
                    invalidCount++;
                }
            } else {
                invalidCount++;
            }
        }
        return invalidCount;
    }


    // ================================================================
    // SHARED EARLY-RETURN / DML HELPERS
    // ================================================================

    /**
     * @description Stamps invalidIdCount on all Response stubs and returns the list.
     *              Used for all early-exit paths before any DML is attempted.
     */
    private static List<Response> earlyReturn(
        List<Response>   results,
        Map<Id, Integer> invalidIdTally
    ) {
        for (Response res : results) {
            if (res.receiptId != null) {
                res.invalidIdCount = invalidIdTally.get(res.receiptId);
            }
        }
        return results;
    }

    /**
     * @description Performs the insert DML and populates final Response tallies.
     *              On DmlException, sets errorMessage on all Response stubs.
     *
     * @param  toInsert       Line items to insert
     * @param  results        Response list to finalise
     * @param  createdTally   Per-receipt created count
     * @param  skippedTally   Per-receipt skipped count
     * @param  invalidIdTally Per-receipt invalid Id count
     * @return                Finalised Response list
     */
    private static List<Response> commitAndRespond(
        List<HAM_Receipt_Line_Item__c> toInsert,
        List<Response>                 results,
        Map<Id, Integer>               createdTally,
        Map<Id, Integer>               skippedTally,
        Map<Id, Integer>               invalidIdTally
    ) {
        try {
            if (!toInsert.isEmpty()) {
                insert toInsert;
            }
        } catch (DmlException d) {
            for (Response res : results) {
                res.errorMessage         = 'Failed to insert line items: ' + d.getMessage();
                res.createdCount         = 0;
                res.skippedExistingCount = skippedTally.get(res.receiptId);
                res.invalidIdCount       = invalidIdTally.get(res.receiptId);
            }
            return results;
        }

        for (Response res : results) {
            res.createdCount         = createdTally.get(res.receiptId);
            res.skippedExistingCount = skippedTally.get(res.receiptId);
            res.invalidIdCount       = invalidIdTally.get(res.receiptId);
        }
        return results;
    }

    /**
     * @description Returns a consistent pipe-delimited composite key for duplicate checks.
     *
     * @param  leftId   First Id component (typically Receipt Id)
     * @param  rightId  Second Id component (Credit or Designation Detail Id)
     * @return          Composite key string
     */
    private static String makeKey(Id leftId, Id rightId) {
        return leftId + '|' + rightId;
    }


    // ================================================================
    // SHARED GUARD UTILITIES
    // ================================================================

    /**
     * @description Returns true if at least one valid Credit/Detail Id exists
     *              across all receipts. Avoids an unnecessary duplicate-check
     *              SOQL when there is nothing to insert.
     *
     * @param  receiptToCreditIds  Parsed receipt → credit Id map
     * @param  validIds            Set of Ids confirmed to exist in the org
     * @return                     True if any receipt has at least one valid Id
     */
    private static Boolean hasAnyValidPairs(
        Map<Id, Set<Id>> receiptToCreditIds,
        Set<Id>          validIds
    ) {
        for (Set<Id> creditIds : receiptToCreditIds.values()) {
            for (Id cId : creditIds) {
                if (validIds.contains(cId)) {
                    return true;
                }
            }
        }
        return false;
    }


    // ================================================================
    // SOQL QUERY HELPERS — one method per object / query pattern
    // ================================================================

    /** @description Queries Hard/Soft Credits by Id. */
    private static Map<Id, ucinn_ascendv2__Hard_and_Soft_Credit__c> queryHardSoftCredits(
        Set<Id> ids
    ) {
        Map<Id, ucinn_ascendv2__Hard_and_Soft_Credit__c> result =
            new Map<Id, ucinn_ascendv2__Hard_and_Soft_Credit__c>();
        for (ucinn_ascendv2__Hard_and_Soft_Credit__c c : [
            SELECT Id,
                   ucinn_ascendv2__Designation__c,
                   ucinn_ascendv2__Opportunity__c,
                   ucinn_ascendv2__Credit_Amount__c
            FROM ucinn_ascendv2__Hard_and_Soft_Credit__c
            WHERE Id IN :ids
        ]) {
            result.put(c.Id, c);
        }
        return result;
    }

    /** @description Validates that the provided Ids are real Opportunity records. */
    private static Set<Id> queryValidOpportunityIds(Set<Id> ids) {
        Set<Id> valid = new Set<Id>();
        for (Opportunity o : [
            SELECT Id
            FROM Opportunity
            WHERE Id IN :ids
        ]) {
            valid.add(o.Id);
        }
        return valid;
    }

    /**
     * @description Queries Designation Details for a set of Opportunities,
     *              filtered to only those with Remaining_Amt_Same_Designation > 0.
     *              Returns a map of Opportunity Id → list of Designation Details.
     */
    private static Map<Id, List<ucinn_ascendv2__Designation_Detail__c>> queryDesignationDetails(
        Set<Id> opportunityIds
    ) {
        Map<Id, List<ucinn_ascendv2__Designation_Detail__c>> result =
            new Map<Id, List<ucinn_ascendv2__Designation_Detail__c>>();

        for (ucinn_ascendv2__Designation_Detail__c dd : [
            SELECT Id,
                   ucinn_ascendv2__Designation__c,
                   ucinn_ascendv2__Opportunity__c,
                   ucinn_ascendv2__Remaining_Amt_Same_Designation_Formula__c,
                   ucinn_ascendv2__Amt_Paid_to_Date_Same_Desig_Roll_Up__c,
                   HAM_Opportunity_Amount__c
            FROM ucinn_ascendv2__Designation_Detail__c
            WHERE ucinn_ascendv2__Opportunity__c IN :opportunityIds
              AND ucinn_ascendv2__Remaining_Amt_Same_Designation_Formula__c > 0
        ]) {
            Id oppId = dd.ucinn_ascendv2__Opportunity__c;
            if (!result.containsKey(oppId)) {
                result.put(oppId, new List<ucinn_ascendv2__Designation_Detail__c>());
            }
            result.get(oppId).add(dd);
        }

        return result;
    }

    /**
     * @description Flattens an Opportunity → Designation Detail list map
     *              into a single Set of Designation Detail Ids.
     */
    private static Set<Id> collectDesigDetailIds(
        Map<Id, List<ucinn_ascendv2__Designation_Detail__c>> oppToDesigDetails
    ) {
        Set<Id> ids = new Set<Id>();
        for (List<ucinn_ascendv2__Designation_Detail__c> ddList : oppToDesigDetails.values()) {
            for (ucinn_ascendv2__Designation_Detail__c dd : ddList) {
                ids.add(dd.Id);
            }
        }
        return ids;
    }

    /**
     * @description Queries existing line items keyed by Receipt + Hard/Soft Credit
     *              to prevent duplicate inserts.
     */
    private static Map<String, HAM_Receipt_Line_Item__c> queryExistingByCredit(
        Set<Id> receiptIds,
        Set<Id> creditIds
    ) {
        Map<String, HAM_Receipt_Line_Item__c> existing = new Map<String, HAM_Receipt_Line_Item__c>();
        for (HAM_Receipt_Line_Item__c li : [
            SELECT Id, HAM_Receipt__c, HAM_Hard_and_Soft_Credit__c
            FROM HAM_Receipt_Line_Item__c
            WHERE HAM_Receipt__c                IN :receiptIds
              AND HAM_Hard_and_Soft_Credit__c   IN :creditIds
        ]) {
            existing.put(makeKey(li.HAM_Receipt__c, li.HAM_Hard_and_Soft_Credit__c), li);
        }
        return existing;
    }

    /**
     * @description Queries existing line items keyed by Receipt + Designation Detail
     *              to prevent duplicate inserts.
     */
    private static Map<String, HAM_Receipt_Line_Item__c> queryExistingByDesigDetail(
        Set<Id> receiptIds,
        Set<Id> desigDetailIds
    ) {
        Map<String, HAM_Receipt_Line_Item__c> existing = new Map<String, HAM_Receipt_Line_Item__c>();
        for (HAM_Receipt_Line_Item__c li : [
            SELECT Id, HAM_Receipt__c, HAM_Designation_Detail__c
            FROM HAM_Receipt_Line_Item__c
            WHERE HAM_Receipt__c             IN :receiptIds
              AND HAM_Designation_Detail__c  IN :desigDetailIds
        ]) {
            existing.put(makeKey(li.HAM_Receipt__c, li.HAM_Designation_Detail__c), li);
        }
        return existing;
    }
}