@IsTest
private class HAM_ServiceIndicatorFlagBatchTest {

    @TestSetup
    static void setup() {
        Account a = HAMJediTestDataFactory.makeAccount('SI Flag Batch Test Acct');

        // 3 Contacts, all flags defaulted to true
        List<Contact> contacts = new List<Contact>{
            new Contact(LastName = 'BatchTest1', AccountId = a.Id,
                HAM_Send_Athletic_Updates__c=true, HAM_Send_College_Updates__c=true,
                HAM_Send_Event_Invitations__c=true, HAM_Send_Hamilton_Headlines__c=true,
                HAM_Send_Virtual_Events_Digest__c=true, HAM_Send_Impact_Report__c=true,
                HAM_Hamilton_Calendar__c=true),
            new Contact(LastName = 'BatchTest2', AccountId = a.Id,
                HAM_Send_Athletic_Updates__c=true, HAM_Send_College_Updates__c=true,
                HAM_Send_Event_Invitations__c=true, HAM_Send_Hamilton_Headlines__c=true,
                HAM_Send_Virtual_Events_Digest__c=true, HAM_Send_Impact_Report__c=true,
                HAM_Hamilton_Calendar__c=true),
            new Contact(LastName = 'BatchTest3', AccountId = a.Id,
                HAM_Send_Athletic_Updates__c=true, HAM_Send_College_Updates__c=true,
                HAM_Send_Event_Invitations__c=true, HAM_Send_Hamilton_Headlines__c=true,
                HAM_Send_Virtual_Events_Digest__c=true, HAM_Send_Impact_Report__c=true,
                HAM_Hamilton_Calendar__c=true)
        };
        insert contacts;

        // SI Value records for all 7 names
        List<ucinn_ascendv2__Service_Indicator_Value__c> siValues = new List<ucinn_ascendv2__Service_Indicator_Value__c>{
            new ucinn_ascendv2__Service_Indicator_Value__c(Name = 'Do Not Send Athletic Updates'),
            new ucinn_ascendv2__Service_Indicator_Value__c(Name = 'Do Not Send College Updates'),
            new ucinn_ascendv2__Service_Indicator_Value__c(Name = 'Do Not Send Event Invitations'),
            new ucinn_ascendv2__Service_Indicator_Value__c(Name = 'Do Not Send Hamilton Headlines'),
            new ucinn_ascendv2__Service_Indicator_Value__c(Name = 'Do Not Send Virtual Events Digest'),
            new ucinn_ascendv2__Service_Indicator_Value__c(Name = 'Do Not Sent Impact Report'),
            new ucinn_ascendv2__Service_Indicator_Value__c(Name = 'No Hamilton Calendar')
        };
        insert siValues;

        Map<String, Id> valueIdByName = new Map<String, Id>();
        for (ucinn_ascendv2__Service_Indicator_Value__c v : siValues) {
            valueIdByName.put(v.Name, v.Id);
        }

        // Contact 1: 2 active SIs (Athletic + Calendar), 1 inactive (College)
        // Contact 2: 1 active SI (Hamilton Headlines)
        // Contact 3: no SIs — not inserted, stays out of batch scope
        List<ucinn_ascendv2__Service_Indicator__c> sis = new List<ucinn_ascendv2__Service_Indicator__c>{
            new ucinn_ascendv2__Service_Indicator__c(
                ucinn_ascendv2__Contact__c = contacts[0].Id,
                ucinn_ascendv2__Service_Indicator_Value__c = valueIdByName.get('Do Not Send Athletic Updates'),
                ucinn_ascendv2__Is_Active__c = true
            ),
            new ucinn_ascendv2__Service_Indicator__c(
                ucinn_ascendv2__Contact__c = contacts[0].Id,
                ucinn_ascendv2__Service_Indicator_Value__c = valueIdByName.get('No Hamilton Calendar'),
                ucinn_ascendv2__Is_Active__c = true
            ),
            new ucinn_ascendv2__Service_Indicator__c(
                ucinn_ascendv2__Contact__c = contacts[0].Id,
                ucinn_ascendv2__Service_Indicator_Value__c = valueIdByName.get('Do Not Send College Updates'),
                ucinn_ascendv2__Is_Active__c = false
            ),
            new ucinn_ascendv2__Service_Indicator__c(
                ucinn_ascendv2__Contact__c = contacts[1].Id,
                ucinn_ascendv2__Service_Indicator_Value__c = valueIdByName.get('Do Not Send Hamilton Headlines'),
                ucinn_ascendv2__Is_Active__c = true
            )
        };
        insert sis;
    }

