/**
 * @Trigger Name : ReceiptFileVisibilityTrigger
 * @Object       : ContentDocumentLink
 * @Description  : Ensures files attached to Receipt__c records are instantly visible to 
 * Experience Cloud (Community) users by defaulting Visibility to 'AllUsers'.
 * Runs on 'before insert' to modify the record in memory, avoiding DML limits.
 * @Author       : Cube84 - Sachin
 * @Date         : April 24, 2026
 *==============================================================================
 * Ver | Date        | Author | Modification
 *==============================================================================
 * 1.0 | April 24, 2026 | Sachin | Initial Version
 **/
trigger ReceiptFileVisibilityTrigger on ContentDocumentLink (before insert) {
    
    /** 
	* @Description	: Retrieve the dynamic 3-character key prefix for the Receipt__c object (e.g., 'a0X').
    * 				  Using getDescribe() ensures this works safely across sandboxes and production 
    *  				  without hardcoding IDs that might change between environments.
	**/
    String receiptPrefix = Receipt__c.sObjectType.getDescribe().getKeyPrefix();

    /**
	*	 Iterate through all incoming ContentDocumentLink records.
    *	 Trigger.new inherently handles bulk data loads safely.
	**/
    for (ContentDocumentLink cdl : Trigger.new) {
        
        // Safety check: Ensure the link is actually attached to a record before processing
        if (cdl.LinkedEntityId != null) {
            
            // Check if the file is being attached specifically to a Receipt__c record
            if (String.valueOf(cdl.LinkedEntityId).startsWith(receiptPrefix)) {
                
                /* * Set Visibility to 'AllUsers' (Customer Access).
                 * By default, Salesforce sets internal uploads to 'InternalUsers',
                 * which blocks Community users from downloading/previewing the file.
                 * Updating this in the 'before insert' context consumes 0 additional DML statements.
                 */
                cdl.Visibility = 'AllUsers'; 
                
            }
        }
    }
}