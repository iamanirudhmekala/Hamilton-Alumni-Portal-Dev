/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : Ham_Batch_ClearChosenTriviaOption
 * Author          : Immanuel
 * Created Date    : Mar 19, 2026
 * Last Modified By: Immanuel
 * Last Modified On: Mar 19, 2026
 * Description     : When the trivia is attempted on portal, the option chosen is stored in the 'HAM_Trivia_Option_Chosen__c' field of the constitiuent. 
 					 Since the trivia is a daily recurring process, we need to look out and clear the chosen option on daily basis so that UI reflects the correct data.
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Mar 19, 2026  │ Immanuel   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@SuppressWarnings('PMD.ApexDoc, PMD.DebugsShouldUseLoggingLevel,  PMD.AvoidGlobalModifier, PMD.ApexSharingViolations, PMD.NoTrailingWhitespace, PMD.ExcessiveClassLength, PME.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
global class Ham_Batch_ClearChosenTriviaOption implements Database.Batchable<SObject> {

    global Database.QueryLocator start(Database.BatchableContext bc) {
        
        String query = 'SELECT Id, HAM_Trivia_Attempted_Date__c, HAM_Trivia_Option_Chosen__c ' +
               		   'FROM Contact ' +
               	       'WHERE HAM_Trivia_Attempted_Date__c = YESTERDAY ' +
                       'AND HAM_Trivia_Option_Chosen__c != NULL ' +
                       'AND HAM_Is_Active__c = true';

        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext bc, List<Contact> scope) {
        
        List<Contact> contacts = new List<Contact>();

        for (Contact con : scope) {
            if(con.HAM_Trivia_Option_Chosen__c != null){
                con.HAM_Trivia_Option_Chosen__c = null;
                contacts.add(con);
            }
        }
	
        if(!contacts.isEmpty()){
            Database.update(contacts, false);
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Daily Trivia Option cleanup completed.');
    }

}