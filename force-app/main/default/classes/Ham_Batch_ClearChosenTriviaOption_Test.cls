@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.DebugsShouldUseLoggingLevel, PMD.CognitiveComplexity, PMD.ExcessiveClassLength, PMD.CyclomaticComplexity, PMD.NcssMethodCount, PMD.StdCyclomaticComplexity, PMD.MethodNamingConventions, PMD.AvoidHardcodingId, PMD.LocalVariableNamingConventions, PMD.ApexDoc')
@isTest
public class Ham_Batch_ClearChosenTriviaOption_Test {

    @isTest
    static void testBatchExecution() {

        // Create test data
        List<Contact> contacts = new List<Contact>();

        for (Integer i = 0; i < 10; i++) {
            contacts.add(new Contact(
                LastName = 'Test ' + i,
                HAM_Trivia_Attempted_Date__c = Date.today().addDays(-1),
                HAM_Trivia_Option_Chosen__c = 'Option A',
                ucinn_ascendv2__Primary_Contact_Type__c = 'Trustee',
                HAM_Is_Active__c = true
            ));
        }

        insert contacts;
        
        for(Contact con : contacts){
            system.debug(con);
        }

        Test.startTest();

        // Execute batch
        Database.executeBatch(new Ham_Batch_ClearChosenTriviaOption(), 200);

        Test.stopTest();

        // Verify results
        List<Contact> updatedContacts = [
            SELECT HAM_Trivia_Option_Chosen__c
            FROM Contact
            WHERE Id IN :contacts
        ];

        for (Contact con : updatedContacts) {
            System.assertEquals(null, con.HAM_Trivia_Option_Chosen__c,'Trivia option should be cleared');
        }
    }
}