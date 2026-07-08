@IsTest
private class hamCCVolunteerEngagementControllerTest {

    @TestSetup
    static void setup() {

        ucinn_ascendv2__Involvement_Value__c v1 =
            new ucinn_ascendv2__Involvement_Value__c(
                Name = 'Vol 1',
                ucinn_ascendv2__Type__c = 'Volunteer Engagement',
                HAM_Category__c = 'Career Center',
                HAM_CC_Score__c = 1,
                ucinn_ascendv2__Involvement_Description__c = 'test'
            );
        ucinn_ascendv2__Involvement_Value__c v2 =
            new ucinn_ascendv2__Involvement_Value__c(
                Name = 'Vol 2',
                ucinn_ascendv2__Type__c = 'Volunteer Engagement',
                HAM_Category__c = 'Career Center',
                HAM_CC_Score__c = 2,
                ucinn_ascendv2__Involvement_Description__c = 'test 2'
            );
        insert new List<ucinn_ascendv2__Involvement_Value__c>{ v1, v2 };

        Account acc = new Account(Name = 'Employer');
        insert acc;

        Contact con = new Contact(LastName = 'Alumni', AccountId = acc.Id);
        insert con;

        Id rt =
            Schema.SObjectType.ucinn_ascendv2__Involvement__c
                .getRecordTypeInfosByDeveloperName()
                .get('Volunteer_Engagement')
                .getRecordTypeId();

        Date today = Date.today();

        insert new List<ucinn_ascendv2__Involvement__c>{
            new ucinn_ascendv2__Involvement__c(
                RecordTypeId = rt,
                ucinn_ascendv2__Contact__c = con.Id,
                ucinn_ascendv2__Involvement_Code__c = v1.Id,
                ucinn_ascendv2__Start_Date__c = today
            ),
            new ucinn_ascendv2__Involvement__c(
                RecordTypeId = rt,
                ucinn_ascendv2__Account__c = acc.Id,
                ucinn_ascendv2__Involvement_Code__c = v2.Id,
                ucinn_ascendv2__Start_Date__c = today.addYears(-1)
            )
        };
    }

    @IsTest
    static void testGetEngagement_Alumni() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        hamCCVolunteerEngagementController.CCEngagementData r =
            hamCCVolunteerEngagementController.getEngagementData(c.Id, true);

