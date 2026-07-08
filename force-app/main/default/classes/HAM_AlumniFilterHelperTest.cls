@IsTest
public class HAM_AlumniFilterHelperTest {

    @TestSetup
    static void setupData() {
        // --- 0. Setup Test User (Wrapped to avoid Mixed DML Exception) ---
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User testUser = new User(
            Alias = 'htest',
            Email = 'hamiltonadmin@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'hamiltonadmintest' + DateTime.now().getTime() + '@testorg.com'
        );
        
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert testUser;
        }

        // 1. Fetch both possible Record Types used in the main class to avoid discrepancies
        List<RecordType> corpRts = [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND DeveloperName IN ('Corporations_and_Organizations', 'New_Corporations_and_Organizations')
        ];

        // 2. Insert an Account for every matching Record Type found
        List<Account> accountsToInsert = new List<Account>();
        for(RecordType rt : corpRts) {
            accountsToInsert.add(new Account(
                Name = 'Test Corporation',
                RecordTypeId = rt.Id
            ));
        }
        insert accountsToInsert;

        // 3. Setup Contact
        Contact c = new Contact(
            LastName = 'Test Contact',
            Job_Title__c = 'Software Engineer',
            HAM_LiveAlumni_Job_Title__c = 'Senior Engineer',
            ucinn_ascendv2__Primary_Contact_Type__c = 'Trustee'
        );
        insert c;

        // 4. Setup Region/Chapter
        insert new HAM_Chapter_Lookup__c(
            Name = 'Midwest',
            HAM_Chapter_Code__c = 'MDWST',
            HAM_Chapter_Type__c = 'Domestic'
        );

        // 5. Setup Involvements (Dynamic Values)
        List<ucinn_ascendv2__Involvement_Value__c> invValues = new List<ucinn_ascendv2__Involvement_Value__c>();
        
        invValues.add(new ucinn_ascendv2__Involvement_Value__c(
            ucinn_ascendv2__Involvement_Description__c = 'Basketball',
            HAM_Category__c = 'Student NCAA Athletics'));

        invValues.add(new ucinn_ascendv2__Involvement_Value__c(
            ucinn_ascendv2__Involvement_Description__c = 'Alumni Council Member',
            HAM_Category__c = 'Alumni Council',
            Ham_Display_On_The_Portal__c = true ));

        invValues.add(new ucinn_ascendv2__Involvement_Value__c(
            ucinn_ascendv2__Involvement_Description__c = 'Chess Club',
            HAM_Category__c = 'Student Clubs'));
        
        invValues.add(new ucinn_ascendv2__Involvement_Value__c(
            ucinn_ascendv2__Involvement_Description__c = 'Career Fair',
            HAM_Category__c = 'Career Center'));

        insert invValues;

