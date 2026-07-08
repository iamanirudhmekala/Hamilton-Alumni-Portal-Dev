// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents

// Anonymous Apex to debug profile pic privacy toggle

// 1. Get a Contact Id (adjust query if needed)
Contact c = [SELECT Id, Name FROM Contact LIMIT 1];
System.debug('Using Contact: ' + c.Name + ' (' + c.Id + ')');

// 2. Check if SIV record exists
List<ucinn_ascendv2__Service_Indicator_Value__c> sivList = [
    SELECT Id, Name, HAM_Portal_ID__c 
    FROM ucinn_ascendv2__Service_Indicator_Value__c 
    WHERE HAM_Portal_ID__c = 'SIV_VIS_PROFILE_PIC'
];
System.debug('SIV Records found: ' + sivList.size());
if(!sivList.isEmpty()) {
    System.debug('SIV Record: ' + sivList[0]);
}

// 3. Mimic the privacyChanges map from JS
Map<String, Boolean> privacyChanges = new Map<String, Boolean>{
    'SIV_VIS_PROFILE_PIC' => true  // true = hide profile pic
};
System.debug('privacyChanges: ' + privacyChanges);

// 4. Call saveProfile with minimal params
String result = HAM_EditProfileController.saveProfile(
    c.Id,
    new Map<String, String>(),  // empty dynamicFields
    privacyChanges,
    null  // no contentDocId
);
System.debug('saveProfile result: ' + result);

// 5. Verify if Service Indicator was created
List<ucinn_ascendv2__Service_Indicator__c> createdSI = [
    SELECT Id, ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c, ucinn_ascendv2__Is_Active__c
    FROM ucinn_ascendv2__Service_Indicator__c 
    WHERE ucinn_ascendv2__Contact__c = :c.Id 
    AND ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c = 'SIV_VIS_PROFILE_PIC'
];
System.debug('Service Indicator records for profile pic: ' + createdSI.size());
for(ucinn_ascendv2__Service_Indicator__c si : createdSI) {
    System.debug('SI Record: ' + si);
}
