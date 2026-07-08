@IsTest
private class PledgeHelperTest {

    @IsTest
    static void testGetPledges_returnsEmptyListWhenNoMatchingPledges() {
        Account acct = new Account(
            Name = 'Pledge Helper Test Account'
        );
        insert acct;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'pledgehelpertest+' + DateTime.now().getTime() + '@example.com',
            AccountId = acct.Id
        );
        insert con;

        Test.startTest();
        List<HamGivingController.PledgeWrapper> results = PledgeHelper.getPledges(con.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Method should return a list, not null.');
        System.assertEquals(0, results.size(), 'Expected no pledges for a contact with no matching pledge Opportunities.');
    }
}