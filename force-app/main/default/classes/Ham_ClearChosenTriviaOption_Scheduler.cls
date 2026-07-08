/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : Ham_ClearChosenTriviaOption_Scheduler
 * Author          : Immanuel
 * Created Date    : Mar 19, 2026
 * Last Modified By: Immanuel
 * Last Modified On: Mar 19, 2026
 * Description     : Schedules the Batch class 'Ham_Batch_ClearChosenTriviaOption' at 12:01 AM daily.
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Mar 19, 2026  │ Immanuel   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@SuppressWarnings('PMD.ApexDoc,  PMD.AvoidGlobalModifier, PMD.ApexSharingViolations, PMD.NoTrailingWhitespace, PMD.ExcessiveClassLength, PME.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
global class Ham_ClearChosenTriviaOption_Scheduler implements Schedulable {
	public void execute(SchedulableContext sc) {
		
		/* cron expression that needed to be run in the anonymous window:
			System.schedule(
				'Daily Clear Trivia Option Job',
				'0 1 0 * * ?',  // 12:01 AM
				new Ham_ClearChosenTriviaOption_Scheduler()
			);
		*/
		Database.executeBatch(new Ham_Batch_ClearChosenTriviaOption(), 200);
	}
}