    private static Map<String, Contact> getContacts() {
        Map<String, Contact> result = new Map<String, Contact>();
        for (Contact c : [
            SELECT LastName,
                   HAM_Send_Athletic_Updates__c, HAM_Send_College_Updates__c,
                   HAM_Send_Event_Invitations__c, HAM_Send_Hamilton_Headlines__c,
                   HAM_Send_Virtual_Events_Digest__c, HAM_Send_Impact_Report__c,
                   HAM_Hamilton_Calendar__c
            FROM Contact
            WHERE LastName LIKE 'BatchTest%'
        ]) {
            result.put(c.LastName, c);
        }
        return result;
    }

    @IsTest
    static void testActiveSIUnchecksFlag() {
        Test.startTest();
        Database.executeBatch(new HAM_ServiceIndicatorFlagBatch(), 200);
        Test.stopTest();

        Map<String, Contact> contacts = getContacts();
        Contact c1 = contacts.get('BatchTest1');

        System.assertEquals(false, c1.HAM_Send_Athletic_Updates__c, 'Active Athletic SI should uncheck flag');
        System.assertEquals(false, c1.HAM_Hamilton_Calendar__c,     'Active Calendar SI should uncheck flag');
    }

    @IsTest
    static void testInactiveSIFlagStaysTrue() {
        Test.startTest();
        Database.executeBatch(new HAM_ServiceIndicatorFlagBatch(), 200);
        Test.stopTest();

        Map<String, Contact> contacts = getContacts();
        Contact c1 = contacts.get('BatchTest1');

        System.assertEquals(true, c1.HAM_Send_College_Updates__c, 'Inactive College SI — flag should stay true');
    }

    @IsTest
    static void testContact2OnlyItsOwnFlagUnchecked() {
        Test.startTest();
        Database.executeBatch(new HAM_ServiceIndicatorFlagBatch(), 200);
        Test.stopTest();

        Map<String, Contact> contacts = getContacts();
        Contact c2 = contacts.get('BatchTest2');

        System.assertEquals(false, c2.HAM_Send_Hamilton_Headlines__c, 'Active Headlines SI should uncheck flag');
        System.assertEquals(true,  c2.HAM_Send_Athletic_Updates__c,   'No Athletic SI on this contact — should stay true');
        System.assertEquals(true,  c2.HAM_Hamilton_Calendar__c,       'No Calendar SI on this contact — should stay true');
    }

    @IsTest
    static void testContactWithNoSIsNotAffected() {
        Test.startTest();
        Database.executeBatch(new HAM_ServiceIndicatorFlagBatch(), 200);
        Test.stopTest();

        Map<String, Contact> contacts = getContacts();
        Contact c3 = contacts.get('BatchTest3');

        // BatchTest3 had no SIs, so it was never in batch scope — flags unchanged from setup
        System.assertEquals(true, c3.HAM_Send_Athletic_Updates__c,      'No-SI contact flags should be unchanged');
        System.assertEquals(true, c3.HAM_Send_Hamilton_Headlines__c,    'No-SI contact flags should be unchanged');
        System.assertEquals(true, c3.HAM_Hamilton_Calendar__c,          'No-SI contact flags should be unchanged');
    }

    @IsTest
    static void testBatchCompletesWithoutException() {
        Test.startTest();
        Id jobId = Database.executeBatch(new HAM_ServiceIndicatorFlagBatch(), 200);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job should have been enqueued');
    }
}