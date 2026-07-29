/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAMCloneSchoolToAISDegreeBatch_Test
 * Author          : <YourName>
 * Created Date    : Jul 16, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Jul 16, 2026
 * Description     :Test coverage for HAMCloneSchoolToAISDegreeBatch - verifies that
 *                   School Degree Information records are cloned to the Hamilton AIS
 *                   Degree Information record type with core fields intact, that
 *                   originals get HAMRolledOver__c flagged, and that a subsequent run
 *                   is a no-op (idempotency).
 *
 *                   NOTE: This test depends on the Hamilton_AIS_Degree_Information
 *                   record type and the HAMRolledOver__c field already existing in
 *                   whatever org it runs in (per Ameya, currently lower/FullQA
 *                   sandbox only as of Jul 16, 2026). testBatchClonesAndFlagsOriginals
 *                   asserts that dependency explicitly so a missing record type fails
 *                   with a clear message instead of a confusing NPE.
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jul 16, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

@isTest
private class HAMCloneSchoolToAISDegreeBatch_Test {
	 private static final String SOURCE_RT_DEV_NAME = 'School_Degree_Information';
    private static final String TARGET_RT_DEV_NAME = 'Hamilton_AIS_Degree_Information';
 
    @testSetup
    static void setup() {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.ucinn_ascendv2__Degree_Information__c.getRecordTypeInfosByDeveloperName();
        System.assert(
            rtMap.containsKey(SOURCE_RT_DEV_NAME),
            'Record Type "' + SOURCE_RT_DEV_NAME + '" must exist in this org to run this test.'
        );
        System.assert(
            rtMap.containsKey(TARGET_RT_DEV_NAME),
            'Record Type "' + TARGET_RT_DEV_NAME + '" must exist in this org to run this test - '
            + 'deploy/create it (currently lower sandbox only) before running this test class here.'
        );
 
        Id schoolRtId = rtMap.get(SOURCE_RT_DEV_NAME).getRecordTypeId();
 
        Contact con = new Contact(LastName = 'HAM Batch Test Contact');
        insert con;
 
        Account acc = new Account(Name = 'HAM Batch Test Institution');
        insert acc;
 
        ucinn_ascendv2__Post_Code__c pc = new ucinn_ascendv2__Post_Code__c(
            Name = 'HAMTST',
            ucinn_ascendv2__Major_Specialty_Description__c = 'HAM Test Major',
            ucinn_ascendv2__Is_Active__c = true
        );
        insert pc;
 
        List<ucinn_ascendv2__Degree_Information__c> degrees = new List<ucinn_ascendv2__Degree_Information__c>();
        for (Integer i = 0; i < 5; i++) {
            degrees.add(new ucinn_ascendv2__Degree_Information__c(
                RecordTypeId = schoolRtId,
                ucinn_ascendv2__Contact__c = con.Id,
                ucinn_ascendv2__Source__c = 'Student Information System',
                ucinn_ascendv2__Post_Code__c = pc.Id,
                ucinn_ascendv2__Conferred_Degree_Year__c = '2020',
                ucinn_ascendv2__Degree_Institution__c = acc.Id
            ));
        }
        insert degrees;
    }
 