        // 6. Setup Major/Post Code
        insert new ucinn_ascendv2__Post_Code__c(
            ucinn_ascendv2__Major_Specialty_Description__c = 'Computer Science');
    }

    @IsTest
    static void testGetDynamicValues() {
        User testUser = [SELECT Id FROM User WHERE Email = 'hamiltonadmin@testorg.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            // Testing all branches of the switch statement in getDynamicValues
            System.assertNotEquals(null, HAM_AlumniFilterHelper.getDynamicValues('Class Year'));
            System.assertNotEquals(null, HAM_AlumniFilterHelper.getDynamicValues('Industry'));
            System.assertNotEquals(0, HAM_AlumniFilterHelper.getDynamicValues('Employer').size());
            System.assertNotEquals(0, HAM_AlumniFilterHelper.getDynamicValues('Job Title').size());
            System.assert(HAM_AlumniFilterHelper.getDynamicValues('Sports Association').contains('Basketball'));
            System.assert(HAM_AlumniFilterHelper.getDynamicValues('Student Organizations').contains('Chess Club'));
            System.assert(HAM_AlumniFilterHelper.getDynamicValues('Region').contains('Midwest'));
            System.assert(HAM_AlumniFilterHelper.getDynamicValues('Volunteer Role').contains('Career Fair'));
            System.assert(HAM_AlumniFilterHelper.getDynamicValues('Alumni Committee').contains('Alumni Council Member'));
            System.assert(HAM_AlumniFilterHelper.getDynamicValues('Major').contains('Computer Science'));
            
            List<String> staticOptions = HAM_AlumniFilterHelper.getDynamicValues('Trustee');
            System.assertEquals(2, staticOptions.size());
            // Test fallback
            System.assertEquals(null, HAM_AlumniFilterHelper.getDynamicValues('NonExistent'));
            Test.stopTest();
        }
    }

    @IsTest
    static void testSearchDynamicValues() {
        User testUser = [SELECT Id FROM User WHERE Email = 'hamiltonadmin@testorg.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            List<String> employers = HAM_AlumniFilterHelper.searchDynamicValues('Employer', 'Test');
            
            List<String> jobTitles = HAM_AlumniFilterHelper.searchDynamicValues('Job Title', 'Engineer');
            System.assert(jobTitles.size() > 0, 'Should find Software Engineer');

            // Coverage for 'Class Year' search
            List<String> blankYearSearch = HAM_AlumniFilterHelper.searchDynamicValues('Class Year', '   ');
            System.assertEquals(0, blankYearSearch.size(), 'Should return empty list for blank search term');

            List<String> validYearSearch = HAM_AlumniFilterHelper.searchDynamicValues('Class Year', '19');
            System.assertNotEquals(null, validYearSearch, 'Should return a non-null list for year search');
            
            // NEW: Coverage for unmatched placeholder in search
            List<String> unknownSearch = HAM_AlumniFilterHelper.searchDynamicValues('Unknown Category', 'Test');
            System.assertEquals(0, unknownSearch.size(), 'Should return an empty list for unmapped search placeholders');

            Test.stopTest();
        }
    }

    @IsTest
    static void testGetSpecificWhereClause() {
        User testUser = [SELECT Id FROM User WHERE Email = 'hamiltonadmin@testorg.com' LIMIT 1];
        
        System.runAs(testUser) {
            List<String> values = new List<String>{'Test Value'};
            String contactId = 'Id';
            String prefix = '';

            Test.startTest();

            // 1. Employer
            String empResult = HAM_AlumniFilterHelper.getSpecificWhereClause('Employer', values, contactId, prefix);
            System.assert(empResult.contains('Constituent_Employer__r.Name'));

            // 2. Job Title
            String jobResult = HAM_AlumniFilterHelper.getSpecificWhereClause('Job Title', values, contactId, prefix);
            System.assert(jobResult.contains('HAM_LiveAlumni_Job_Title__c'));
            
            // 3. Region 
            // FIX: Updated to match controller's subquery on HAM_Current_Chapter__c
            String regionResult = HAM_AlumniFilterHelper.getSpecificWhereClause('Region', values, contactId, prefix);
            System.assert(regionResult.contains('FROM HAM_Current_Chapter__c WHERE Chapter__r.Name IN'), 'Region SOQL should query the junction object');
            
            // 4. Volunteer Role
            String volResult = HAM_AlumniFilterHelper.getSpecificWhereClause('Volunteer Role', values, contactId, prefix);
            System.assert(volResult.contains('ucinn_ascendv2__Start_Date__c'));

            // 5. General Involvements
            String commResult = HAM_AlumniFilterHelper.getSpecificWhereClause('Alumni Committee', values, contactId, prefix);
            System.assert(commResult.contains('ucinn_ascendv2__End_Date__c = null'));
            
            // 6. Major
            String majorResult = HAM_AlumniFilterHelper.getSpecificWhereClause('Major', values, contactId, prefix);
            System.assert(majorResult.contains('ucinn_ascendv2__Degree_Information__c'));

            // 7. Couper Guild (Yes, No, and edge case branches)
            String couperYes = HAM_AlumniFilterHelper.getSpecificWhereClause('Couper Guild', new List<String>{'Yes'}, contactId, prefix);
            System.assert(couperYes.contains('IN (SELECT'));
            
            String couperNo = HAM_AlumniFilterHelper.getSpecificWhereClause('Couper Guild', new List<String>{'No'}, contactId, prefix);
            System.assert(couperNo.contains('NOT IN (SELECT'));

            // Couper Guild fallback check
            String couperFallback = HAM_AlumniFilterHelper.getSpecificWhereClause('Couper Guild', new List<String>{'Maybe'}, contactId, prefix);
            System.assertEquals('', couperFallback);

            // 8. Trustee (Yes, No, and edge case branches)
            String trusteeYes = HAM_AlumniFilterHelper.getSpecificWhereClause('Trustee', new List<String>{'Yes'}, contactId, prefix);
            System.assert(trusteeYes.contains('= \'Trustee\''));
            
            String trusteeNo = HAM_AlumniFilterHelper.getSpecificWhereClause('Trustee', new List<String>{'No'}, contactId, prefix);
            System.assert(trusteeNo.contains('!= \'Trustee\''));

            // Trustee fallback check
            String trusteeFallback = HAM_AlumniFilterHelper.getSpecificWhereClause('Trustee', new List<String>{'Maybe'}, contactId, prefix);
            System.assertEquals('', trusteeFallback);

            // 9. Edge Cases
            System.assertEquals('', HAM_AlumniFilterHelper.getSpecificWhereClause('Employer', new List<String>(), contactId, prefix));
            System.assertEquals(null, HAM_AlumniFilterHelper.getSpecificWhereClause('Unknown', values, contactId, prefix));
            
            // NEW: Test with a valid prefix to cover the String.isNotBlank logic
            String prefixResult = HAM_AlumniFilterHelper.getSpecificWhereClause('Employer', values, contactId, 'Contact.');
            System.assert(prefixResult.contains('Contact.Constituent_Employer__r.Name IN'), 'Prefix should be successfully prepended to the fields');

            Test.stopTest();
        }
    }
}