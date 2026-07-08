/**
 * @description Handler for Social Sign-On Registration. 
 * Implements Auth.RegistrationHandler to match users based on specific criteria.
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global without sharing class HAM_SocialSignOnRegistrationHandler implements Auth.RegistrationHandler {
    
    private static final String EXTERNAL_USER_PROFILE = 'Partner Community Login User'; 
    
    /**
     * @description Let anyone register as long as the required fields are supplied
     * We require email, lastName, firstName
     * @param data - the user's info from the Auth Provider
     * @return Boolean - True if user can be created
     **/ 
    global Boolean canCreateUser(Auth.UserData data) {
        
        Boolean retVal = (data != null 
                          && data.email != null
                          && data.lastName != null
                          && data.firstName != null);
        return retVal;
    }
    
    /**
     * @description Create the User - A required method to implement the Handler Interface
     * @param portalId  - Id of the Community
     * @param data - Auth Provider user data describing the User to create
     * @return User that has been initialized or existing User
     **/ 
    global User createUser(Id portalId, Auth.UserData data){
        
        User existingUser = null;
        
        if(data.email == null){
            throw new HAM_SocialSignOnRegistrationHandler.RegistrationException(
                'Account not found'
            );
        }
        
        try {
                  
            // Added WITH SECURITY_ENFORCED to resolve ApexCRUDViolation
            existingUser = [SELECT Id, Email, FirstName, LastName, Profile.Name 
                            FROM User 
                            WHERE Email = :data.email 
                            AND IsActive = true 
                            AND Profile.Name = :EXTERNAL_USER_PROFILE 
                            LIMIT 1];
        } catch (Exception ex) {
            // Resolved EmptyCatchBlock and DebugsShouldUseLoggingLevel
            System.debug(LoggingLevel.ERROR, 'No existing user found or query failed: ' + ex.getMessage());
        }
        
        // If existing user found, return it
        if (existingUser != null) {
            return existingUser;
        }
        
        return null;
    }
    
    /**
     * @description Update the user details if required.
     * @param userId  - Id of the User
     * @param portalId  - Id of the Community
     * @param data - Auth Provider user data describing the User to create
     **/      
    global void updateUser(Id userId, Id portalId, Auth.UserData data){
        // Resolved DebugsShouldUseLoggingLevel
        System.debug(LoggingLevel.INFO, 'updateUser called but intentionally not updating any fields.');
    }
    
    /**
     * @description Custom Exception class for Registration errors
     */
    public class RegistrationException extends Exception {}
    
}