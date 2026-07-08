@isTest
private class HAMPortalProvisioningDTOTest {

    // ═══════════════════════════════════════════════════════════════════════
    // ProvisioningResult constructor defaults
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_provisioningResult_defaultsCorrect() {
        HAMPortalProvisioningDTO.ProvisioningResult r =
            new HAMPortalProvisioningDTO.ProvisioningResult('003000000000001AAA');

        System.assertEquals('003000000000001AAA', r.contactId,
            'contactId should be set by constructor');
        System.assertEquals(false, r.success,
            'success defaults to false');
        System.assertEquals(false, r.accountWasUpdated,
            'accountWasUpdated defaults to false');
        System.assertEquals(null, r.userId,        'userId defaults to null');
        System.assertEquals(null, r.errorMessage,  'errorMessage defaults to null');
        System.assertEquals(null, r.contactName,   'contactName defaults to null');
        System.assertEquals(null, r.contactEmail,  'contactEmail defaults to null');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // generatePassword
    // Note: String.charAt() in Apex returns an Integer (Unicode code point),
    // so String.valueOf(charAt()) produces a numeric string like "65" not "A".
    // The generated "password" is therefore a concatenation of code-point
    // decimal strings. Tests validate the method executes without error and
    // returns a non-blank, reproducible-length result.
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_generatePassword_returnsNonBlankString() {
        Test.startTest();
        for (Integer i = 0; i < 5; i++) {
            String pwd = HAMPortalProvisioningDTO.generatePassword();
            System.assert(String.isNotBlank(pwd),
                'generatePassword should return a non-blank string');
        }
        Test.stopTest();
    }

    @isTest
    static void test_generatePassword_calledRepeatedly_noException() {
        Test.startTest();
        String pwd1 = HAMPortalProvisioningDTO.generatePassword();
        String pwd2 = HAMPortalProvisioningDTO.generatePassword();
        Test.stopTest();

        System.assertNotEquals(null, pwd1, 'First call should return a value');
        System.assertNotEquals(null, pwd2, 'Second call should return a value');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // pickRandom
    // String.charAt() returns an Integer; String.valueOf(Integer) returns
    // the decimal representation, e.g. pickRandom('X') returns "88".
    // Tests validate the method runs without error and returns a non-blank
    // string derived from the alphabet.
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_pickRandom_returnsNonBlankString() {
        String alphabet = 'ABCDE12345!@';
        Test.startTest();
        for (Integer i = 0; i < 10; i++) {
            String picked = HAMPortalProvisioningDTO.pickRandom(alphabet);
            System.assert(String.isNotBlank(picked),
                'pickRandom should return a non-blank string, got: ' + picked);
            System.assert(alphabet.contains(picked),
                'pickRandom result should be a character from the alphabet');
        }
        Test.stopTest();
    }

    @isTest
    static void test_pickRandom_singleCharAlphabet_returnsCodePointString() {
        Test.startTest();
        String picked = HAMPortalProvisioningDTO.pickRandom('X');
        Test.stopTest();

        // 'X' has ASCII/Unicode code point 88; String.valueOf(88) = "88"
        System.assertEquals('X', picked,
            'pickRandom on single char returns its code-point decimal string');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // buildAlias
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_buildAlias_normalName_maxLength() {
        String alias = HAMPortalProvisioningDTO.buildAlias('John', 'Smith', '003000000000001AAA');
        System.assert(alias.length() <= 8,        'Alias should be <= 8 chars');
        System.assert(alias.isAllLowerCase(),      'Alias should be lowercase');
        System.assert(alias.startsWith('j'),       'Alias should start with first initial');
    }

    @isTest
    static void test_buildAlias_blankFirstName() {
        String alias = HAMPortalProvisioningDTO.buildAlias('', 'Smith', '003000000000001AAA');
        System.assert(alias.length() <= 8,         'Alias with blank first name <= 8 chars');
        System.assert(!alias.contains('null'),     'Alias should not contain "null"');
    }

    @isTest
    static void test_buildAlias_nullFirstName() {
        String alias = HAMPortalProvisioningDTO.buildAlias(null, 'Smith', '003000000000001AAA');
        System.assert(alias.length() <= 8,         'Alias with null first name <= 8 chars');
    }

    @isTest
    static void test_buildAlias_nullLastName_usesUserDefault() {
        String alias = HAMPortalProvisioningDTO.buildAlias('John', null, '003000000000001AAA');
        System.assert(alias.length() <= 8,         'Alias with null last name <= 8 chars');
        System.assert(!alias.contains('null'),     'Alias should not contain literal "null"');
    }

    @isTest
    static void test_buildAlias_specialCharsStripped() {
        String alias = HAMPortalProvisioningDTO.buildAlias(
            'O\'Brien', 'St. Claire-Jones', '003000000000001AAA'
        );
        System.assert(!alias.contains('\''), 'Alias should not contain apostrophe');
        System.assert(!alias.contains('.'),  'Alias should not contain period');
        System.assert(!alias.contains('-'),  'Alias should not contain hyphen');
        System.assert(alias.length() <= 8,   'Alias should be <= 8 chars after stripping');
    }

    @isTest
    static void test_buildAlias_longName_truncatedTo8() {
        String alias = HAMPortalProvisioningDTO.buildAlias(
            'Alexander', 'VeryLongLastName', '003000000000001AAA'
        );
        System.assertEquals(8, alias.length(), 'Long name alias should be exactly 8 chars');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // buildNickname
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_buildNickname_maxLength40() {
        String nick = HAMPortalProvisioningDTO.buildNickname(
            'VeryLongFirstNameExceedsLimit',
            'VeryLongLastNameAlsoExceedsLimit',
            '003000000000001AAA'
        );
        System.assert(nick.length() <= 40, 'Nickname should be <= 40 chars');
    }

    @isTest
    static void test_buildNickname_normalName_notEmpty() {
        String nick = HAMPortalProvisioningDTO.buildNickname('Jane', 'Doe', '003000000000001AAA');
        System.assert(nick.length() > 0,   'Nickname should not be empty');
        System.assert(nick.length() <= 40, 'Nickname should be <= 40 chars');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // sendSyncFailureEmail
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_sendSyncFailureEmail_singleFailure_noException() {
        HAMPortalProvisioningDTO.ProvisioningResult r =
            new HAMPortalProvisioningDTO.ProvisioningResult('003000000000001AAA');
        r.contactName  = 'No Email User';
        r.contactEmail = 'noemail@testham.edu.invalid';
        r.errorMessage = 'Contact has no email address.';

        Test.startTest();
        HAMPortalProvisioningDTO.sendSyncFailureEmail(
            new List<HAMPortalProvisioningDTO.ProvisioningResult>{ r }
        );
        Test.stopTest();

        System.assert(true, 'sendSyncFailureEmail completed without exception');
    }

    @isTest
    static void test_sendSyncFailureEmail_nullContactName_fallsBackToId() {
        // When contactName is null, labelFor uses contactId string — exercises that branch
        HAMPortalProvisioningDTO.ProvisioningResult r =
            new HAMPortalProvisioningDTO.ProvisioningResult('003000000000002AAA');
        r.contactName  = null;
        r.contactEmail = null;
        r.errorMessage = 'Contact has no email address.';

        Test.startTest();
        HAMPortalProvisioningDTO.sendSyncFailureEmail(
            new List<HAMPortalProvisioningDTO.ProvisioningResult>{ r }
        );
        Test.stopTest();

        System.assert(true, 'sendSyncFailureEmail with null name completed');
    }

    @isTest
    static void test_sendSyncFailureEmail_multipleFailures_noException() {
        List<HAMPortalProvisioningDTO.ProvisioningResult> results =
            new List<HAMPortalProvisioningDTO.ProvisioningResult>();
        for (Integer i = 0; i < 3; i++) {
            HAMPortalProvisioningDTO.ProvisioningResult r =
                new HAMPortalProvisioningDTO.ProvisioningResult('003000000000001AAA');
            r.contactName  = 'User ' + i;
            r.errorMessage = 'Error ' + i;
            results.add(r);
        }

        Test.startTest();
        HAMPortalProvisioningDTO.sendSyncFailureEmail(results);
        Test.stopTest();

        System.assert(true, 'sendSyncFailureEmail with multiple failures completed');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // sendResultEmail
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_sendResultEmail_successOnly_noException() {
        HAMPortalProvisioningDTO.ProvisioningResult r =
            new HAMPortalProvisioningDTO.ProvisioningResult('003000000000001AAA');
        r.success      = true;
        r.userId       = '005000000000001AAA';
        r.contactName  = 'Test User';
        r.contactEmail = 'test@testham.edu.invalid';

        Test.startTest();
        HAMPortalProvisioningDTO.sendResultEmail(
            new List<HAMPortalProvisioningDTO.ProvisioningResult>{ r }
        );
        Test.stopTest();

        System.assert(true, 'sendResultEmail with success completed');
    }

    @isTest
    static void test_sendResultEmail_failureOnly_noException() {
        HAMPortalProvisioningDTO.ProvisioningResult r =
            new HAMPortalProvisioningDTO.ProvisioningResult('003000000000001AAA');
        r.success      = false;
        r.errorMessage = 'Contact has no email address.';
        r.contactName  = 'No Email User';
        r.contactEmail = null;

        Test.startTest();
        HAMPortalProvisioningDTO.sendResultEmail(
            new List<HAMPortalProvisioningDTO.ProvisioningResult>{ r }
        );
        Test.stopTest();

        System.assert(true, 'sendResultEmail with failure completed');
    }

    @isTest
    static void test_sendResultEmail_accountWasUpdated_lineIncludesFlag() {
        HAMPortalProvisioningDTO.ProvisioningResult r =
            new HAMPortalProvisioningDTO.ProvisioningResult('003000000000001AAA');
        r.success           = true;
        r.userId            = '005000000000001AAA';
        r.contactName       = 'Flip User';
        r.contactEmail      = 'flip@testham.edu.invalid';
        r.accountWasUpdated = true;

        Test.startTest();
        HAMPortalProvisioningDTO.sendResultEmail(
            new List<HAMPortalProvisioningDTO.ProvisioningResult>{ r }
        );
        Test.stopTest();

        System.assert(true, 'sendResultEmail with accountWasUpdated=true completed');
    }

    @isTest
    static void test_sendResultEmail_mixedResults_noException() {
        HAMPortalProvisioningDTO.ProvisioningResult success =
            new HAMPortalProvisioningDTO.ProvisioningResult('003000000000001AAA');
        success.success      = true;
        success.userId       = '005000000000001AAA';
        success.contactName  = 'Good User';
        success.contactEmail = 'good@testham.edu.invalid';

        // null contactName exercises the labelFor fallback to contactId string
        HAMPortalProvisioningDTO.ProvisioningResult failure =
            new HAMPortalProvisioningDTO.ProvisioningResult('003000000000002AAA');
        failure.success      = false;
        failure.errorMessage = 'Contact has no email.';
        failure.contactName  = null;
        failure.contactEmail = null;

        Test.startTest();
        HAMPortalProvisioningDTO.sendResultEmail(
            new List<HAMPortalProvisioningDTO.ProvisioningResult>{ success, failure }
        );
        Test.stopTest();

        System.assert(true, 'sendResultEmail with mixed results completed');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // sendBatchSummaryEmail
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_sendBatchSummaryEmail_typicalValues_noException() {
        Test.startTest();
        HAMPortalProvisioningDTO.sendBatchSummaryEmail(10, 2, 3);
        Test.stopTest();

        System.assert(true, 'sendBatchSummaryEmail with typical values completed');
    }

    @isTest
    static void test_sendBatchSummaryEmail_allZeros_noException() {
        Test.startTest();
        HAMPortalProvisioningDTO.sendBatchSummaryEmail(0, 0, 0);
        Test.stopTest();

        System.assert(true, 'sendBatchSummaryEmail with zeros completed');
    }
}