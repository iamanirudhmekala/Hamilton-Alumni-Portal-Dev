@isTest
private class HAM_PortalLoginHistoryControllerTest {

    // LoginHistory can't be inserted or reliably seeded in test context, and real User
    // records (unlike most org data) are visible to tests by default without
    // SeeAllData=true. So these assertions are intentionally shape/behavior-based rather
    // than count-based - they hold no matter what portal users or login history exist
    // in the org the tests happen to run against.

    @isTest
    static void testSearchPortalLogins_blankSearchTermReturnsAllPortalUsers() {
        Test.startTest();
        List<HAM_PortalLoginHistoryController.LoginRow> nullTermResult =
            HAM_PortalLoginHistoryController.searchPortalLogins(null, 180);
        List<HAM_PortalLoginHistoryController.LoginRow> blankTermResult =
            HAM_PortalLoginHistoryController.searchPortalLogins('   ', 180);
        List<HAM_PortalLoginHistoryController.LoginRow> narrowedResult =
            HAM_PortalLoginHistoryController.searchPortalLogins('a', 180);
        Test.stopTest();

        System.assertEquals(nullTermResult.size(), blankTermResult.size(),
            'Null and whitespace-only terms must both mean "all portal users" and return the same rows');
        System.assert(blankTermResult.size() >= narrowedResult.size(),
            'The default all-users view can never return fewer rows than a narrowed search');
    }

    @isTest
    static void testSearchPortalLogins_noMatchingNameReturnsEmptyList() {
        Test.startTest();
        List<HAM_PortalLoginHistoryController.LoginRow> results =
            HAM_PortalLoginHistoryController.searchPortalLogins('Zzzznonexistentnamezzzz12345', 180);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'A name matching no portal user must return an empty list');
    }

    @isTest
    static void testSearchPortalLogins_nonPositiveDaysDefaultsWithoutError() {
        Test.startTest();
        List<HAM_PortalLoginHistoryController.LoginRow> nullDaysResult =
            HAM_PortalLoginHistoryController.searchPortalLogins('a', null);
        List<HAM_PortalLoginHistoryController.LoginRow> zeroDaysResult =
            HAM_PortalLoginHistoryController.searchPortalLogins('a', 0);
        List<HAM_PortalLoginHistoryController.LoginRow> negativeDaysResult =
            HAM_PortalLoginHistoryController.searchPortalLogins('a', -5);
        Test.stopTest();

        System.assertNotEquals(null, nullDaysResult, 'Null days should still return a list, not null');
        System.assertNotEquals(null, zeroDaysResult, 'Zero days should still return a list, not null');
        System.assertNotEquals(null, negativeDaysResult, 'Negative days should still return a list, not null');
    }

    @isTest
    static void testMatchesSearchTerm_matchesUserNameOrContactNameCaseInsensitively() {
        Test.startTest();
        Boolean matchesUserName = HAM_PortalLoginHistoryController.matchesSearchTerm('Jane Portal', 'Someone Else', 'jane');
        Boolean matchesContactName = HAM_PortalLoginHistoryController.matchesSearchTerm('svc.integration', 'Jane Contact', 'JANE');
        Boolean noMatch = HAM_PortalLoginHistoryController.matchesSearchTerm('Bob User', 'Bob Contact', 'zzz');
        Boolean blankTerm = HAM_PortalLoginHistoryController.matchesSearchTerm('Jane Portal', 'Jane Contact', '   ');
        Boolean nullContactName = HAM_PortalLoginHistoryController.matchesSearchTerm('Jane Portal', null, 'jane');
        Test.stopTest();

        System.assertEquals(true, matchesUserName, 'Should match on userName');
        System.assertEquals(true, matchesContactName, 'Should match on contactName regardless of case');
        System.assertEquals(false, noMatch, 'Should not match when term is absent from both names');
        System.assertEquals(false, blankTerm, 'A blank term should never match');
        System.assertEquals(true, nullContactName, 'Should still match on userName when contactName is null');
    }

    @isTest
    static void testBuildRow_mapsAllFieldsOntoLoginRow() {
        Datetime loginTime = Datetime.newInstance(2026, 6, 1, 10, 30, 0);

        Test.startTest();
        HAM_PortalLoginHistoryController.LoginRow row = HAM_PortalLoginHistoryController.buildRow(
            '0YASu0000000001', 'jane.user', 'Jane User', 'jane.user@example.com',
            loginTime, 'Success', '203.0.113.5', 'Browser', 'Chrome', 'Windows'
        );
        Test.stopTest();

        System.assertEquals('0YASu0000000001', row.rowKey);
        System.assertEquals('jane.user', row.userName);
        System.assertEquals('Jane User', row.contactName);
        System.assertEquals('jane.user@example.com', row.email);
        System.assertEquals(loginTime, row.loginTime);
        System.assertEquals('Success', row.status);
        System.assertEquals('203.0.113.5', row.sourceIp);
        System.assertEquals('Browser', row.application);
        System.assertEquals('Chrome', row.browser);
        System.assertEquals('Windows', row.platform);
    }

    @isTest
    static void testBuildRow_handlesNullContactFieldsGracefully() {
        Datetime loginTime = Datetime.now();

        Test.startTest();
        HAM_PortalLoginHistoryController.LoginRow row = HAM_PortalLoginHistoryController.buildRow(
            '0YASu0000000002', 'orphan.user', null, null,
            loginTime, 'Failed', '198.51.100.9', 'API', null, null
        );
        Test.stopTest();

        System.assertEquals(null, row.contactName, 'contactName should pass through as null when Contact is absent');
        System.assertEquals(null, row.email, 'email should pass through as null when Contact is absent');
        System.assertEquals('orphan.user', row.userName);
        System.assertEquals('Failed', row.status);
    }

    @isTest
    static void testSearchPortalLogins_rowsSortedDescendingAndFieldsMapped() {
        Test.startTest();
        List<HAM_PortalLoginHistoryController.LoginRow> results =
            HAM_PortalLoginHistoryController.searchPortalLogins('a', 180);
        Test.stopTest();

        for (Integer i = 1; i < results.size(); i++) {
            System.assert(
                results.get(i - 1).loginTime >= results.get(i).loginTime,
                'Rows must be sorted by loginTime descending'
            );
        }

        for (HAM_PortalLoginHistoryController.LoginRow row : results) {
            System.assertNotEquals(null, row.rowKey, 'rowKey must always be populated from LoginHistory.Id');
            System.assertNotEquals(null, row.loginTime, 'loginTime must always be populated within the lookback window');
        }
    }
}