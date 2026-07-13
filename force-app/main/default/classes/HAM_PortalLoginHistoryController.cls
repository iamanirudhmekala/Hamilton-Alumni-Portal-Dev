public with sharing class HAM_PortalLoginHistoryController {

    public class LoginRow {
        @AuraEnabled public String rowKey;
        @AuraEnabled public String userName;
        @AuraEnabled public String contactName;
        @AuraEnabled public String email;
        @AuraEnabled public Datetime loginTime;
        @AuraEnabled public String status;
        @AuraEnabled public String sourceIp;
        @AuraEnabled public String application;
        @AuraEnabled public String browser;
        @AuraEnabled public String platform;
    }

    @AuraEnabled(cacheable=true)
    public static List<LoginRow> searchPortalLogins(String searchTerm, Integer days) {
        Integer lookback = (days == null || days <= 0) ? 180 : days;
        Datetime cutoff = Datetime.now().addDays(-lookback);
        // Blank search = the component's default view: all portal users combined.
        String term = searchTerm == null ? '' : searchTerm.trim();

        // Portal users = active User records with a populated ContactId.
        // Matched by name in Apex rather than a SOQL "Contact.Name LIKE" filter -
        // filtering on a parent-relationship field in the WHERE clause is unreliable
        // under Apex test data isolation (it can zero out the whole result set).
        Map<Id, User> portalUsers = new Map<Id, User>([
            SELECT Id, Name, Contact.Name, Contact.Email
            FROM User
            WHERE ContactId != null
              AND IsActive = true
        ]);

        Map<Id, User> matchingUsers = new Map<Id, User>();
        for (User u : portalUsers.values()) {
            if (String.isBlank(term)
                || matchesSearchTerm(u.Name, u.Contact != null ? u.Contact.Name : null, term)) {
                matchingUsers.put(u.Id, u);
            }
        }

        if (matchingUsers.isEmpty()) {
            return new List<LoginRow>();
        }

        List<LoginRow> rows = new List<LoginRow>();
        for (LoginHistory lh : [
            SELECT Id, UserId, LoginTime, Status, SourceIp,
                   Application, Browser, Platform
            FROM LoginHistory
            WHERE UserId IN :matchingUsers.keySet()
              AND LoginTime >= :cutoff
            ORDER BY LoginTime DESC
            LIMIT 5000
        ]) {
            User u = matchingUsers.get(lh.UserId);
            rows.add(buildRow(
                lh.Id,
                u.Name,
                u.Contact != null ? u.Contact.Name  : null,
                u.Contact != null ? u.Contact.Email : null,
                lh.LoginTime,
                lh.Status,
                lh.SourceIp,
                lh.Application,
                lh.Browser,
                lh.Platform
            ));
        }
        return rows;
    }

    @TestVisible
    private static Boolean matchesSearchTerm(String userName, String contactName, String term) {
        if (String.isBlank(term)) {
            return false;
        }
        String needle = term.toLowerCase();
        return (userName != null && userName.toLowerCase().contains(needle))
            || (contactName != null && contactName.toLowerCase().contains(needle));
    }

    // LoginHistory rows can't be inserted or reliably seeded in test context, so the
    // field-mapping logic is isolated here and exercised directly with synthetic data
    // rather than through the SOQL loop above.
    @TestVisible
    private static LoginRow buildRow(String rowKey, String userName, String contactName,
                                      String email, Datetime loginTime, String status,
                                      String sourceIp, String application, String browser,
                                      String platform) {
        LoginRow r = new LoginRow();
        r.rowKey      = rowKey;
        r.userName    = userName;
        r.contactName = contactName;
        r.email       = email;
        r.loginTime   = loginTime;
        r.status      = status;
        r.sourceIp    = sourceIp;
        r.application = application;
        r.browser     = browser;
        r.platform    = platform;
        return r;
    }
}