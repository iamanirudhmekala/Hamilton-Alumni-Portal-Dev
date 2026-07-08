/**
* @File Name : HAM_TriviaController.cls
* @Description : Serves the trivia data. Updates the constituent's trivia data after submission
* @Author : Immanuel
* @Last Modified By : Immanuel
* @Last Modified On : December 13, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 13, 2025 | Immanuel | Initial Version
**/
@SuppressWarnings('PMD.FormalParameterNamingConventions, PMD.DebugsShouldUseLoggingLevel, PMD.ApexDoc, PMD.FieldNamingConventions, PMD.NoTrailingWhitespace, PMD.ExcessiveClassLength, PME.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
public without sharing class HAM_TriviaController {

	public class TriviaWrapper{

		@AuraEnabled public Contact Constituent;
	 	@AuraEnabled public HAM_Trivia__c Trivia;

		public TriviaWrapper(Contact Constituent,HAM_Trivia__c Trivia){
			this.Constituent = Constituent;
			this.Trivia = Trivia;
		}
	}
	
	//Serves the trivia data to the component
	@AuraEnabled(cacheable=true)
	public static TriviaWrapper getTriviaQuestionAndOptions(Id ContactId){

		Contact Constituent;
		HAM_Trivia__c Trivia;

		List<Contact> Constituents = [Select Id,HAM_Trivia_Attempted__c,HAM_Trivia_Attempted_Date__c,HAM_Trivia_Option_Chosen__c,HAM_Trivia_Score__c FROM Contact WHERE Id =: ContactId];

		if(!Constituents.isEmpty()){
			Constituent = Constituents[0];
		}

		List<HAM_Trivia__c> TriviaList = [Select Id,Active__c,Show_On_Portal__c,Order__c,Points__c,Question__c,
								(Select Id,Display_Order__c,Is_Correct__c,Option__c,Question__c FROM Trivia_Options__r ORDER BY  Display_Order__c ASC)
								FROM HAM_Trivia__c WHERE Active__c = True AND Show_On_Portal__c = True ORDER BY Order__c ASC LIMIT 1
			   				   ];

		 if(!TriviaList.isEmpty()){
			Trivia = TriviaList[0];
		}

		return new TriviaWrapper(Constituent,Trivia);
	}

	//Updates the constituent's trivia data after submission
	@AuraEnabled
	public static string updateTriviaInfoOnConstituent(Id ContactId,Integer Points,String SelectedOption){
		
		String returnValue;
		if(ContactId != Null){
			try{
				Contact Constituent = [SELECT Id,HAM_Trivia_Attempted_Date__c,HAM_Trivia_Option_Chosen__c,HAM_Trivia_Score__c
								   	   FROM Contact WHERE Id =: ContactId];
				Constituent.HAM_Trivia_Attempted_Date__c = Date.today();
				Constituent.HAM_Trivia_Option_Chosen__c = SelectedOption;
				Constituent.HAM_Trivia_Score__c =+ Points;

				Update Constituent;
				returnValue = 'Success';
			}catch(exception ex){
				returnValue = 'Unexpected Error Occured '+ex.getMessage();
				system.debug('Trivia Error '+ex.getMessage()+' at '+ex.getLineNumber());
			}
		}else{
			returnValue = 'Error - No ContactId';
		}

		return returnValue;

	}
}