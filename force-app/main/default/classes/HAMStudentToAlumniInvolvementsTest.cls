@IsTest
private class HAMStudentToAlumniInvolvementsTest {

    @testSetup
    static void setupData() {
        // Create Account
        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        // Create Contact
        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'Student',
            AccountId = acc.Id
        );
        insert con;

        // Fetch Record Types by Developer Name
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.ucinn_ascendv2__Involvement__c
                .getRecordTypeInfosByDeveloperName();

        Id studentRT  = rtMap.get('Student_Involvement').getRecordTypeId();
        Id housingRT  = rtMap.get('Student_Housing').getRecordTypeId();

        List<ucinn_ascendv2__Involvement__c> involvements = new List<ucinn_ascendv2__Involvement__c>();
        ucinn_ascendv2__Involvement_Value__c studentInv = new ucinn_ascendv2__Involvement_Value__c(
            Name = 'Mens Basketball',ucinn_ascendv2__Involvement_Description__c = 'test',ucinn_ascendv2__Type__c = 'Student Involvement',HAM_Category__c = 'Student NCAA Athletics');        // Student Involvement
        insert studentInv;

        ucinn_ascendv2__Involvement_Value__c studentHouseInv = new ucinn_ascendv2__Involvement_Value__c(
            Name = 'House1',ucinn_ascendv2__Involvement_Description__c = 'test',ucinn_ascendv2__Type__c = 'Student Housing',HAM_Category__c = 'Student Housing');        // Student Involvement
        insert studentHouseInv;
        
            involvements.add(new ucinn_ascendv2__Involvement__c(
            RecordTypeId = studentRT,
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Account__c = acc.Id,
            ucinn_ascendv2__Involvement_Code__c = studentInv.Id,
            ucinn_ascendv2__Start_Date__c = Date.today().addDays(-2)
            //ucinn_ascendv2__End_Date__c   = Date.today().addDays(-1)
        ));

        // Student Housing Involvement
        involvements.add(new ucinn_ascendv2__Involvement__c(
            RecordTypeId = housingRT,
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Account__c = acc.Id,
            ucinn_ascendv2__Involvement_Code__c = studentHouseInv.Id,
            ucinn_ascendv2__Start_Date__c = Date.today().addDays(-3)
            //ucinn_ascendv2__End_Date__c   = Date.today().addDays(-2)
        ));

        insert involvements;
        system.debug('involvements--TC--'+involvements);
    }

    @IsTest
    static void testBatchCreatesAlumniInvolvements() {
        Test.startTest();
        HAMStudentToAlumniInvolvements batch =
            new HAMStudentToAlumniInvolvements();
        Database.executeBatch(batch, 50);
        Test.stopTest();

        // Fetch Alumni Record Type
        Id alumniRT =
            Schema.SObjectType.ucinn_ascendv2__Involvement__c
                .getRecordTypeInfosByDeveloperName()
                .get('Alumni_Involvement')
                .getRecordTypeId();

        // Verify Alumni Involvements were created
        List<ucinn_ascendv2__Involvement__c> alumniRecords =
            [SELECT Id,
                    RecordTypeId,
                    ucinn_ascendv2__Involvement_Code__c,
                    ucinn_ascendv2__Contact__c,
                    ucinn_ascendv2__Account__c,
                    ucinn_ascendv2__Start_Date__c,
                    ucinn_ascendv2__End_Date__c
             FROM ucinn_ascendv2__Involvement__c
             WHERE RecordTypeId = :alumniRT];

        System.assertEquals(
            2,
            alumniRecords.size(),
            'Two Alumni Involvements should be created'
        );

        for (ucinn_ascendv2__Involvement__c ai : alumniRecords) {
            System.assertNotEquals(null, ai.ucinn_ascendv2__Contact__c);
            System.assertNotEquals(null, ai.ucinn_ascendv2__Account__c);
            System.assertNotEquals(null, ai.ucinn_ascendv2__Involvement_Code__c);
        }
    }
}