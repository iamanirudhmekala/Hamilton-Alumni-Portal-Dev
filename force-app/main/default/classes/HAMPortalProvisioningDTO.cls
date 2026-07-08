/**
 * HAMPortalProvisioningDTO
 *
 * Shared data-transfer objects and utility methods for the portal user
 * provisioning framework.  Kept in a standalone class so that
 * HAMPortalUserProvisioningService, HAMProvisioningQueueable, and
 * HAMPortalUserProvisioningBatch can all reference these types without
 * creating circular compile-time dependencies.
 *
 * Deploy this class FIRST before the other three.
 */
public with sharing class HAMPortalProvisioningDTO {

    // ── FullQA-confirmed constants ─────────────────────────────────────────
    public static final String PROFILE_NAME     = 'Partner Community Login User';
    public static final String PERM_SET_PARTNER = 'HAM_Partner_Community_Permission';
    public static final String PERM_SET_STRIPE  = 'Stripe_Permissions';

    public static final List<String> NOTIFY_EMAILS = new List<String>{
        'awadke@hamilton.edu',
        'nvaidya@hamilton.edu'
    };

    // ── Result object (returned to callers + used for email reporting) ─────
    public class ProvisioningResult {
        public Id      contactId;
        public String  contactName;
        public String  contactEmail;
        public Id      userId;
        public Boolean success;
        public String  errorMessage;
        public Boolean accountWasUpdated;

        public ProvisioningResult(Id contactId) {
            this.contactId         = contactId;
            this.success           = false;
            this.accountWasUpdated = false;
        }
    }

    // ── Payload serialised into the Queueable ─────────────────────────────
    // Must be a top-level inner class (not nested inside another inner class)
    // so JSON.deserialize() can resolve the type across class boundaries.
    public class ContactPayload {
        public Id      contactId;
        public String  firstName;
        public String  lastName;
        public String  email;
        public Id      accountId;
        public String  generatedPassword;
        public Boolean accountWasUpdated;
    }

    // ── Outcome returned from the sync phase to the batch class ───────────
    public class SyncPhaseOutcome {
        public List<ProvisioningResult> results;
        public List<ContactPayload>     payloads;
    }

    // ══════════════════════════════════════════════════════════════════════
    // PASSWORD HELPERS
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Generates a cryptographically random password between 8 and 12
     * characters satisfying Salesforce's default complexity policy:
     *   - At least one uppercase letter
     *   - At least one lowercase letter
     *   - At least one digit
     *   - At least one special character
     *
     * Uses Crypto.getRandomInteger() (CSPRNG).
     * Excludes visually ambiguous chars (0, 1, I, O, l).
     */
    @TestVisible
    public static String generatePassword() {
        final String UPPER   = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
        final String LOWER   = 'abcdefghjkmnpqrstuvwxyz';
        final String DIGITS  = '23456789';
        final String SPECIAL = '!@#$%^&*()-_=+[]{}';
        final String ALL     = UPPER + LOWER + DIGITS + SPECIAL;

        Integer length = 8 + Math.mod(Math.abs(Crypto.getRandomInteger()), 5);

        List<String> chars = new List<String>();
        chars.add(pickRandom(UPPER));
        chars.add(pickRandom(LOWER));
        chars.add(pickRandom(DIGITS));
        chars.add(pickRandom(SPECIAL));

        for (Integer i = 4; i < length; i++) {
            chars.add(pickRandom(ALL));
        }

        // Fisher-Yates shuffle
        for (Integer i = chars.size() - 1; i > 0; i--) {
            Integer j    = Math.mod(Math.abs(Crypto.getRandomInteger()), i + 1);
            String  tmp  = chars[i];
            chars[i]     = chars[j];
            chars[j]     = tmp;
        }

        return String.join(chars, '');
    }

    public static String pickRandom(String alphabet) {
        Integer idx = Math.mod(
            Math.abs(Crypto.getRandomInteger()), alphabet.length()
        );
        return alphabet.substring(idx, idx + 1);
    }

    // ══════════════════════════════════════════════════════════════════════
    // STRING HELPERS
    // ══════════════════════════════════════════════════════════════════════

    public static String buildAlias(
        String firstName, String lastName, Id contactId
    ) {
        String raw = '';
        if (String.isNotBlank(firstName)) raw += firstName.left(1);
        raw += (String.isNotBlank(lastName) ? lastName : 'User');
        return raw.replaceAll('[^a-zA-Z0-9]', '').left(8).toLowerCase();
    }

    public static String buildNickname(
        String firstName, String lastName, Id contactId
    ) {
        String base = buildAlias(firstName, lastName, contactId)
            + String.valueOf(Math.abs(Math.mod(contactId.hashCode(), 9999)));
        return base.left(40);
    }

    // ══════════════════════════════════════════════════════════════════════
    // EMAIL HELPERS
    // ══════════════════════════════════════════════════════════════════════

    public static void sendSyncFailureEmail(List<ProvisioningResult> results) {
        List<String> failLines = new List<String>();
        for (ProvisioningResult r : results) {
            String label = labelFor(r);
            failLines.add('✗ ' + label + ' → ' + r.errorMessage);
        }

        String subject = 'Portal Provisioning — Pre-flight Failures ('
            + results.size() + ') — ' + System.today().format();

        String body = 'Portal User Provisioning — Pre-flight Failures\n'
            + '===============================================\n'
            + 'Date: '            + System.now().format() + '\n'
            + 'Failed Contacts: ' + results.size()        + '\n\n'
            + '── FAILURES ──\n'
            + String.join(failLines, '\n') + '\n\n'
            + 'These contacts were excluded before the Queueable was dispatched.\n';

        sendEmail(subject, body);
    }

    public static void sendResultEmail(List<ProvisioningResult> results) {
        Integer      successCount = 0;
        Integer      failCount    = 0;
        List<String> successLines = new List<String>();
        List<String> failLines    = new List<String>();

        for (ProvisioningResult r : results) {
            String label = labelFor(r);
            if (r.success) {
                successCount++;
                String line = '✓ ' + label + ' → User Id: ' + r.userId;
                if (r.accountWasUpdated) {
                    line += ' [Account IsPartner auto-set to TRUE]';
                }
                successLines.add(line);
            } else {
                failCount++;
                failLines.add('✗ ' + label + ' → ' + r.errorMessage);
            }
        }

        String subject = 'Portal User Provisioning: '
            + successCount + ' created, '
            + failCount    + ' failed — '
            + System.today().format();

        String body = 'Portal User Provisioning Job Summary\n'
            + '=====================================\n'
            + 'Date: '                 + System.now().format() + '\n'
            + 'Total Processed: '      + results.size()        + '\n'
            + 'Successfully Created: ' + successCount          + '\n'
            + 'Failed: '               + failCount             + '\n\n';

        if (!successLines.isEmpty()) {
            body += '── SUCCESSES ──\n'
                + String.join(successLines, '\n') + '\n\n';
        }
        if (!failLines.isEmpty()) {
            body += '── FAILURES ──\n'
                + String.join(failLines, '\n') + '\n\n';
        }

        body += 'Note: Passwords were set silently. '
            + 'No password-reset email was sent to users.\n';

        sendEmail(subject, body);
    }

    public static void sendBatchSummaryEmail(
        Integer totalSuccess,
        Integer totalFailed,
        Integer totalChunks
    ) {
        String subject = 'Portal Provisioning Batch Complete: '
            + totalSuccess + ' queued, '
            + totalFailed  + ' failed (sync) — '
            + System.today().format();

        String body = 'Portal User Provisioning — Batch Run Summary\n'
            + '============================================\n'
            + 'Date: '                  + System.now().format() + '\n'
            + 'Total Batch Chunks: '    + totalChunks           + '\n'
            + 'Passed to Queueable: '   + totalSuccess          + '\n'
            + 'Failed (sync phase): '   + totalFailed           + '\n\n'
            + 'Per-chunk provisioning detail was emailed as each Queueable completed.\n';

        sendEmail(subject, body);
    }

    // ── Internal helpers ───────────────────────────────────────────────────

    private static String labelFor(ProvisioningResult r) {
        String label = r.contactName != null
            ? r.contactName : String.valueOf(r.contactId);
        if (r.contactEmail != null) label += ' (' + r.contactEmail + ')';
        return label;
    }

    public static void sendEmail(String subject, String body) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(NOTIFY_EMAILS);
        mail.setSubject(subject);
        mail.setPlainTextBody(body);
        mail.setSaveAsActivity(false);

        if (!Test.isRunningTest()) {
            Messaging.sendEmail(
                new List<Messaging.SingleEmailMessage>{ mail }
            );
        }
    }
}