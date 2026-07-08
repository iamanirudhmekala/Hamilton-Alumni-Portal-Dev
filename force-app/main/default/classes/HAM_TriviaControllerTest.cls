@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ApexUnitTestClassShouldHaveRunAs, PMD.ApexUnitTestClassShouldHaveAsserts, PMD.ExcessiveClassLength, PME.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
@isTest
public class HAM_TriviaControllerTest {
    
     /* ---------------------------
       Test Data Setup
    ---------------------------- */
    @testSetup
    static void setupData() {

        // Create Contact
            Contact con = new Contact(
            LastName = 'Test User',
            //HAM_Trivia_Attempted__c = false,
            HAM_Trivia_Score__c = 0
        );
        insert con;
        
        // Create Trivia Question
            HAM_Trivia__c trivia = new HAM_Trivia__c(
            Question__c = 'What is Apex?',
            Active__c = true,
            Show_On_Portal__c = true,
            //Order__c = 1,
            Points__c = 10
        );
        insert trivia;
        
          // Create Trivia Options
          // Create Trivia Options
        List<HAM_Trivia_Options__c> options = new List<HAM_Trivia_Options__c>{
            new HAM_Trivia_Options__c(
                Question__c = trivia.Id,
                Option__c = 'Programming Language',
                Is_Correct__c = true,
                Display_Order__c = '1'
            ),
            new HAM_Trivia_Options__c(
                Question__c = trivia.Id,
                Option__c = 'Database',
                Is_Correct__c = false,
                Display_Order__c = '2'
            )
        };
        insert options;     
    } 
    
    /* ---------------------------
       Test getTriviaQuestionAndOptions
    ---------------------------- */
    @IsTest
    static void testGetTriviaQuestionAndOptions() {

        Contact con = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        HAM_TriviaController.TriviaWrapper wrapper =
            HAM_TriviaController.getTriviaQuestionAndOptions(con.Id);
        Test.stopTest();
        
    }
    
    /* ---------------------------
       Test updateTriviaInfoOnConstituent
    ---------------------------- */
    @IsTest
    static void testUpdateTriviaInfoOnConstituent() {

        Contact con = [SELECT Id, HAM_Trivia_Score__c FROM Contact LIMIT 1];

        Test.startTest();
        String result = HAM_TriviaController.updateTriviaInfoOnConstituent(
            con.Id,
            10,
            'Programming Language'
        );
        Test.stopTest();
    }
}