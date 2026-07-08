public with sharing class HAMStudentToAlumniInvolvements  implements Database.Batchable<sObject>,  Database.Stateful {
    String studentInvolvement = Schema.SObjectType.ucinn_ascendv2__Involvement__c.getRecordTypeInfosByDeveloperName().get('Student_Involvement').getRecordTypeId();
    String alumniInvolvement = Schema.SObjectType.ucinn_ascendv2__Involvement__c.getRecordTypeInfosByDeveloperName().get('Alumni_Involvement').getRecordTypeId(); 
    String StudentHousingInvolvement = Schema.SObjectType.ucinn_ascendv2__Involvement__c.getRecordTypeInfosByDeveloperName().get('Student_Housing').getRecordTypeId(); 
    List<String> errors = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator([SELECT Id, 
                                                Name,
                                                ucinn_ascendv2__Involvement_Code__c,
                                                ucinn_ascendv2__Contact__c,
                                                HAM_Category__c,
                                                ucinn_ascendv2__Account__c,
                                                ucinn_ascendv2__Start_Date__c,
                                                ucinn_ascendv2__End_Date__c 
                                        FROM    ucinn_ascendv2__Involvement__c 
                                        WHERE   (RecordTypeId =: studentInvolvement OR RecordTypeId =: StudentHousingInvolvement ) AND ucinn_ascendv2__Status__c = 'Current']);
    
    }
    public void execute(Database.BatchableContext bc, List<ucinn_ascendv2__Involvement__c> lstStudentInvolvments){
       
        List<ucinn_ascendv2__Involvement__c> lstAlumniInvolvments = new List<ucinn_ascendv2__Involvement__c>();
        for(ucinn_ascendv2__Involvement__c objStudentInvolvement: lstStudentInvolvments){
            ucinn_ascendv2__Involvement__c objAlumniInvolvement = new ucinn_ascendv2__Involvement__c();
            objAlumniInvolvement.RecordTypeId = alumniInvolvement;
            objAlumniInvolvement.ucinn_ascendv2__Involvement_Code__c = objStudentInvolvement.ucinn_ascendv2__Involvement_Code__c;
            objAlumniInvolvement.ucinn_ascendv2__Contact__c = objStudentInvolvement.ucinn_ascendv2__Contact__c;
            objAlumniInvolvement.ucinn_ascendv2__Account__c = objStudentInvolvement.ucinn_ascendv2__Account__c;
            objAlumniInvolvement.ucinn_ascendv2__Start_Date__c = objStudentInvolvement.ucinn_ascendv2__Start_Date__c;
            objAlumniInvolvement.ucinn_ascendv2__End_Date__c = objStudentInvolvement.ucinn_ascendv2__End_Date__c;
            objAlumniInvolvement.HAM_Related_Student_Involvements__c = objStudentInvolvement.Id; 
            lstAlumniInvolvments.add(objAlumniInvolvement);
        }
        Database.SaveResult[] results = Database.insert(lstAlumniInvolvments, false);
		
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                for (Database.Error err : results[i].getErrors()) {
                    
                    errors.add(err.getMessage());
                }
            }
        }
    }
    public void finish(Database.BatchableContext bc){

    }
}