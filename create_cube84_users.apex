// ============================================================
// Create 8 Internal Users: Cube84 Dev Team
// Profile: System Administrator (Salesforce license, implicit)
// Permission Set: HAM_Admin
// Run in Dev Console (Anonymous Apex) — QA and UAT
// ------------------------------------------------------------
// No Contacts: these are INTERNAL admin/dev users. User.ContactId
//   is only valid for community/portal users, so there is nothing
//   to link. (Single transaction — no mixed-DML concern.)
//
// IMPORTANT: Salesforce Usernames are globally unique across ALL orgs.
//   Set envSuffix ('.fullqa' / '.uat' / ...) before running so the same
//   file works in every sandbox. Email stays the real address.
// ============================================================

// ---------- Config ----------
String envSuffix   = '.fullqa';                // <-- CHANGE per environment ('.uat', etc.)
String profileName = 'System Administrator';
String timezone    = 'America/New_York';
String locale      = 'en_US';
String language    = 'en_US';
String encoding    = 'UTF-8';
List<String> permSetNames = new List<String>{ 'HAM_Admin' };

// ---------- People (base username = real email) ----------
// FirstName = everything before the last space; LastName = last word
List<String> firstNames = new List<String>{
    'Nilesh', 'Sachin Kumar', 'Immanuel', 'Arthiraja',
    'Feroz', 'Bhavani', 'Prathyusha', 'Deepika'
};
List<String> lastNames = new List<String>{
    'Mohokar', 'Sharma', 'Sirigiri', 'Govindan',
    'Basha', 'Sure', 'Mallemuru', 'Jogan'
};
List<String> usernameBases = new List<String>{
    'nilesh.m@cube84.com', 'sachin.s@cube84.com', 'immanuel.s@cube84.com', 'arthiraja.g@cube84.com',
    'feroz@cube84.com', 'bhavani.s@cube84.com', 'prathyusha.m@cube84.com', 'deepika.j@cube84.com'
};
Integer total = usernameBases.size();

// Step 1 — Resolve profile
Profile adminProfile;
try {
    adminProfile = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
    System.debug('Profile resolved: ' + profileName + ' → ' + adminProfile.Id);
} catch (Exception e) {
    System.debug('ERROR: Profile not found → ' + profileName);
    return;
}

// Step 2 — Resolve permission sets
Map<String, Id> psMap = new Map<String, Id>();
for (PermissionSet ps : [SELECT Id, Name FROM PermissionSet WHERE Name IN :permSetNames]) {
    psMap.put(ps.Name, ps.Id);
}
System.debug('Permission sets found: ' + psMap.keySet());
for (String psName : permSetNames) {
    if (!psMap.containsKey(psName)) {
        System.debug('WARNING: Permission set not found → ' + psName);
    }
}

// Step 3 — Create 8 internal Users (System Admin profile; NO ContactId on internal users)
List<User> usersToCreate = new List<User>();
Long nickSeed = Datetime.now().getTime();          // helps keep CommunityNickname unique per run
for (Integer i = 0; i < total; i++) {
    String firstNoSpace = firstNames[i].replaceAll('[^a-zA-Z0-9]', '');
    String alias    = (firstNames[i].left(1) + lastNames[i]).replaceAll('[^a-zA-Z0-9]', '').toLowerCase().left(8);
    String nickname = (firstNoSpace + lastNames[i]).toLowerCase() + String.valueOf(nickSeed + i);

    usersToCreate.add(new User(
        FirstName         = firstNames[i],
        LastName          = lastNames[i],
        Email             = usernameBases[i],            // real email
        Username          = usernameBases[i] + envSuffix,// globally-unique login
        CommunityNickname = nickname,
        Alias             = alias,
        ProfileId         = adminProfile.Id,
        TimeZoneSidKey    = timezone,
        LocaleSidKey      = locale,
        LanguageLocaleKey = language,
        EmailEncodingKey  = encoding,
        IsActive          = true
    ));
}
try {
    insert usersToCreate;
    System.debug('SUCCESS: Created ' + usersToCreate.size() + ' internal users.');
} catch (DmlException e) {
    System.debug('ERROR creating users: ' + e.getMessage());
    return;
}

// Step 4 — Assign permission sets (HAM_Admin). Same transaction as User is OK (both setup objects).
List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
for (User u : usersToCreate) {
    for (String psName : permSetNames) {
        if (psMap.containsKey(psName)) {
            psas.add(new PermissionSetAssignment(
                AssigneeId      = u.Id,
                PermissionSetId = psMap.get(psName)
            ));
        }
    }
}
try {
    if (!psas.isEmpty()) {
        insert psas;
        System.debug('SUCCESS: Assigned ' + psas.size() + ' permission set assignments.');
    } else {
        System.debug('WARNING: No permission set assignments created (none resolved).');
    }
} catch (DmlException e) {
    System.debug('ERROR assigning permission sets: ' + e.getMessage());
}

// Step 5 — Summary
System.debug('\n========== USER CREATION SUMMARY (env: ' + envSuffix + ') ==========');
for (Integer i = 0; i < usersToCreate.size(); i++) {
    System.debug(
        firstNames[i] + ' ' + lastNames[i] +
        ' | Username: ' + usersToCreate[i].Username +
        ' | Email: ' + usersToCreate[i].Email +
        ' | UserId: ' + usersToCreate[i].Id
    );
}
System.debug('PermSets assigned per user: ' + permSetNames);
System.debug('=====================================================');