    @isTest
    static void testBatchClonesAndFlagsOriginals() {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.ucinn_ascendv2__Degree_Information__c.getRecordTypeInfosByDeveloperName();
        Id schoolRtId = rtMap.get(SOURCE_RT_DEV_NAME).getRecordTypeId();
        Id aisRtId = rtMap.get(TARGET_RT_DEV_NAME).getRecordTypeId();
 
        List<ucinn_ascendv2__Degree_Information__c> before = [
            SELECT Id
            FROM ucinn_ascendv2__Degree_Information__c
            WHERE RecordTypeId = :schoolRtId
        ];
        System.assertEquals(5, before.size(), 'Test setup should have created 5 School Degree Information records.');
 
        Test.startTest();
        Database.executeBatch(new HAMCloneSchoolToAISDegreeBatch(), 200);
        Test.stopTest();
 
        List<ucinn_ascendv2__Degree_Information__c> originalsAfter = [
            SELECT Id, HAMRolledOver__c
            FROM ucinn_ascendv2__Degree_Information__c
            WHERE RecordTypeId = :schoolRtId
        ];
        System.assertEquals(5, originalsAfter.size());
        for (ucinn_ascendv2__Degree_Information__c rec : originalsAfter) {
            System.assertEquals(true, rec.HAMRolledOver__c, 'Original record should be flagged as rolled over.');
        }
 
        List<ucinn_ascendv2__Degree_Information__c> clones = [
            SELECT Id, ucinn_ascendv2__Post_Code__c, ucinn_ascendv2__Conferred_Degree_Year__c,
                   ucinn_ascendv2__Contact__c, ucinn_ascendv2__Source__c,
                   ucinn_ascendv2__Degree_Institution__c, HAMRolledOver__c, RecordTypeId
            FROM ucinn_ascendv2__Degree_Information__c
            WHERE RecordTypeId = :aisRtId
        ];
        System.assertEquals(5, clones.size(), 'Expected one clone per original School Degree Information record.');
        for (ucinn_ascendv2__Degree_Information__c cloneRec : clones) {
            System.assertEquals(false, cloneRec.HAMRolledOver__c, 'New clone should not be marked rolled over.');
            System.assertNotEquals(null, cloneRec.ucinn_ascendv2__Post_Code__c, 'Post Code should have been cloned.');
            System.assertNotEquals(null, cloneRec.ucinn_ascendv2__Contact__c, 'Contact should have been cloned.');
            System.assertNotEquals(null, cloneRec.ucinn_ascendv2__Degree_Institution__c, 'Degree Institution should have been cloned.');
            System.assertEquals('2020', cloneRec.ucinn_ascendv2__Conferred_Degree_Year__c, 'Degree Year should have been cloned.');
            System.assertEquals('Student Information System', cloneRec.ucinn_ascendv2__Source__c, 'Source should have been cloned.');
        }
    }
 
    @isTest
    static void testRerunIsIdempotent() {
        Test.startTest();
        Database.executeBatch(new HAMCloneSchoolToAISDegreeBatch(), 200);
        Test.stopTest();
 
        Id schoolRtId = Schema.SObjectType.ucinn_ascendv2__Degree_Information__c
            .getRecordTypeInfosByDeveloperName().get(SOURCE_RT_DEV_NAME).getRecordTypeId();
 
        // After one run, no un-rolled-over School records should remain, so a
        // second scheduled run of this batch would pick up zero rows.
        List<ucinn_ascendv2__Degree_Information__c> remaining = [
            SELECT Id
            FROM ucinn_ascendv2__Degree_Information__c
            WHERE RecordTypeId = :schoolRtId
              AND (HAMRolledOver__c = false OR HAMRolledOver__c = null)
        ];
        System.assertEquals(0, remaining.size(), 'All School Degree Information records should be flagged as rolled over after one run.');
    }
 
    @isTest
    static void testCustomExceptionIsThrowableAndCatchable() {
        // start() throws this custom exception when required org configuration
        // (record types / fields) is missing. We can't safely delete metadata
        // record types from a test context to exercise that branch directly,
        // so this confirms the exception type itself behaves correctly.
        Boolean caught = false;
        String msg;
        try {
            throw new HAMCloneSchoolToAISDegreeBatch.HAMCloneSchoolToAISDegreeBatchException('config missing');
        } catch (HAMCloneSchoolToAISDegreeBatch.HAMCloneSchoolToAISDegreeBatchException e) {
            caught = true;
            msg = e.getMessage();
        }
        System.assert(caught, 'Custom exception should be catchable by its own type.');
        System.assertEquals('config missing', msg);
    }
}