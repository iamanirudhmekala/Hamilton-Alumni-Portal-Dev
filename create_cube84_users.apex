// ============================================================
// Create 20 Contacts + Portal Users: Cube84 Test 1 – 20
// Contact fields populated to match QA dataset
// ============================================================

Id      accountId      = '001U100000e7VuxIAE';
Id      prmUserId      = '005VG00000cV1htYAC';
String  profileName    = 'Partner Community Login User';
String  contactEmail   = 'deepika.j@cube84.com';
String  usernameBase   = 'deepika';
String  usernameSuffix = '.j@cube84.com';
String  nicknameSuffix = '.m';
String  timezone       = 'America/New_York';
String  locale         = 'en_US';
String  language       = 'en_US';
String  encoding       = 'UTF-8';

String linkedInUrl = 'https://www.linkedin.com/in/cube84inc/';

// Step 1 — Resolve profile
Profile portalProfile;
try {
    portalProfile = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
    System.debug('Profile resolved: ' + portalProfile.Id);
} catch (Exception e) {
    System.debug('ERROR: Profile not found → ' + profileName);
    return;
}

// Step 2 — Resolve permission sets
Map<String, Id> psMap = new Map<String, Id>();
for (PermissionSet ps : [
    SELECT Id, Name FROM PermissionSet
    WHERE Name IN ('HAM_Partner_Community_Permission', 'HAM_Portal_Access_Internal')
]) {
    psMap.put(ps.Name, ps.Id);
}
System.debug('Permission sets found: ' + psMap.keySet());
if (psMap.size() < 2) {
    System.debug('WARNING: One or both permission sets not found. Check API names.');
}

// Step 3 — Create 20 Contacts with full field population
// Tweaked per user: Phone (last 4 digits), HAM_Reunion_Year__c (increments 1996→2015)
// All other fields held constant to match the QA dataset
List<Contact> contacts = new List<Contact>();
for (Integer i = 1; i <= 20; i++) {
    contacts.add(new Contact(
        // Core identity
        FirstName                                   = 'Cube84',
        LastName                                    = 'Test ' + i,
        Email                                       = contactEmail,
        Phone                                       = '(995) 995-' + String.valueOf(9900 + i),
        AccountId                                   = accountId,
        ucinn_ascendv2__PRM__c                      = prmUserId,

        // Boolean fields
        HAM_1812__c                                 = false,
        HAM_Chapel_Bell__c                          = false,
        HAM_Couper_Guild__c                         = false,
        HAM_Founders_Circle__c                      = true,
        HAM_Is_Active__c                            = true,
        HAM_JBA__c                                  = false,
        HAM_Show_PRM_Details__c                     = true,
        HAM_Ten_to_Fifth__c                         = false,
        Is_Volunteer__c                             = true,

        // Currency / Number fields
        HAM_Because_Hamilton__c                     = 6614198.8,
        HAM_Consecutive_Years_of_Giving__c          = 0,
        HAM_Current_Year_Hamilton_Fund_Collected__c = 40,
        HAM_Current_Yr_Hamilton_Fund_Fundraising__c = 20,
        HAM_FY00_Collect_Amt_Restricted__c          = 0,
        HAM_FY00_Committed_Ex_BQI_Amt_Restricted__c = 0,
        HAM_Lifetime_Committed__c                   = 10,
        HAM_Total_Years_of_Giving__c                = 3,

        // Year — increments per user: Test 1 → 1996, Test 2 → 1997 … Test 20 → 2015
        HAM_Reunion_Year__c                         = String.valueOf(1995 + i),

        // Text / Picklist fields
        HAM_Current_Chapters__c                     = 'Alabama, Alaska, Arizona, Connecticut (Hartford), Unassigned Chapter',
        HAM_Current_Regions__c                      = 'Anytown',
        HAM_Industry__c                             = 'Cube84',
        HAM_LiveAlumni_Employer__c                  = 'Test',
        HAM_LiveAlumni_Job_Title__c                 = 'Associate Director',
        Job_Title__c                                = 'Assoc Director',
        HAM_LiveAlumni_LinkedIn_URL__c              = linkedInUrl
    ));
}

try {
    insert contacts;
    System.debug('SUCCESS: Created ' + contacts.size() + ' contacts.');
} catch (DmlException e) {
    System.debug('ERROR creating contacts: ' + e.getMessage());
    return;
}

// Step 4 — Create Portal Users
List<User> usersToCreate = new List<User>();
for (Integer i = 0; i < contacts.size(); i++) {
    Integer num = i + 1;
    usersToCreate.add(new User(
        FirstName         = 'Cube84',
        LastName          = 'Test ' + num,
        Email             = contactEmail,
        Username          = usernameBase + num + usernameSuffix,
        CommunityNickname = usernameBase + num + nicknameSuffix,
        Alias             = ('d' + num).left(8),
        ContactId         = contacts[i].Id,
        ProfileId         = portalProfile.Id,
        TimeZoneSidKey    = timezone,
        LocaleSidKey      = locale,
        LanguageLocaleKey = language,
        EmailEncodingKey  = encoding,
        IsActive          = true
    ));
}

try {
    insert usersToCreate;
    System.debug('SUCCESS: Created ' + usersToCreate.size() + ' portal users.');
} catch (DmlException e) {
    System.debug('ERROR creating users: ' + e.getMessage());
    return;
}

// Step 5 — Assign permission sets (2 per user = 40 total)
List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
for (User u : usersToCreate) {
    for (String psName : new List<String>{
            'HAM_Partner_Community_Permission',
            'HAM_Portal_Access_Internal'}) {
        if (psMap.containsKey(psName)) {
            psas.add(new PermissionSetAssignment(
                AssigneeId      = u.Id,
                PermissionSetId = psMap.get(psName)
            ));
        }
    }
}

try {
    insert psas;
    System.debug('SUCCESS: Assigned ' + psas.size() + ' permission set assignments.');
} catch (DmlException e) {
    System.debug('ERROR assigning permission sets: ' + e.getMessage());
}

// Step 6 — Summary
System.debug('\n========== CREATION SUMMARY ==========');
for (Integer i = 0; i < usersToCreate.size(); i++) {
    System.debug(
        'Cube84 Test ' + (i+1) +
        ' | ReunionYear: ' + (1995 + (i+1)) +
        ' | Phone: (995) 995-' + String.valueOf(9900 + (i+1)) +
        ' | ContactId: ' + contacts[i].Id +
        ' | Username: ' + usersToCreate[i].Username +
        ' | UserId: ' + usersToCreate[i].Id
    );
}
System.debug('======================================');
