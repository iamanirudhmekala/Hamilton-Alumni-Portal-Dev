@IsTest
private class HAM_ServiceIndicatorFlagHandlerTest {

    @TestSetup
    static void setup() {
        Account a = HAMJediTestDataFactory.makeAccount('Test Account');
        Contact c = new Contact(
            LastName = 'FlagTest',
            AccountId = a.Id,
            HAM_Send_Athletic_Updates__c      = true,
            HAM_Send_College_Updates__c       = true,
            HAM_Send_Event_Invitations__c     = true,
            HAM_Send_Hamilton_Headlines__c    = true,
            HAM_Send_Virtual_Events_Digest__c = true,
            HAM_Send_Impact_Report__c         = true,
            HAM_Hamilton_Calendar__c          = true
        );
        insert c;
    }

    private static Contact getContact() {
        return [
            SELECT Id,
                   HAM_Send_Athletic_Updates__c,
                   HAM_Send_College_Updates__c,
                   HAM_Send_Event_Invitations__c,
                   HAM_Send_Hamilton_Headlines__c,
                   HAM_Send_Virtual_Events_Digest__c,
                   HAM_Send_Impact_Report__c,
                   HAM_Hamilton_Calendar__c
            FROM Contact
            WHERE LastName = 'FlagTest'
            LIMIT 1
        ];
    }

    @IsTest
    static void testActiveSIUnchecksFlag() {
        Contact c = getContact();

        HAM_ServiceIndicatorFlagHandler.FlowInput input = new HAM_ServiceIndicatorFlagHandler.FlowInput();
        input.contactId = c.Id;
        input.serviceIndicatorValueName = 'Do Not Send Athletic Updates';
        input.isActive = true;

        Test.startTest();
        HAM_ServiceIndicatorFlagHandler.updateFlags(new List<HAM_ServiceIndicatorFlagHandler.FlowInput>{ input });
        Test.stopTest();

        Contact result = getContact();
        System.assertEquals(false, result.HAM_Send_Athletic_Updates__c, 'Active SI should uncheck the flag');
        System.assertEquals(true,  result.HAM_Send_College_Updates__c,  'Other flags should be unchanged');
    }

    @IsTest
    static void testInactiveSIRechecksFlag() {
        Contact c = getContact();
        // Pre-uncheck the flag
        c.HAM_Send_Hamilton_Headlines__c = false;
        update c;

        HAM_ServiceIndicatorFlagHandler.FlowInput input = new HAM_ServiceIndicatorFlagHandler.FlowInput();
        input.contactId = c.Id;
        input.serviceIndicatorValueName = 'Do Not Send Hamilton Headlines';
        input.isActive = false;

        Test.startTest();
        HAM_ServiceIndicatorFlagHandler.updateFlags(new List<HAM_ServiceIndicatorFlagHandler.FlowInput>{ input });
        Test.stopTest();

        Contact result = getContact();
        System.assertEquals(true, result.HAM_Send_Hamilton_Headlines__c, 'Inactive SI should recheck the flag');
    }

    @IsTest
    static void testUnknownSINameNoChange() {
        Contact c = getContact();

        HAM_ServiceIndicatorFlagHandler.FlowInput input = new HAM_ServiceIndicatorFlagHandler.FlowInput();
        input.contactId = c.Id;
        input.serviceIndicatorValueName = 'Some Unknown Indicator';
        input.isActive = true;

        Test.startTest();
        HAM_ServiceIndicatorFlagHandler.updateFlags(new List<HAM_ServiceIndicatorFlagHandler.FlowInput>{ input });
        Test.stopTest();

        Contact result = getContact();
        System.assertEquals(true, result.HAM_Send_Athletic_Updates__c,      'Unknown SI — no flags should change');
        System.assertEquals(true, result.HAM_Send_College_Updates__c,       'Unknown SI — no flags should change');
        System.assertEquals(true, result.HAM_Send_Event_Invitations__c,     'Unknown SI — no flags should change');
        System.assertEquals(true, result.HAM_Send_Hamilton_Headlines__c,    'Unknown SI — no flags should change');
        System.assertEquals(true, result.HAM_Send_Virtual_Events_Digest__c, 'Unknown SI — no flags should change');
        System.assertEquals(true, result.HAM_Send_Impact_Report__c,         'Unknown SI — no flags should change');
        System.assertEquals(true, result.HAM_Hamilton_Calendar__c,          'Unknown SI — no flags should change');
    }

    @IsTest
    static void testNullContactIdNoError() {
        HAM_ServiceIndicatorFlagHandler.FlowInput input = new HAM_ServiceIndicatorFlagHandler.FlowInput();
        input.contactId = null;
        input.serviceIndicatorValueName = 'Do Not Send College Updates';
        input.isActive = true;

        Test.startTest();
        try {
            HAM_ServiceIndicatorFlagHandler.updateFlags(new List<HAM_ServiceIndicatorFlagHandler.FlowInput>{ input });
        } catch (Exception e) {
            System.assert(false, 'Null contactId should not throw: ' + e.getMessage());
        }
        Test.stopTest();
    }
}