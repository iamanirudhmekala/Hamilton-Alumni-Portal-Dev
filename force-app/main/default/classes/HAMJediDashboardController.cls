public with sharing class HAMJediDashboardController {

    @AuraEnabled(cacheable=true)
    public static String getUserPreferences() {
        User u = [
            SELECT HAM_JEDI_Dashboard_Preferences__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        return u.HAM_JEDI_Dashboard_Preferences__c;
    }

    @AuraEnabled
    public static void saveUserPreferences(String prefsJson) {
        User u = new User(
            Id = UserInfo.getUserId(),
            HAM_JEDI_Dashboard_Preferences__c = prefsJson
        );
        update u;
    }
}