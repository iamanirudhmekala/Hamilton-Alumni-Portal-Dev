// 04/08/2026 NVV: ASC-13038 - Capture Notes field while creating new Interest
@IsTest
private class HAMCCInterestViewControllerTest {

    /**
     * @description Creates common test data used by all test methods.
     */
    @TestSetup
    static void setupData() {
        Account orgA = HAMJediTestDataFactory.makeAccount('Org A');
        Account orgB = HAMJediTestDataFactory.makeAccount('Org B');

        Contact alumniA = HAMJediTestDataFactory.makeContact('One', orgA.Id);
        HAMJediTestDataFactory.makeContact('Two', orgB.Id);

        ucinn_ascendv2__Foundation_Funding_Interests__c ffi1 =
            HAMJediTestDataFactory.makeFoundationFundingInterest('Career Center');
        ucinn_ascendv2__Foundation_Funding_Interests__c ffi2 =
            HAMJediTestDataFactory.makeFoundationFundingInterest('Career Center');

        Date today = Date.today();

        // Alumni active (end in future)
        HAMJediTestDataFactory.makeFundingInterestForContact(alumniA.Id, ffi1.Id, today.addDays(-10), today.addDays(10));
        // Alumni ended (end in past — should be excluded)
        HAMJediTestDataFactory.makeFundingInterestForContact(alumniA.Id, ffi2.Id, today.addDays(-20), today.addDays(-1));
        // Org active (end in future)
        HAMJediTestDataFactory.makeFundingInterestForAccount(orgA.Id, ffi1.Id, today.addDays(-5), today.addDays(5));
        // Org no end date (should be included)
        HAMJediTestDataFactory.makeFundingInterestForAccount(orgA.Id, ffi2.Id, today.addDays(-15), null);
    }

    // -------------------------
    // getMyFundingInterests
    // -------------------------