        System.assertEquals(1, r.ccInvolvments.size());
        System.assertEquals(1, r.currentYearScore);
    }

    @IsTest
    static void testGetEngagement_Employer() {
        Account a = [SELECT Id FROM Account LIMIT 1];

        hamCCVolunteerEngagementController.CCEngagementData r =
            hamCCVolunteerEngagementController.getEngagementData(a.Id, false);

        System.assertEquals(2, r.ccInvolvments.size());
        System.assertEquals(2, r.lastYearScore);
    }

    @IsTest
    static void testInsertInvolvement_Positive() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        ucinn_ascendv2__Involvement_Value__c v =
            [SELECT Id FROM ucinn_ascendv2__Involvement_Value__c LIMIT 1];

        hamCCVolunteerEngagementController.ActivityWrapper dto =
            new hamCCVolunteerEngagementController.ActivityWrapper();
        dto.recordid = c.Id;
        dto.isAlumni = true;
        dto.involvmentCode = v.Id;
        dto.startDate = String.valueOf(Date.today());

        hamCCVolunteerEngagementController.CCEngagementData r =
            hamCCVolunteerEngagementController.insertInvolvement(
                JSON.serialize(dto)
            );

        System.assert(r.ccInvolvments.size() > 1);
    }

    @IsTest
    static void testInsertInvolvement_Invalid() {
        try {
            hamCCVolunteerEngagementController.insertInvolvement('{}');
            System.assert(false);
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('Invalid input'));
        }
    }

    @IsTest
    static void testNullRecordIdSafe() {
        hamCCVolunteerEngagementController.CCEngagementData r =
            hamCCVolunteerEngagementController.getEngagementData(null, true);

        System.assertEquals(0, r.ccInvolvments.size());
    }

    @IsTest
    static void testUpdateInvolvement_Alumni_Positive() {
        // Get test data
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        ucinn_ascendv2__Involvement__c inv = [
            SELECT Id, ucinn_ascendv2__Start_Date__c, ucinn_ascendv2__End_Date__c,
                   HAM_Handshake_Link__c, OwnerId, ucinn_ascendv2__Involvement_Code__c
            FROM ucinn_ascendv2__Involvement__c 
            WHERE ucinn_ascendv2__Contact__c = :c.Id 
            LIMIT 1
        ];
        
        // Get a different involvement value for update
        ucinn_ascendv2__Involvement_Value__c newValue = [
            SELECT Id 
            FROM ucinn_ascendv2__Involvement_Value__c 
            WHERE Id != :inv.ucinn_ascendv2__Involvement_Code__c 
            LIMIT 1
        ];

        // Create update payload
        hamCCVolunteerEngagementController.UpdateWrapper dto =
            new hamCCVolunteerEngagementController.UpdateWrapper();
        dto.recordId = inv.Id;
        dto.parentRecordId = c.Id;
        dto.isAlumni = true;
        dto.startDate = String.valueOf(Date.today().addDays(5));
        dto.endDate = String.valueOf(Date.today().addDays(10));
        dto.involvmentCode = newValue.Id;
        dto.handshakeLink = 'https://test.example.com/handshake';
        dto.representativeId = UserInfo.getUserId();

        Test.startTest();
        hamCCVolunteerEngagementController.CCEngagementData result =
            hamCCVolunteerEngagementController.updateInvolvement(
                JSON.serialize(dto)
            );
        Test.stopTest();

        // Verify the update
        ucinn_ascendv2__Involvement__c updatedInv = [
            SELECT Id, ucinn_ascendv2__Start_Date__c, ucinn_ascendv2__End_Date__c,
                   HAM_Handshake_Link__c, OwnerId, ucinn_ascendv2__Involvement_Code__c
            FROM ucinn_ascendv2__Involvement__c 
            WHERE Id = :inv.Id
        ];

        System.assertEquals(Date.valueOf(dto.startDate), updatedInv.ucinn_ascendv2__Start_Date__c, 'Start date should be updated');
        System.assertEquals(Date.valueOf(dto.endDate), updatedInv.ucinn_ascendv2__End_Date__c, 'End date should be updated');
        System.assertEquals(dto.handshakeLink, updatedInv.HAM_Handshake_Link__c, 'Handshake link should be updated');
        System.assertEquals(dto.representativeId, updatedInv.OwnerId, 'Owner should be updated');
        System.assertEquals(newValue.Id, updatedInv.ucinn_ascendv2__Involvement_Code__c, 'Involvement code should be updated');
        
        // Verify result contains updated data
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.ccInvolvments.size() > 0, 'Should return involvement records');
    }

    @IsTest
    static void testUpdateInvolvement_Employer_Positive() {
        // Get test data
        Account acc = [SELECT Id FROM Account LIMIT 1];
        ucinn_ascendv2__Involvement__c inv = [
            SELECT Id, ucinn_ascendv2__Start_Date__c, HAM_Handshake_Link__c
            FROM ucinn_ascendv2__Involvement__c 
            WHERE ucinn_ascendv2__Account__c = :acc.Id 
            LIMIT 1
        ];

        // Create update payload with partial data
        hamCCVolunteerEngagementController.UpdateWrapper dto =
            new hamCCVolunteerEngagementController.UpdateWrapper();
        dto.recordId = inv.Id;
        dto.parentRecordId = acc.Id;
        dto.isAlumni = false;
        dto.startDate = String.valueOf(Date.today().addDays(-30));
        dto.handshakeLink = 'https://employer.handshake.com/events/12345';

        Test.startTest();
        hamCCVolunteerEngagementController.CCEngagementData result =
            hamCCVolunteerEngagementController.updateInvolvement(
                JSON.serialize(dto)
            );
        Test.stopTest();

        // Verify the update
        ucinn_ascendv2__Involvement__c updatedInv = [
            SELECT Id, ucinn_ascendv2__Start_Date__c, HAM_Handshake_Link__c
            FROM ucinn_ascendv2__Involvement__c 
            WHERE Id = :inv.Id
        ];

        System.assertEquals(Date.valueOf(dto.startDate), updatedInv.ucinn_ascendv2__Start_Date__c, 'Start date should be updated');
        System.assertEquals(dto.handshakeLink, updatedInv.HAM_Handshake_Link__c, 'Handshake link should be updated');
        
        // Verify result
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(2, result.ccInvolvments.size(), 'Should return both employer involvements');
    }

    @IsTest
    static void testUpdateInvolvement_InvalidRecordId() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        // Create update payload with non-existent record ID
        hamCCVolunteerEngagementController.UpdateWrapper dto =
            new hamCCVolunteerEngagementController.UpdateWrapper();
        dto.recordId = '0011234567890ABC'; // Fake ID
        dto.parentRecordId = c.Id;
        dto.isAlumni = true;
        dto.startDate = String.valueOf(Date.today());

        Test.startTest();
        try {
            hamCCVolunteerEngagementController.updateInvolvement(
                JSON.serialize(dto)
            );
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('not found'), 'Should indicate record not found');
        }
        Test.stopTest();
    }

    @IsTest
    static void testUpdateInvolvement_MissingRequiredFields() {
        // Test with missing recordId
        hamCCVolunteerEngagementController.UpdateWrapper dto1 =
            new hamCCVolunteerEngagementController.UpdateWrapper();
        dto1.parentRecordId = '0031234567890ABC';
        dto1.isAlumni = true;

        try {
            hamCCVolunteerEngagementController.updateInvolvement(
                JSON.serialize(dto1)
            );
            System.assert(false, 'Should have thrown an exception for missing recordId');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('Invalid input'), 'Should indicate invalid input');
        }

        // Test with missing parentRecordId
        hamCCVolunteerEngagementController.UpdateWrapper dto2 =
            new hamCCVolunteerEngagementController.UpdateWrapper();
        dto2.recordId = '0011234567890ABC';
        dto2.isAlumni = true;

        try {
            hamCCVolunteerEngagementController.updateInvolvement(
                JSON.serialize(dto2)
            );
            System.assert(false, 'Should have thrown an exception for missing parentRecordId');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('Invalid input'), 'Should indicate invalid input');
        }

        // Test with missing isAlumni
        hamCCVolunteerEngagementController.UpdateWrapper dto3 =
            new hamCCVolunteerEngagementController.UpdateWrapper();
        dto3.recordId = '0011234567890ABC';
        dto3.parentRecordId = '0031234567890ABC';

        try {
            hamCCVolunteerEngagementController.updateInvolvement(
                JSON.serialize(dto3)
            );
            System.assert(false, 'Should have thrown an exception for missing isAlumni');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('Invalid input'), 'Should indicate invalid input');
        }
    }

    @IsTest
    static void testUpdateInvolvement_EmptyPayload() {
        try {
            hamCCVolunteerEngagementController.updateInvolvement('{}');
            System.assert(false, 'Should have thrown an exception for empty payload');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('Invalid input'), 'Should indicate invalid input');
        }
    }

    @IsTest
    static void testGetInvolvementDescriptionValues() {
        Test.startTest();
        List<String> values = hamCCVolunteerEngagementController.getInvolvementDescriptionValues();
        Test.stopTest();
        System.assertNotEquals(null, values, 'Should return a list');
    }

    @IsTest
    static void testGetQuickSelectCodes_NoUsage() {
        Test.startTest();
        hamCCVolunteerEngagementController.QuickSelectResult res =
            hamCCVolunteerEngagementController.getQuickSelectCodes();
        Test.stopTest();
        System.assertNotEquals(null, res, 'Should return a result');
        System.assertNotEquals(null, res.topCodes, 'topCodes should not be null');
        System.assertNotEquals(null, res.moreCodes, 'moreCodes should not be null');
    }

    @IsTest
    static void testGetQuickSelectCodes_WithUsage() {
        Id rt = Schema.SObjectType.ucinn_ascendv2__Involvement__c
            .getRecordTypeInfosByDeveloperName()
            .get('Volunteer_Engagement')
            .getRecordTypeId();

        ucinn_ascendv2__Involvement_Value__c v =
            new ucinn_ascendv2__Involvement_Value__c(
                Name = 'Quick Test',
                ucinn_ascendv2__Type__c = 'Volunteer Engagement',
                HAM_Category__c = 'Career Center',
                HAM_CC_Score__c = 1,
                HAM_Volunteer_Activity__c = true,
                ucinn_ascendv2__Involvement_Description__c = 'test'
            );
        insert v;

        Contact c = [SELECT Id FROM Contact LIMIT 1];

        List<ucinn_ascendv2__Involvement__c> invs = new List<ucinn_ascendv2__Involvement__c>();
        for (Integer i = 0; i < 4; i++) {
            invs.add(new ucinn_ascendv2__Involvement__c(
                RecordTypeId = rt,
                ucinn_ascendv2__Contact__c = c.Id,
                ucinn_ascendv2__Involvement_Code__c = v.Id,
                ucinn_ascendv2__Start_Date__c = Date.today()
            ));
        }
        insert invs;

        Test.startTest();
        hamCCVolunteerEngagementController.QuickSelectResult res =
            hamCCVolunteerEngagementController.getQuickSelectCodes();
        Test.stopTest();

        System.assertEquals(1, res.topCodes.size(), 'Should have 1 top code with 4 uses');
    }

    @IsTest
    static void testInsertInvolvement_WithDescription() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        ucinn_ascendv2__Involvement_Value__c v =
            [SELECT Id FROM ucinn_ascendv2__Involvement_Value__c LIMIT 1];

        hamCCVolunteerEngagementController.ActivityWrapper dto =
            new hamCCVolunteerEngagementController.ActivityWrapper();
        dto.recordid = c.Id;
        dto.isAlumni = true;
        dto.involvmentCode = v.Id;
        dto.startDate = String.valueOf(Date.today());
        dto.involvementDescription = 'Golf Attendee';

        Test.startTest();
        hamCCVolunteerEngagementController.CCEngagementData r =
            hamCCVolunteerEngagementController.insertInvolvement(JSON.serialize(dto));
        Test.stopTest();

        ucinn_ascendv2__Involvement__c inserted = [
            SELECT ucinn_ascendv2__Involvement_Description__c
            FROM ucinn_ascendv2__Involvement__c
            WHERE ucinn_ascendv2__Contact__c = :c.Id
            AND ucinn_ascendv2__Involvement_Description__c = 'Golf Attendee'
            LIMIT 1
        ];
        System.assertEquals('Golf Attendee', inserted.ucinn_ascendv2__Involvement_Description__c);
    }

    @IsTest
    static void testUpdateInvolvement_WithDescription() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        ucinn_ascendv2__Involvement__c inv = [
            SELECT Id FROM ucinn_ascendv2__Involvement__c
            WHERE ucinn_ascendv2__Contact__c = :c.Id LIMIT 1
        ];

        hamCCVolunteerEngagementController.UpdateWrapper dto =
            new hamCCVolunteerEngagementController.UpdateWrapper();
        dto.recordId = inv.Id;
        dto.parentRecordId = c.Id;
        dto.isAlumni = true;
        dto.involvementDescription = 'Summer Leadership Program';

        Test.startTest();
        hamCCVolunteerEngagementController.updateInvolvement(JSON.serialize(dto));
        Test.stopTest();

        ucinn_ascendv2__Involvement__c updated = [
            SELECT ucinn_ascendv2__Involvement_Description__c
            FROM ucinn_ascendv2__Involvement__c
            WHERE Id = :inv.Id
        ];
        System.assertEquals('Summer Leadership Program', updated.ucinn_ascendv2__Involvement_Description__c);
    }

    @IsTest
    static void testInsertInvolvement_BlankDates() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        ucinn_ascendv2__Involvement_Value__c v =
            [SELECT Id FROM ucinn_ascendv2__Involvement_Value__c LIMIT 1];

        hamCCVolunteerEngagementController.ActivityWrapper dto =
            new hamCCVolunteerEngagementController.ActivityWrapper();
        dto.recordid = c.Id;
        dto.isAlumni = true;
        dto.involvmentCode = v.Id;
        dto.startDate = '';
        dto.endDate = '';

        Test.startTest();
        hamCCVolunteerEngagementController.CCEngagementData r =
            hamCCVolunteerEngagementController.insertInvolvement(JSON.serialize(dto));
        Test.stopTest();

        System.assert(r.ccInvolvments.size() > 0, 'Should insert with blank dates defaulting to today');
    }
}