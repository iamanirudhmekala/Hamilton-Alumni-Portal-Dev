@isTest
private class HAM_SocialSignOnRegistrationHandler_Test {

    private static Auth.UserData createTestUserData(String email, String firstName, String lastName) {
        return new Auth.UserData(
            'testId',           // identifier
            firstName,          // firstName
            lastName,           // lastName
            firstName + ' ' + lastName, // fullName
            email,              // email
            null,               // link
            null,               // userName
            null,               // locale
            'LinkedIn',         // provider
            null,               // siteLoginUrl
            new Map<String, String>()
        );
    }

    /**
     * @description Helper method to get a standard admin user for System.runAs() context
     * @return User An active System Administrator user record
     */
    private static User getRunAsUser() {
        return [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
    }

    @isTest
    static void testCanCreateUserValidData() { // Fixed naming convention (removed underscore)
        User runAsUser = getRunAsUser();
        
        System.runAs(runAsUser) { // Added System.runAs
            HAM_SocialSignOnRegistrationHandler handler = new HAM_SocialSignOnRegistrationHandler();
            Auth.UserData data = createTestUserData('test@example.com', 'John', 'Doe');
    
            Test.startTest();
            Boolean result = handler.canCreateUser(data);
            Test.stopTest();
    
            System.assertEquals(true, result, 'Should return true when all required fields are present');
        }
    }

    @isTest
    static void testCanCreateUserNullData() { // Fixed naming convention
        User runAsUser = getRunAsUser();
        
        System.runAs(runAsUser) { // Added System.runAs
            HAM_SocialSignOnRegistrationHandler handler = new HAM_SocialSignOnRegistrationHandler();
    
            Test.startTest();
            Boolean result = handler.canCreateUser(null);
            Test.stopTest();
    
            System.assertEquals(false, result, 'Should return false when data is null');
        }
    }

    @isTest
    static void testCanCreateUserMissingEmail() { // Fixed naming convention
        User runAsUser = getRunAsUser();
        
        System.runAs(runAsUser) { // Added System.runAs
            HAM_SocialSignOnRegistrationHandler handler = new HAM_SocialSignOnRegistrationHandler();
            Auth.UserData data = createTestUserData(null, 'John', 'Doe');
    
            Test.startTest();
            Boolean result = handler.canCreateUser(data);
            Test.stopTest();
    
            System.assertEquals(false, result, 'Should return false when email is missing');
        }
    }

    @isTest
    static void testCanCreateUserMissingFirstName() { // Fixed naming convention
        User runAsUser = getRunAsUser();
        
        System.runAs(runAsUser) { // Added System.runAs
            HAM_SocialSignOnRegistrationHandler handler = new HAM_SocialSignOnRegistrationHandler();
            Auth.UserData data = createTestUserData('test@example.com', null, 'Doe');
    
            Test.startTest();
            Boolean result = handler.canCreateUser(data);
            Test.stopTest();
    
            System.assertEquals(false, result, 'Should return false when firstName is missing');
        }
    }

    @isTest
    static void testCanCreateUserMissingLastName() { // Fixed naming convention
        User runAsUser = getRunAsUser();
        
        System.runAs(runAsUser) { // Added System.runAs
            HAM_SocialSignOnRegistrationHandler handler = new HAM_SocialSignOnRegistrationHandler();
            Auth.UserData data = createTestUserData('test@example.com', 'John', null);
    
            Test.startTest();
            Boolean result = handler.canCreateUser(data);
            Test.stopTest();
    
            System.assertEquals(false, result, 'Should return false when lastName is missing');
        }
    }

    @isTest
    static void testCreateUserNullEmail() { // Fixed naming convention
        User runAsUser = getRunAsUser();
        
        System.runAs(runAsUser) { // Added System.runAs
            HAM_SocialSignOnRegistrationHandler handler = new HAM_SocialSignOnRegistrationHandler();
            Auth.UserData data = createTestUserData(null, 'John', 'Doe');
    
            Test.startTest();
            try {
                handler.createUser(null, data);
                System.assert(false, 'Should have thrown RegistrationException');
            } catch (HAM_SocialSignOnRegistrationHandler.RegistrationException e) {
                System.assertEquals('Account not found', e.getMessage(), 'Exception message should match');
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testCreateUserNoExistingUser() { // Fixed naming convention
        User runAsUser = getRunAsUser();
        
        System.runAs(runAsUser) { // Added System.runAs
            HAM_SocialSignOnRegistrationHandler handler = new HAM_SocialSignOnRegistrationHandler();
            Auth.UserData data = createTestUserData('nonexistent@example.com', 'John', 'Doe');
    
            Test.startTest();
            User result = handler.createUser(null, data);
            Test.stopTest();
    
            System.assertEquals(null, result, 'Should return null when no matching user exists');
        }
    }

    @isTest
    static void testCreateUserExistingUserFound() { // Fixed naming convention
        User runAsUser = getRunAsUser();
        
        // Data setup shouldn't be inside runAs if we are creating community users
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Partner Community Login User' LIMIT 1];

        // Create an Account and Contact for the community user
        Account acc = new Account(Name = 'Test Partner Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Existing',
            LastName = 'User',
            Email = 'existing@example.com',
            AccountId = acc.Id
        );
        insert con;

        // Create an existing community user
        User existingUser = new User(
            FirstName = 'Existing',
            LastName = 'User',
            Email = 'existing@example.com',
            Username = 'existing_sso_test_' + System.currentTimeMillis() + '@example.com',
            Alias = 'exuser',
            ProfileId = p.Id,
            ContactId = con.Id,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            IsActive = true
        );
        insert existingUser;

        System.runAs(runAsUser) { // Added System.runAs for execution
            HAM_SocialSignOnRegistrationHandler handler = new HAM_SocialSignOnRegistrationHandler();
            Auth.UserData data = createTestUserData('existing@example.com', 'Existing', 'User');
    
            Test.startTest();
            User result = handler.createUser(null, data);
            Test.stopTest();
    
            System.assertNotEquals(null, result, 'Should return the existing user');
            System.assertEquals(existingUser.Id, result.Id, 'Should return the correct existing user');
        }
    }

    @isTest
    static void testUpdateUserDoesNothing() { // Fixed naming convention
        User runAsUser = getRunAsUser();
        
        System.runAs(runAsUser) { // Added System.runAs
            HAM_SocialSignOnRegistrationHandler handler = new HAM_SocialSignOnRegistrationHandler();
            Auth.UserData data = createTestUserData('test@example.com', 'John', 'Doe');
    
            // Just use the runAsUser as our current user for this context
            User currentUser = [SELECT Id, FirstName, LastName, Email FROM User WHERE Id = :runAsUser.Id];
    
            Test.startTest();
            handler.updateUser(currentUser.Id, null, data);
            Test.stopTest();
    
            // Verify no fields were changed
            User afterUpdate = [SELECT FirstName, LastName, Email FROM User WHERE Id = :currentUser.Id];
            System.assertEquals(currentUser.FirstName, afterUpdate.FirstName, 'FirstName should not change');
            System.assertEquals(currentUser.LastName, afterUpdate.LastName, 'LastName should not change');
            System.assertEquals(currentUser.Email, afterUpdate.Email, 'Email should not change');
        }
    }
}