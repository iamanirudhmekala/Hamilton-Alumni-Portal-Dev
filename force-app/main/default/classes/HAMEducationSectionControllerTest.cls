/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAMEducationSectionControllerTest
 * Purpose         : Test coverage for HAMEducationSectionController.
 *
 *                   IMPORTANT -- schema note: HAM_HQ_Staging__c and its fields
 *                   (HAM_Constituent__c, HAM_School__c, HAM_Degree_Code__c, HAM_Major__c,
 *                   HAM_Minor__c, HAM_Degree_Conferred_Year__c,
 *                   HAM_is_Ready_for_Processing__c, HAM_Is_Processed__c,
 *                   HAM_Degree_Information__c, and the Grad_School_Degree record type)
 *                   could NOT be verified against a live schema here -- that object only
 *                   exists in the AdvDev sandbox this feature was built in, not in the
 *                   Production org this session has query access to. Field names below are
 *                   taken directly from the Object Manager screenshot shared earlier in
 *                   this project. Everything else (ucinn_ascendv2__Degree_Information__c,
 *                   ucinn_ascendv2__Post_Code__c, ucinn_ascendv2__Degree_Code__c,
 *                   ucinn_ascendv2__Minor_Code__c, Account) was confirmed against the live
 *                   Production schema before writing this class. Run this once in the
 *                   sandbox and fix up any HAM_HQ_Staging__c field name mismatches the
 *                   compiler flags -- that's the one part of this file I could not verify.
 *
 *                   Coverage approach: builds one full set of code-table records (Account,
 *                   Degree Code, Post Code, Minor Code) reused across tests, then exercises
 *                   each public method's main branches:
 *                     - getEducationData: Hamilton degree (majors/minors), a real grad row,
 *                       and a pending ("Other") staging row merged into one sorted list.
 *                     - searchPostCodes / searchDegreeCodes / searchInstitutions /
 *                       searchMinorCodes: typeahead matches by the field actually used for
 *                       search+label (Minor via Description__c, others via their own
 *                       description/code fields).
 *                     - saveHamiltonDegree: update path against a College-created record
 *                       (alumni never create this record themselves), plus the >3
 *                       selections validation error.
 *                     - saveGradDegree: new fully-matched row (ready=true), new row with an
 *                       unmatched "Other" field (ready=false, Task created), editing an
 *                       existing pending staging row, editing an existing real
 *                       Degree_Information__c row, and the missing-School validation error.
 *                     - deleteGradDegree: deleting a pending staging row and a real row.
 *                     - Failure path: malformed JSON passed to saveGradDegree.
 *
 *  Change History  :
 *  Date          │   Author     │   Change
 *  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Aug 25, 2026  │ Ameya   │ Initial version.
 *  Sep 01, 2026  │ Ameya   │ Fixed 4 failing tests (testGetEducationData_...,
 *                            testSaveHamiltonDegree_insertsThenUpdatesTheSingleSchoolRecord,
 *                            testDeleteGradDegree_deletesRealDegreeInformationRow,
 *                            testSaveGradDegree_editingExistingRealRow_...). All four were
 *                            the same root cause, not four separate bugs: the portal test
 *                            user created by createRunningUser() had a Profile (found via
 *                            findPortalProfile()'s generic heuristic) but no Permission Set
 *                            granting access to the ucinn_ascendv2 package or its fields.
 *                            That produced "sObject type ... is not supported" (no package
 *                            license/object access at all) on getEducationData, and
 *                            FIELD_CUSTOM_VALIDATION_EXCEPTION / "You do not have access
 *                            permission" on saveHamiltonDegree/deleteGradDegree, since a
 *                            validation rule on Degree_Information__c checks FLS on a field
 *                            the test user's Profile can't see. The real-row saveGradDegree
 *                            assertion failure was downstream of the same silent DML
 *                            failure. Confirmed against a real Hamilton Quad portal user's
 *                            detail page: Profile "Partner Community Login User" (User
 *                            License "Partner Community Login"), with Permission Set
 *                            "HAM Partner Community Permission" mandatory for correct
 *                            access. Set HQ_PORTAL_PROFILE_NAME accordingly, and added
 *                            assignPortalPermissionSets(), called from createRunningUser()
 *                            right after insert, which assigns that Permission Set (matched
 *                            by Label, since its value has spaces and its API Name spelling
 *                            wasn't separately confirmed) plus every Permission Set in the
 *                            ucinn_ascendv2 namespace to the new user.
 *  Sep 01, 2026  │ Ameya   │ That fix then surfaced MIXED_DML_OPERATION on every test:
 *                            inserting a User plus a PermissionSetAssignment (both setup
 *                            objects) in the same transaction as the Account/Contact/etc.
 *                            every test already inserts before calling createRunningUser()
 *                            is a platform-wide restriction, not an org-specific one.
 *                            Wrapped the User insert and assignPortalPermissionSets() call
 *                            in createRunningUser() inside System.runAs(new
 *                            User(Id = UserInfo.getUserId())) -- the standard workaround,
 *                            which gives setup-object DML its own transaction context even
 *                            when "running as" the same user the test is already running as.
 *  Sep 01, 2026  │ Ameya   │ Last failure (testSaveHamiltonDegree_...) turned out not to be
 *                            an access-config gap at all: alumni never create their own
 *                            Hamilton College Degree record -- the College creates it, and
 *                            a portal user attempting to INSERT one correctly trips a
 *                            validation rule shipped with the Ascend package (on
 *                            ucinn_ascendv2__Relationship__c, from package automation off
 *                            the Degree Information insert) blocking portal users from
 *                            creating that data. Renamed/rewrote the test as
 *                            testSaveHamiltonDegree_updatesTheCollegeCreatedSchoolRecord_neverInsertsOne:
 *                            it now seeds the College's School Degree Information record
 *                            before createRunningUser() (mirroring production, where that
 *                            record already exists by the time an alumnus logs in), and the
 *                            portal user only ever exercises saveHamiltonDegree's UPDATE path.
 *  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@IsTest
private class HAMEducationSectionControllerTest {

    // -------------------------------------------------------------------
    // Shared test data
    // -------------------------------------------------------------------

    private static User createRunningUser(Id contactId) {
        // The controller reads UserInfo.getUserId() -> Contact via
        // getRunningUserContactId(). A User's ContactId can ONLY be set when the
        // User's profile is a portal/Community license type (UserType != 'Standard')
        // -- an internal "Standard User" profile throws FIELD_INTEGRITY_EXCEPTION on
        // insert. This looks up whatever portal-capable profile exists in the org
        // rather than hardcoding a name, since the exact Experience Cloud profile
        // name for Hamilton Quad is specific to that org's setup.
        //
        // NOTE: if this org has zero available licenses for whatever profile is
        // found (common in sandboxes with limited external-user seats), the User
        // insert below can still fail with a license-limit error unrelated to this
        // logic -- if so, swap findPortalProfile() for a hardcoded Id of the actual
        // Hamilton Quad community profile, which you'll know and I can't query here.
        Profile p = findPortalProfile();
        System.assert(p != null, 'No portal/Community profile found in this org -- '
            + 'swap in the exact Hamilton Quad community profile Id here.');

        User u = new User(
            FirstName = 'HQ',
            LastName = 'Test User ' + Crypto.getRandomInteger(),
            Email = 'hqtestuser' + Crypto.getRandomInteger() + '@hamilton.edu.test',
            Username = 'hqtestuser' + Crypto.getRandomLong() + '@hamilton.edu.test',
            Alias = 'hqtest',
            CommunityNickname = 'hqtest' + Crypto.getRandomInteger(),
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            ContactId = contactId
        );

        // MIXED_DML_OPERATION: inserting a User (a setup object) in the same
        // transaction as the non-setup objects (Account, Contact, ...) every
        // calling test already inserted before reaching this point throws
        // MIXED_DML_OPERATION -- this is a platform-wide rule, not specific to
        // this org. PermissionSetAssignment is a setup object too, so both the
        // User insert and assignPortalPermissionSets() go inside their own
        // System.runAs block, which gives setup DML its own transaction context.
        // This is the standard workaround for mixed DML in test contexts, and
        // works even running as the same user the test is already running as.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            // See HQ_PORTAL_PERMISSION_SET_NAMES / assignPortalPermissionSets()
            // below -- the Profile alone does not grant this user access to the
            // ucinn_ascendv2 package objects/fields; real Hamilton Quad users get
            // that through one or more assigned Permission Sets.
            assignPortalPermissionSets(u.Id);
        }

        return u;
    }

    // TODO(Ameya): set this to the exact Profile Name real Hamilton Quad portal users
    // run under (Setup > Digital Experiences > Hamilton Quad > Administration >
    // Members shows the Guest User Profile; or check whatever HAMPortalUserProvisioningService
    // assigns). Until this is set, findPortalProfile() falls back to a generic
    // heuristic that may pick the WRONG portal-type profile -- one that satisfies
    // "a Contact can be linked to it" but is NOT the profile any validation rules /
    // object-level license restrictions on the managed-package objects actually
    // expect, which is exactly what's producing FIELD_CUSTOM_VALIDATION_EXCEPTION
    // and "sObject type ... not supported" errors in these tests.
    // Confirmed from a real Hamilton Quad portal user's detail page: Profile
    // "Partner Community Login User", User License "Partner Community Login".
    private static final String HQ_PORTAL_PROFILE_NAME = 'Partner Community Login User';

    // Confirmed mandatory for correct access: "HAM Partner Community Permission".
    // Real Hamilton Quad portal users get their runtime access to
    // ucinn_ascendv2__Degree_Information__c, the Post/Degree/Minor Code objects, and
    // the field a validation rule on Degree Information checks FLS on through this
    // Permission Set -- the Profile alone does not grant it, which is what produced
    // "sObject type ... is not supported" and the FIELD_CUSTOM_VALIDATION_EXCEPTION /
    // "You do not have access permission" failures before this was set.
    private static final List<String> HQ_PORTAL_PERMISSION_SET_NAMES = new List<String>{
        'HAM Partner Community Permission'
    };

    private static Profile findPortalProfile() {
        if (String.isNotBlank(HQ_PORTAL_PROFILE_NAME)) {
            List<Profile> named = [SELECT Id, Name, UserType FROM Profile WHERE Name = :HQ_PORTAL_PROFILE_NAME LIMIT 1];
            if (!named.isEmpty()) {
                return named[0];
            }
        }
        List<Profile> profiles = [
            SELECT Id, Name, UserType
            FROM Profile
            WHERE UserType IN ('PowerCustomerSuccess', 'CustomerSuccess', 'CspLitePortal', 'PowerPartner')
            LIMIT 1
        ];
        if (!profiles.isEmpty()) {
            return profiles[0];
        }
        // Fallback: standard Experience Cloud profile names almost always contain
        // "Community" even when cloned/customized for a specific site.
        profiles = [SELECT Id, Name, UserType FROM Profile WHERE Name LIKE '%Community%' LIMIT 1];
        return profiles.isEmpty() ? null : profiles[0];
    }

    /**
     * Assigns whatever Permission Set(s) are named in
     * HQ_PORTAL_PERMISSION_SET_NAMES, plus every Permission Set in the
     * ucinn_ascendv2 package namespace, to the given test user. Without this,
     * a portal user created purely from findPortalProfile()'s Profile has no
     * object permissions/license on the managed package at all, which is what
     * produced "sObject type 'ucinn_ascendv2__Degree_Information__c' is not
     * supported" on getEducationData, and the FIELD_CUSTOM_VALIDATION_EXCEPTION
     * / "You do not have access permission" failures on saveHamiltonDegree and
     * deleteGradDegree (a validation rule on Degree_Information__c checking FLS
     * on a field the Profile can't see).
     *
     * Silently does nothing if no matching Permission Set is found, so an org
     * where this hasn't been configured yet still runs (surfacing the same
     * access failures for you to diagnose) instead of failing at setup time.
     */
    private static void assignPortalPermissionSets(Id userId) {
        // Matched against Label as well as Name: the value confirmed for this org
        // ("HAM Partner Community Permission") has spaces, which is only valid on
        // the PermissionSet Label field -- the API Name can't contain spaces, and
        // its actual spelling/casing (e.g. HAM_Partner_Community_Permission vs.
        // HAMPartnerCommunityPermission) wasn't confirmed alongside the Label.
        Set<String> names = new Set<String>(HQ_PORTAL_PERMISSION_SET_NAMES);
        List<PermissionSet> permSets = [
            SELECT Id, Name, Label
            FROM PermissionSet
            WHERE Name IN :names
               OR Label IN :names
               OR NamespacePrefix = 'ucinn_ascendv2'
        ];
        if (permSets.isEmpty()) {
            return;
        }
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet ps : permSets) {
            assignments.add(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps.Id));
        }
        insert assignments;
    }

    private static Account newHamiltonCollegeAccount() {
        Account hamilton = new Account(Name = 'Hamilton College', Type = 'Academic Organization');
        insert hamilton;
        return hamilton;
    }

    private static Account newInstitutionAccount(String name) {
        Account acc = new Account(Name = name, Type = 'Academic Organization');
        insert acc;
        return acc;
    }

    private static ucinn_ascendv2__Post_Code__c newPostCode(String label) {
        ucinn_ascendv2__Post_Code__c pc = new ucinn_ascendv2__Post_Code__c(
            Name = label,
            ucinn_ascendv2__Major_Specialty_Description__c = label,
            ucinn_ascendv2__Is_Active__c = true
        );
        insert pc;
        return pc;
    }

    private static ucinn_ascendv2__Degree_Code__c newDegreeCode(String code) {
        ucinn_ascendv2__Degree_Code__c dc = new ucinn_ascendv2__Degree_Code__c(
            Name = code,
            ucinn_ascendv2__Degree_Code__c = code,
            ucinn_ascendv2__Is_Active__c = true
        );
        insert dc;
        return dc;
    }

    private static ucinn_ascendv2__Minor_Code__c newMinorCode(String description) {
        ucinn_ascendv2__Minor_Code__c mc = new ucinn_ascendv2__Minor_Code__c(
            Name = description,
            ucinn_ascendv2__Description__c = description
        );
        insert mc;
        return mc;
    }

    private static Id schoolRecordTypeId() {
        // Developer Name changed from 'School_Degree_Information' to
        // 'Hamilton_AIS_Degree_Information' -- updated here to match.
        return Schema.SObjectType.ucinn_ascendv2__Degree_Information__c
            .getRecordTypeInfosByDeveloperName().get('Hamilton_AIS_Degree_Information').getRecordTypeId();
    }

    private static Id nonSchoolRecordTypeId() {
        return Schema.SObjectType.ucinn_ascendv2__Degree_Information__c
            .getRecordTypeInfosByDeveloperName().get('Non_School_Degree_Information').getRecordTypeId();
    }

    private static Id gradStagingRecordTypeId() {
        return Schema.SObjectType.HAM_HQ_Staging__c
            .getRecordTypeInfosByDeveloperName().get('Grad_School_Degree').getRecordTypeId();
    }

    // -------------------------------------------------------------------
    // getEducationData
    // -------------------------------------------------------------------

    @IsTest
    static void testGetEducationData_returnsHamiltonDegreeRealGradRowAndPendingRowMerged() {
        Account hamilton = newHamiltonCollegeAccount();
        Contact con = new Contact(LastName = 'Wolfpack', AccountId = hamilton.Id);
        insert con;
        User runningUser = createRunningUser(con.Id);

        ucinn_ascendv2__Post_Code__c physics = newPostCode('Physics');
        ucinn_ascendv2__Post_Code__c spanish = newPostCode('Spanish');
        ucinn_ascendv2__Minor_Code__c govMinor = newMinorCode('Government');

        // Hamilton College Degree (School record type): one major, one minor.
        ucinn_ascendv2__Degree_Information__c schoolRec = new ucinn_ascendv2__Degree_Information__c(
            RecordTypeId = schoolRecordTypeId(),
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Degree_Institution__c = hamilton.Id,
            ucinn_ascendv2__Post_Code__c = physics.Id,
            ucinn_ascendv2__Minor_Code__c = govMinor.Id
        );
        insert schoolRec;

        // A real, fully-processed grad row.
        Account gradSchool = newInstitutionAccount('Suny Plattsburgh');
        ucinn_ascendv2__Degree_Code__c ms = newDegreeCode('MS');
        ucinn_ascendv2__Minor_Code__c physMinor = newMinorCode('Physics');
        ucinn_ascendv2__Degree_Information__c gradRec = new ucinn_ascendv2__Degree_Information__c(
            RecordTypeId = nonSchoolRecordTypeId(),
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Degree_Institution__c = gradSchool.Id,
            ucinn_ascendv2__Degree_Code__c = ms.Id,
            ucinn_ascendv2__Post_Code__c = physics.Id,
            ucinn_ascendv2__Minor_Code__c = physMinor.Id,
            ucinn_ascendv2__Conferred_Degree_Year__c = '2025'
        );
        insert gradRec;

        // A pending staging row: School matched (Id), Degree Type unmatched ("Other").
        HAM_HQ_Staging__c pending = new HAM_HQ_Staging__c(
            RecordTypeId = gradStagingRecordTypeId(),
            HAM_Constituent__c = con.Id,
            HAM_School__c = String.valueOf(gradSchool.Id),
            HAM_Degree_Code__c = 'Custom Certificate',
            HAM_Major__c = String.valueOf(spanish.Id),
            HAM_Degree_Conferred_Year__c = '2026',
            HAM_is_Ready_for_Processing__c = false
        );
        insert pending;

        Test.startTest();
        HAMEducationSectionController.EducationData data;
        System.runAs(runningUser) {
            data = HAMEducationSectionController.getEducationData();
        }
        Test.stopTest();

        System.assertEquals(schoolRec.Id, data.hamiltonDegree.recordId, 'Hamilton degree record should be returned');
        System.assertEquals(1, data.hamiltonDegree.majors.size(), 'One major expected');
        System.assertEquals('Physics', data.hamiltonDegree.majors[0].label, 'Major label should be the friendly description');
        System.assertEquals(1, data.hamiltonDegree.minors.size(), 'One minor expected');

        System.assertEquals(2, data.gradDegrees.size(), 'Real row + pending row expected');

        HAMEducationSectionController.GradDegreeRow realRow;
        HAMEducationSectionController.GradDegreeRow pendingRow;
        for (HAMEducationSectionController.GradDegreeRow row : data.gradDegrees) {
            if (row.isPending) {
                pendingRow = row;
            } else {
                realRow = row;
            }
        }

        System.assertNotEquals(null, realRow, 'Real grad row should be present');
        System.assertEquals('Suny Plattsburgh', realRow.institutionName);
        System.assertEquals('MS', realRow.degreeCodeName, 'Degree Type should show the friendly code, not Name');
        System.assertEquals('Physics', realRow.postCodeName);
        System.assertEquals('Physics', realRow.minorCodeName, 'Minor should resolve via Minor_Formula__c');

        System.assertNotEquals(null, pendingRow, 'Pending staging row should be present');
        System.assertEquals('Suny Plattsburgh', pendingRow.institutionName, 'Matched School Id should resolve to its Name');
        System.assertEquals('Custom Certificate', pendingRow.degreeCodeName, 'Free-text Degree Type should pass through unresolved');
        System.assertEquals('Spanish', pendingRow.postCodeName, 'Matched Concentration Id should resolve to its label');
    }

    @IsTest
    static void testGetEducationData_noContact_returnsEmptyShellWithoutError() {
        // A User with no ContactId at all should not blow up -- getRunningUserContactId()
        // returns null and getEducationData short-circuits to an empty shell.
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'No',
            LastName = 'Contact ' + Crypto.getRandomInteger(),
            Email = 'nocontact' + Crypto.getRandomInteger() + '@hamilton.edu.test',
            Username = 'nocontact' + Crypto.getRandomLong() + '@hamilton.edu.test',
            Alias = 'nocon',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;

        Test.startTest();
        HAMEducationSectionController.EducationData data;
        System.runAs(u) {
            data = HAMEducationSectionController.getEducationData();
        }
        Test.stopTest();

        System.assertEquals(null, data.hamiltonDegree.recordId);
        System.assertEquals(0, data.gradDegrees.size(), 'No Contact means no grad rows should be attempted or returned');
    }

    // -------------------------------------------------------------------
    // Typeahead search
    // -------------------------------------------------------------------

    @IsTest
    static void testSearchPostCodes_matchesByDescription() {
        newPostCode('Physics');
        newPostCode('Government'); // deliberately no shared substring with the search term below

        Test.startTest();
        List<HAMEducationSectionController.CodeOption> results = HAMEducationSectionController.searchPostCodes('Phy');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Physics', results[0].label);
    }

    @IsTest
    static void testSearchDegreeCodes_matchesByCodeField() {
        newDegreeCode('MS');
        newDegreeCode('PHD');

        Test.startTest();
        List<HAMEducationSectionController.CodeOption> results = HAMEducationSectionController.searchDegreeCodes('MS');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('MS', results[0].label);
    }

    @IsTest
    static void testSearchInstitutions_matchesAcademicOrganizationsOnly() {
        newInstitutionAccount('Suny Plattsburgh');
        Account nonAcademic = new Account(Name = 'Suny Plattsburgh Hospital', Type = 'Business');
        insert nonAcademic;

        Test.startTest();
        List<HAMEducationSectionController.CodeOption> results = HAMEducationSectionController.searchInstitutions('Suny Plattsburgh');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Only the Academic Organization account should match');
        System.assertEquals('Suny Plattsburgh', results[0].label);
    }

    @IsTest
    static void testSearchMinorCodes_matchesByDescriptionNotShortCode() {
        newMinorCode('Physics');

        Test.startTest();
        List<HAMEducationSectionController.CodeOption> byDescription = HAMEducationSectionController.searchMinorCodes('Phys');
        Test.stopTest();

        System.assertEquals(1, byDescription.size(), 'Should match on the friendly description field');
        System.assertEquals('Physics', byDescription[0].label);
    }

    // -------------------------------------------------------------------
    // saveHamiltonDegree
    // -------------------------------------------------------------------

    @IsTest
    static void testSaveHamiltonDegree_updatesTheCollegeCreatedSchoolRecord_neverInsertsOne() {
        // Alumni never create their own Hamilton College Degree record -- the College
        // creates it (e.g. via the Registrar/Advancement data feed) long before the
        // alumnus ever logs into Hamilton Quad. The insert branch inside
        // saveHamiltonDegree's upsert is a defensive fallback, not something a portal
        // user is meant to exercise: attempting to INSERT a brand-new
        // ucinn_ascendv2__Degree_Information__c record as a portal user trips a
        // validation rule that ships with the Ascend package itself (on
        // ucinn_ascendv2__Relationship__c, created by package automation off the
        // Degree Information insert). That's a correct package guardrail against
        // portal users creating this data, not a Permission Set gap to work around --
        // so this test reflects the real workflow instead: seed the College's School
        // Degree Information record the way it would already exist in production
        // (outside any portal-user context), then verify the portal user's save only
        // UPDATES it.
        Account hamilton = newHamiltonCollegeAccount();
        Contact con = new Contact(LastName = 'Wolfpack');
        insert con;

        ucinn_ascendv2__Post_Code__c physics = newPostCode('Physics');
        ucinn_ascendv2__Post_Code__c spanish = newPostCode('Spanish');
        ucinn_ascendv2__Minor_Code__c govMinor = newMinorCode('Government');

        // The College's existing School Degree Information record -- inserted here,
        // before createRunningUser(), to mirror production: this record already
        // exists by the time any alumnus reaches the Education section of HQ.
        ucinn_ascendv2__Degree_Information__c existing = new ucinn_ascendv2__Degree_Information__c(
            RecordTypeId = schoolRecordTypeId(),
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Degree_Institution__c = hamilton.Id,
            ucinn_ascendv2__Post_Code__c = physics.Id,
            ucinn_ascendv2__Minor_Code__c = govMinor.Id
        );
        insert existing;

        User runningUser = createRunningUser(con.Id);

        Test.startTest();
        Id savedId;
        System.runAs(runningUser) {
            // Adding a second major to the College's existing record -- the only
            // thing an alumnus can actually do here.
            savedId = HAMEducationSectionController.saveHamiltonDegree(
                new List<String>{ physics.Id, spanish.Id },
                new List<String>{ govMinor.Id }
            );
        }
        Test.stopTest();

        System.assertEquals(existing.Id, savedId, 'saveHamiltonDegree should update the College-created record, never insert a new one');

        List<ucinn_ascendv2__Degree_Information__c> recs = [
            SELECT ucinn_ascendv2__Post_Code__c, ucinn_ascendv2__Second_Major_Post_Code__c, ucinn_ascendv2__Degree_Institution__c
            FROM ucinn_ascendv2__Degree_Information__c
            WHERE ucinn_ascendv2__Contact__c = :con.Id AND RecordTypeId = :schoolRecordTypeId()
        ];
        System.assertEquals(1, recs.size(), 'Only the one College-created record should exist -- saveHamiltonDegree must not have inserted a second one');
        System.assertEquals(physics.Id, recs[0].ucinn_ascendv2__Post_Code__c);
        System.assertEquals(spanish.Id, recs[0].ucinn_ascendv2__Second_Major_Post_Code__c);
        System.assertEquals(hamilton.Id, recs[0].ucinn_ascendv2__Degree_Institution__c);
    }

    @IsTest
    static void testSaveHamiltonDegree_moreThanThreeMajorsThrows() {
        newHamiltonCollegeAccount();
        Contact con = new Contact(LastName = 'Wolfpack');
        insert con;
        User runningUser = createRunningUser(con.Id);

        ucinn_ascendv2__Post_Code__c pc1 = newPostCode('Physics');
        ucinn_ascendv2__Post_Code__c pc2 = newPostCode('Spanish');
        ucinn_ascendv2__Post_Code__c pc3 = newPostCode('Government');
        ucinn_ascendv2__Post_Code__c pc4 = newPostCode('History');

        Test.startTest();
        Boolean threw = false;
        System.runAs(runningUser) {
            try {
                HAMEducationSectionController.saveHamiltonDegree(
                    new List<String>{ pc1.Id, pc2.Id, pc3.Id, pc4.Id },
                    new List<String>()
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
        }
        Test.stopTest();

        System.assert(threw, 'Selecting more than 3 majors should throw an AuraHandledException');
    }

    // -------------------------------------------------------------------
    // saveGradDegree
    // -------------------------------------------------------------------

    @IsTest
    static void testSaveGradDegree_newRowFullyMatched_isReadyAndNoTaskCreated() {
        Contact con = new Contact(LastName = 'Wolfpack');
        insert con;
        User runningUser = createRunningUser(con.Id);

        Account gradSchool = newInstitutionAccount('Suny Plattsburgh');
        ucinn_ascendv2__Degree_Code__c ms = newDegreeCode('MS');
        ucinn_ascendv2__Post_Code__c physics = newPostCode('Physics');

        HAMEducationSectionController.GradDegreeRow row = new HAMEducationSectionController.GradDegreeRow();
        row.institutionId = gradSchool.Id;
        row.institutionName = 'Suny Plattsburgh';
        row.degreeCodeId = ms.Id;
        row.degreeCodeName = 'MS';
        row.postCodeId = physics.Id;
        row.postCodeName = 'Physics';
        row.degreeYear = '2025';

        Test.startTest();
        HAMEducationSectionController.SaveResult result;
        System.runAs(runningUser) {
            result = HAMEducationSectionController.saveGradDegree(JSON.serialize(row));
        }
        Test.stopTest();

        System.assert(result.success, 'Fully matched row should save successfully');

        HAM_HQ_Staging__c staging = [
            SELECT HAM_is_Ready_for_Processing__c, HAM_School__c, HAM_Degree_Code__c, HAM_Major__c
            FROM HAM_HQ_Staging__c
            WHERE Id = :result.recordId
        ];
        System.assert(staging.HAM_is_Ready_for_Processing__c, 'Every field resolved to an Id, so the row should be ready for processing');
        System.assertEquals(String.valueOf(gradSchool.Id), staging.HAM_School__c, 'Id should be stored (pick() prefers Id over Name)');

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :result.recordId];
        System.assertEquals(0, tasks.size(), 'A fully-matched row should not create a Data Steward task');
    }

    @IsTest
    static void testSaveGradDegree_newRowWithUnmatchedOtherField_isNotReadyAndTaskCreated() {
        Contact con = new Contact(LastName = 'Wolfpack');
        insert con;
        User runningUser = createRunningUser(con.Id);

        // Only School is matched; Degree Type is free text ("Other").
        Account gradSchool = newInstitutionAccount('Some Unlisted College');

        HAMEducationSectionController.GradDegreeRow row = new HAMEducationSectionController.GradDegreeRow();
        row.institutionId = gradSchool.Id;
        row.institutionName = 'Some Unlisted College';
        row.degreeCodeName = 'Made Up Certificate'; // no degreeCodeId -> unmatched
        row.degreeYear = '2026';

        Test.startTest();
        HAMEducationSectionController.SaveResult result;
        System.runAs(runningUser) {
            result = HAMEducationSectionController.saveGradDegree(JSON.serialize(row));
        }
        Test.stopTest();

        System.assert(result.success, 'A row with an unmatched field still saves -- just as pending');

        HAM_HQ_Staging__c staging = [
            SELECT HAM_is_Ready_for_Processing__c, HAM_Degree_Code__c
            FROM HAM_HQ_Staging__c
            WHERE Id = :result.recordId
        ];
        System.assert(!staging.HAM_is_Ready_for_Processing__c, 'Unmatched Degree Type should leave the row not ready');
        System.assertEquals('Made Up Certificate', staging.HAM_Degree_Code__c, 'Free text should be stored as-is (pick() falls back to Name)');

        List<Task> tasks = [SELECT Id, WhatId FROM Task WHERE WhatId = :result.recordId];
        System.assertEquals(1, tasks.size(), 'An unmatched field should open a Data Steward task');
    }

    @IsTest
    static void testSaveGradDegree_editingExistingPendingRow_updatesStagingNotDegreeInformation() {
        Contact con = new Contact(LastName = 'Wolfpack');
        insert con;
        User runningUser = createRunningUser(con.Id);

        HAM_HQ_Staging__c staging = new HAM_HQ_Staging__c(
            RecordTypeId = gradStagingRecordTypeId(),
            HAM_Constituent__c = con.Id,
            HAM_School__c = 'Some Unlisted College',
            HAM_Degree_Code__c = 'Made Up Certificate',
            HAM_Degree_Conferred_Year__c = '2026',
            HAM_is_Ready_for_Processing__c = false
        );
        insert staging;

        Account gradSchool = newInstitutionAccount('Now It Exists University');
        ucinn_ascendv2__Degree_Code__c cert = newDegreeCode('CERT');

        HAMEducationSectionController.GradDegreeRow row = new HAMEducationSectionController.GradDegreeRow();
        row.recordId = staging.Id;
        row.institutionId = gradSchool.Id;
        row.institutionName = 'Now It Exists University';
        row.degreeCodeId = cert.Id;
        row.degreeCodeName = 'CERT';
        row.degreeYear = '2026';

        Test.startTest();
        HAMEducationSectionController.SaveResult result;
        System.runAs(runningUser) {
            result = HAMEducationSectionController.saveGradDegree(JSON.serialize(row));
        }
        Test.stopTest();

        System.assert(result.success);
        System.assertEquals(staging.Id, result.recordId, 'Editing a pending row should update the same staging record, not create a new one');

        HAM_HQ_Staging__c updated = [SELECT HAM_is_Ready_for_Processing__c, HAM_School__c FROM HAM_HQ_Staging__c WHERE Id = :staging.Id];
        System.assert(updated.HAM_is_Ready_for_Processing__c, 'Now that both fields resolved to Ids, the row should be ready');
        System.assertEquals(String.valueOf(gradSchool.Id), updated.HAM_School__c);

        System.assertEquals(0, [SELECT COUNT() FROM ucinn_ascendv2__Degree_Information__c WHERE ucinn_ascendv2__Contact__c = :con.Id],
            'No real Degree_Information__c record should have been created by this edit');
    }

    @IsTest
    static void testSaveGradDegree_editingExistingRealRow_updatesDegreeInformationDirectly() {
        Contact con = new Contact(LastName = 'Wolfpack');
        insert con;
        User runningUser = createRunningUser(con.Id);

        Account originalSchool = newInstitutionAccount('Original School');
        Account newSchool = newInstitutionAccount('Corrected School');
        ucinn_ascendv2__Degree_Code__c ms = newDegreeCode('MS');

        ucinn_ascendv2__Degree_Information__c gradRec = new ucinn_ascendv2__Degree_Information__c(
            RecordTypeId = nonSchoolRecordTypeId(),
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Degree_Institution__c = originalSchool.Id,
            ucinn_ascendv2__Degree_Code__c = ms.Id,
            ucinn_ascendv2__Conferred_Degree_Year__c = '2024'
        );
        insert gradRec;

        HAMEducationSectionController.GradDegreeRow row = new HAMEducationSectionController.GradDegreeRow();
        row.recordId = gradRec.Id;
        row.institutionId = newSchool.Id;
        row.degreeCodeId = ms.Id;
        row.degreeYear = '2024';

        Test.startTest();
        HAMEducationSectionController.SaveResult result;
        System.runAs(runningUser) {
            result = HAMEducationSectionController.saveGradDegree(JSON.serialize(row));
        }
        Test.stopTest();

        System.assert(result.success);
        ucinn_ascendv2__Degree_Information__c updated = [
            SELECT ucinn_ascendv2__Degree_Institution__c
            FROM ucinn_ascendv2__Degree_Information__c
            WHERE Id = :gradRec.Id
        ];
        System.assertEquals(newSchool.Id, updated.ucinn_ascendv2__Degree_Institution__c, 'Real record should be updated directly, no staging row involved');
        System.assertEquals(0, [SELECT COUNT() FROM HAM_HQ_Staging__c WHERE HAM_Constituent__c = :con.Id],
            'Editing a real record should never create a staging row');
    }

    @IsTest
    static void testSaveGradDegree_missingSchool_returnsFailureResult() {
        Contact con = new Contact(LastName = 'Wolfpack');
        insert con;
        User runningUser = createRunningUser(con.Id);

        HAMEducationSectionController.GradDegreeRow row = new HAMEducationSectionController.GradDegreeRow();
        row.degreeYear = '2025'; // no institutionId or institutionName at all

        Test.startTest();
        HAMEducationSectionController.SaveResult result;
        System.runAs(runningUser) {
            result = HAMEducationSectionController.saveGradDegree(JSON.serialize(row));
        }
        Test.stopTest();

        System.assert(!result.success, 'A row with no School at all should fail validation');
        System.assertEquals('School is required.', result.message);
    }

    @IsTest
    static void testSaveGradDegree_malformedJson_returnsFailureResultNotException() {
        Contact con = new Contact(LastName = 'Wolfpack');
        insert con;
        User runningUser = createRunningUser(con.Id);

        Test.startTest();
        HAMEducationSectionController.SaveResult result;
        System.runAs(runningUser) {
            result = HAMEducationSectionController.saveGradDegree('{not valid json');
        }
        Test.stopTest();

        System.assert(!result.success, 'Malformed JSON should be reported as a failure, not thrown');
        System.assert(result.message.contains('Could not read the submitted form'));
    }

    // -------------------------------------------------------------------
    // deleteGradDegree
    // -------------------------------------------------------------------

    @IsTest
    static void testDeleteGradDegree_deletesPendingStagingRow() {
        Contact con = new Contact(LastName = 'Wolfpack');
        insert con;
        User runningUser = createRunningUser(con.Id);

        HAM_HQ_Staging__c staging = new HAM_HQ_Staging__c(
            RecordTypeId = gradStagingRecordTypeId(),
            HAM_Constituent__c = con.Id,
            HAM_School__c = 'Some School',
            HAM_is_Ready_for_Processing__c = false
        );
        insert staging;

        Test.startTest();
        System.runAs(runningUser) {
            HAMEducationSectionController.deleteGradDegree(staging.Id);
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM HAM_HQ_Staging__c WHERE Id = :staging.Id]);
    }

    @IsTest
    static void testDeleteGradDegree_deletesRealDegreeInformationRow() {
        Contact con = new Contact(LastName = 'Wolfpack');
        insert con;
        User runningUser = createRunningUser(con.Id);

        Account gradSchool = newInstitutionAccount('Suny Plattsburgh');
        ucinn_ascendv2__Degree_Information__c gradRec = new ucinn_ascendv2__Degree_Information__c(
            RecordTypeId = nonSchoolRecordTypeId(),
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Degree_Institution__c = gradSchool.Id
        );
        insert gradRec;

        Test.startTest();
        System.runAs(runningUser) {
            HAMEducationSectionController.deleteGradDegree(gradRec.Id);
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ucinn_ascendv2__Degree_Information__c WHERE Id = :gradRec.Id]);
    }
}