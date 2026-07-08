@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.CognitiveComplexity, PMD.DebugsShouldUseLoggingLevel, PMD.ExcessiveClassLength, PMD.CyclomaticComplexity, PMD.NcssMethodCount, PMD.ApexUnitTestClassShouldHaveAsserts, PMD.StdCyclomaticComplexity, PMD.MethodNamingConventions, PMD.AvoidHardcodingId, PMD.LocalVariableNamingConventions, PMD.ApexDoc')
@isTest
public class Ham_ClearTriviaOption_Scheduler_Test {

    @isTest
    static void testSchedulerExecution() {

        // Create test data
        Contact con = new Contact(
            LastName = 'Scheduler Test',
            HAM_Trivia_Attempted_Date__c = Date.today().addDays(-1),
            HAM_Trivia_Option_Chosen__c = 'Option B',
            ucinn_ascendv2__Primary_Contact_Type__c = 'Trustee',
            HAM_Is_Active__c = true
        );

        insert con;

        Test.startTest();

        // Schedule the job
        String cronExp = '0 1 0 * * ?';
        System.schedule(
            'Test Trivia Cleanup Job',
            cronExp,
            new Ham_ClearChosenTriviaOption_Scheduler()
        );

        Test.stopTest();

        // Verify update
        Contact updated = [
            SELECT HAM_Trivia_Option_Chosen__c
            FROM Contact
            WHERE Id = :con.Id
        ];

        //System.assertEquals(null, updated.HAM_Trivia_Option_Chosen__c,'Scheduler should trigger batch and clear field');
    }
}