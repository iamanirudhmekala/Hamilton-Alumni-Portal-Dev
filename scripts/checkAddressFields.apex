
/* ============================================================
   SELF-SEARCH TEST  —  Alumni Directory
   Run in: Developer Console > Execute Anonymous (Open Log, level DEBUG)
   Fill in the two values below, then Execute.
   ============================================================ */

Id     myContactId = '003U100000aIdq9IAC';   // <-- logged-in portal user's CONTACT Id
String myName      = 'Cube84 User Ham Test';             // <-- search term, as the name appears in directory

// ---- 1) Call the SEARCH DIRECTORY data method (page 1, no filters) ----
HAM_AlumniDirectoryController.DirectoryResponse resp =
    HAM_AlumniDirectoryController.getDirectoryData(
        'Search Directory',                 // tab  (HAM_ConstantsUtil.BUILD_TAB)
        9,                                  // pageSize
        0,                                  // recordsToSkip (page 1)
        myName,                             // searchKey
        new List<Map<String,Object>>(),     // selectedFilters (none)
        myContactId,                        // portalConstituentId
        null, null, null,                   // invitationSubTab, bookmarkFilter, favoriteFilter
        null                                // scopeContactIds (not a group scope)
    );

Boolean selfFound = false;
System.debug('===== Cards returned on page 1: ' + resp.constituentsData.size());
for (HAM_AlumniDirectoryController.ConstituentWrapper cw : resp.constituentsData) {
    System.debug('   card id=' + cw.id + '  header=' + cw.header);
    if (cw.id == myContactId) { selfFound = true; }
}
System.debug('===== SELF RECORD IN SEARCH RESULTS? ' + selfFound);

// ---- 2) Count method (what pagination/total uses) ----
Integer total = HAM_AlumniDirectoryController.getDirectoryDataCount(
        'Search Directory', myName, new List<Map<String,Object>>(),
        myContactId, null, null, null, null);
System.debug('===== Count query total: ' + total);

/* ============================================================
   3) DIAGNOSTIC — if selfFound = false, this shows WHY.
   Checks the same eligibility gates the page query applies.
   ============================================================ */
Contact me = [SELECT Id, Name,
                     ucinn_ascendv2__Primary_Contact_Type__c,
                     HAM_Is_Active__c,
                     ucinn_ascendv2__Is_Deceased__c,
                     ucinn_ascendv2__Expanded_Name_Formula__c
              FROM Contact WHERE Id = :myContactId];
System.debug('--- Contact: ' + me.Name
        + ' | PrimaryType=' + me.ucinn_ascendv2__Primary_Contact_Type__c
        + ' | IsActive='    + me.HAM_Is_Active__c
        + ' | Deceased='    + me.ucinn_ascendv2__Is_Deceased__c
        + ' | ExpandedName='+ me.ucinn_ascendv2__Expanded_Name_Formula__c);

// Excluded primary types per ham_AlumniDefaultFilter (+ no-Student on Search tab)
Set<String> excludedTypes = new Set<String>{
    'Spouse of Alumni or Trustee','Friend','Tribute Donor','Incoming Parent',
    'Former Incoming Parent','Organization Contact','Former Employee','Grandparent'};
String pt = me.ucinn_ascendv2__Primary_Contact_Type__c;
if (pt != null && excludedTypes.contains(pt))
    System.debug('*** BLOCKED: Primary_Contact_Type is an excluded type: ' + pt);
if (pt != null && pt.contains('Student'))
    System.debug('*** BLOCKED: Primary_Contact_Type contains "Student" (no-Student clause on Search tab)');
if (me.HAM_Is_Active__c != true && me.ucinn_ascendv2__Is_Deceased__c != true)
    System.debug('*** BLOCKED: HAM_Is_Active__c is false and not deceased');

// Active service indicators on this contact (privacy)
for (ucinn_ascendv2__Service_Indicator__c si : [
        SELECT ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c
        FROM ucinn_ascendv2__Service_Indicator__c
        WHERE ucinn_ascendv2__Contact__c = :myContactId
          AND ucinn_ascendv2__Is_Active__c = true]) {
    String pid = si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c;
    System.debug('--- Active Service Indicator portalId=' + pid);
    if (pid == 'SIV_VIS_ALUMNI_PRIVACY')
        System.debug('*** BLOCKED: Alumni Privacy indicator active -> hidden from directory (AlumniPrivacyIds)');
    if (pid == 'SIV_VIS_CONNECTION')
        System.debug('--- Note: Connection Privacy active -> Send Request disabled (card still shows)');
}
System.debug('===== DIAGNOSTIC COMPLETE =====');