    @IsTest
    static void testGetFundingInterestsAlumni() {
        Contact alumni = [SELECT Id FROM Contact WHERE LastName = 'One' LIMIT 1];

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            List<ucinn_ascendv2__Funding_Interest__c> results =
                HAMCCInterestViewController.getMyFundingInterests(alumni.Id, true);
            Test.stopTest();

            System.assertEquals(1, results.size(), 'Only active alumni funding interests should be returned');
            System.assertEquals(alumni.Id, results[0].ucinn_ascendv2__Contact__c);
        }
    }

    @IsTest
    static void testGetFundingInterestsOrganization() {
        Account org = [SELECT Id FROM Account WHERE Name = 'Org A' LIMIT 1];

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            List<ucinn_ascendv2__Funding_Interest__c> results =
                HAMCCInterestViewController.getMyFundingInterests(org.Id, false);
            Test.stopTest();

            System.assertEquals(2, results.size(), 'Org should return both active and null-end-date interests');
            for (ucinn_ascendv2__Funding_Interest__c fi : results) {
                System.assertEquals(org.Id, fi.ucinn_ascendv2__Account__c);
            }
        }
    }

    @IsTest
    static void testGetFundingInterestsNullRecordId() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            List<ucinn_ascendv2__Funding_Interest__c> results =
                HAMCCInterestViewController.getMyFundingInterests(null, true);
            Test.stopTest();

            System.assertEquals(0, results.size(), 'Null recordId should return empty list');
        }
    }

    // -------------------------
    // upsertFundingInterest
    // -------------------------

    @IsTest
    static void testUpsertFundingInterestAlumni() {
        Contact alumni = [SELECT Id FROM Contact WHERE LastName = 'One' LIMIT 1];
        ucinn_ascendv2__Foundation_Funding_Interests__c ffi =
            [SELECT Id FROM ucinn_ascendv2__Foundation_Funding_Interests__c LIMIT 1];

        HAMCCInterestViewController.FundingInterestDTO dto =
            new HAMCCInterestViewController.FundingInterestDTO();
        dto.recordId      = alumni.Id;
        dto.isAlumni      = true;
        dto.interestValue = ffi.Id;
        dto.startDate     = Date.today();
        dto.activity      = 'Host a job shadow or immersion trip';
        dto.ownerId       = UserInfo.getUserId();
        dto.notes         = 'Test notes for funding interest';

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            List<ucinn_ascendv2__Funding_Interest__c> results =
                HAMCCInterestViewController.upsertFundingInterest(JSON.serialize(dto));
            Test.stopTest();

            System.assert(results.size() > 0, 'Returned list should include newly inserted record');
            Boolean found = false;
            for (ucinn_ascendv2__Funding_Interest__c fi : results) {
                if (fi.ucinn_ascendv2__Foundation_Funding_Interest__c == ffi.Id) {
                    found = true;
                }
            }
            System.assert(found, 'Inserted funding interest should be present in returned list');
        }
    }

    @IsTest
    static void testUpsertFundingInterestOrganization() {
        Account org = [SELECT Id FROM Account WHERE Name = 'Org A' LIMIT 1];
        ucinn_ascendv2__Foundation_Funding_Interests__c ffi =
            [SELECT Id FROM ucinn_ascendv2__Foundation_Funding_Interests__c LIMIT 1];

        HAMCCInterestViewController.FundingInterestDTO dto =
            new HAMCCInterestViewController.FundingInterestDTO();
        dto.recordId      = org.Id;
        dto.isAlumni      = false;
        dto.interestValue = ffi.Id;
        dto.startDate     = Date.today();
        dto.activity      = 'Host a job shadow or immersion trip';
        dto.notes         = 'Org test notes';

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            List<ucinn_ascendv2__Funding_Interest__c> results =
                HAMCCInterestViewController.upsertFundingInterest(JSON.serialize(dto));
            Test.stopTest();

            System.assert(results.size() > 0, 'Returned list should include newly inserted org record');
            Boolean found = false;
            for (ucinn_ascendv2__Funding_Interest__c fi : results) {
                if (fi.ucinn_ascendv2__Account__c == org.Id
                        && fi.ucinn_ascendv2__Foundation_Funding_Interest__c == ffi.Id) {
                    found = true;
                }
            }
            System.assert(found, 'Inserted org funding interest should be present in returned list');
        }
    }

    @IsTest
    static void testUpsertFundingInterestNullRecordId() {
        HAMCCInterestViewController.FundingInterestDTO dto =
            new HAMCCInterestViewController.FundingInterestDTO();
        dto.recordId = null;
        dto.isAlumni = true;

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                HAMCCInterestViewController.upsertFundingInterest(JSON.serialize(dto));
            } catch (Exception e) {
                exceptionThrown = true;
            }
            Test.stopTest();

            System.assert(exceptionThrown, 'AuraHandledException should be thrown for null recordId');
        }
    }

    // -------------------------
    // getActivityTypesByCategory
    // -------------------------

    @IsTest
    static void testGetActivityTypesByCategory() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Map<String, List<String>> result =
                HAMCCInterestViewController.getActivityTypesByCategory(
                    new List<String>{ 'Career Center' }
                );
            Test.stopTest();

            System.assertNotEquals(null, result, 'Result map should not be null');
            System.assert(result.containsKey('Career Center'), 'Result should contain Career Center key');
            System.assertNotEquals(null, result.get('Career Center'), 'Career Center values list should not be null');
        }
    }

    @IsTest
    static void testGetActivityTypesByCategoryUnknown() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Map<String, List<String>> result =
                HAMCCInterestViewController.getActivityTypesByCategory(
                    new List<String>{ 'Nonexistent Category' }
                );
            Test.stopTest();

            System.assertNotEquals(null, result, 'Result map should not be null');
            System.assert(!result.containsKey('Nonexistent Category'), 'Unknown category should not appear in result');
        }
    }
}