/**
 * @description Apex controller for Closed Tasks component
 */
public with sharing class HamCCClosedTasksController {
     
/**
     * @description Retrieves closed tasks for a given contact or account
     * @param recordId - Contact or Account ID
     * @param isAlumni - Flag to determine if record is Contact (true) or Account (false)
     * @return List of Task records with comments
     */
    @AuraEnabled(cacheable=true)
    public static List<Task> getClosedTasks(Id recordId, Boolean isAlumni) {
        List<Task> tasks = new List<Task>();
        
        if (recordId != null) {
            String query;
            if (isAlumni) {
                query = 'SELECT Id, Priority, Subject, WhoId, WhatId, Status, ActivityDate, Description ' +
                       'FROM Task ' +
                       'WHERE WhoId = :recordId ' +
                       'AND IsClosed = true ' +
                       'ORDER BY ActivityDate DESC';
            } else {
                query = 'SELECT Id, Priority, Subject, WhoId, WhatId, Status, ActivityDate, Description ' +
                       'FROM Task ' +
                       'WHERE WhatId = :recordId ' +
                       'AND IsClosed = true ' +
                       'ORDER BY ActivityDate DESC';
            }
            System.debug('Query------'+query);
            tasks = Database.query(query);
        }
        
        return tasks;
    }
    
    
    
    /**
     * @description Creates or updates a task
     * @param task - Task record to save
     * @return The saved record
     */
    @AuraEnabled(cacheable=true)
    public static Task saveTask(Task task) {
        if (task != null) {
            try {
                upsert task;
                return task;
            } catch (Exception e) {
                System.debug('Error saving task: ' + e.getMessage());
                throw new AuraHandledException('Failed to save task: ' + e.getMessage());
            }
        }
        return null;
    }
}