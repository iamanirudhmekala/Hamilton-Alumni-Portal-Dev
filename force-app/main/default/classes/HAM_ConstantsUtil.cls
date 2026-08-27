/**
* @File Name : HAM_ConstantsUtil.cls
* @Description : This class is used to hold the hardcoded values used in the HAM Classes.
* @Author : Cube84 - Ashwin S
* @Last Modified By : Ashwin S
* @Last Modified On : Sep 03, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | Sep 03, 2025 |  Ashwin S | Initial Version - Done as part of Optimization
* 1.1 | Sep 30, 2025 |  Sachin | Added STUDENT - To implement logic to skip Residence Halls for 'Student' Primary Contact Type.
* 1.2 | Dec 03, 2025 |  Asheesh | Added MY_IMPACT - To implement logic to handle new Home page impact widget component.
* 1.3 | Dec 16, 2025 |  Nilesh  | Added MY_VOLUNTEER_OPP - To implement logic to handle new Home Ham_VolunteerOpportunities  component. 
**/
@SuppressWarnings('PMD.EmptyStatementBlock, PMD.ApexDoc')
public with sharing class HAM_ConstantsUtil {
    public static final String UNDERGRADUATE_DEGREE = 'Undergraduate_Degree';
    public static final String UNDERGRADUATE_MINOR = 'Undergraduate_Minor';
    public static final String POST_GRADUATE_DEGREE = 'Post_Graduate_Degree';
    public static final String UNDERGRADUATE_ATHLETICS = 'Undergraduate_Athletics';
    //public static final String RESIDENCE_HALLS = 'Residence_Halls'; 
    public static final String STUDENT = 'Student';
    public static final String SCHOOL_DEGREE_INFORMATION = 'School_Degree_Information';
    public static final String NON_SCHOOL_DEGREE_INFORMATION = 'Non_School_Degree_Information';
    public static final String CONTACT_RECORD_TYPE = 'Contact_Service_Indicator';
    public static final String STUDENT_HOUSING = 'Student Housing';
    public static final String PICKLIST = 'Picklist';
    public static final String CUSTOM = 'Custom';
    public static final String CURRENT = 'Current';
    public static final String CELL = 'Cell';
    public static final String PERSONAL = 'Personal'; 
    public static final String ALL_USERS = 'AllUsers'; 
    public static final String FOOTER = 'Footer'; 
    public static final String NAVBAR = 'NavBar'; 
    public static final String MY_AFFINITIES = 'My Affinities'; 
    public static final String LISTS = 'List'; 
    public static final String HARDCODED_STRING = 'Hardcoded String'; 
    public static final String MY_SERVICE = 'My Service'; 
    public static final String BIO_DATA = 'Bio Data'; 
    public static final String MY_CONNECT = 'My Connect'; 
    public static final String MY_PHILANTHROPY_HIGHLIGHT = 'My Philanthropy Highlight'; 
    public static final String MY_PHILANTHROPY_DETAIL = 'My Philanthropy Detail';
    public static final String MY_IMPACT = 'My Impact';
    public static final Integer VOLUNTEER_OPP_HOME = 3;

    /* Home page constant*/
    public static final String MY_VOLUNTEER_OPP = 'VolunterOppLWC';

   /*
    * ==============================================================================================================================================
    * constants used in HAM_VolunteerOpportunityController.cls
   */
    
    public static final String CAREER_CENTER = 'Career Center';
    public static final String EVENTS_VOLUNTEER = 'Events Volunteer';
    public static final String VOLUNTEER_ENGAGEMENT = 'Volunteer Engagement';

    /* HAM_NotificationController constant*/
    public static final String UNREAD = 'Unread';
    public static final String READ = 'read';
    public static final String ACTIONED = 'Actioned';
    public static final String CONNECTED = 'Connected';
    public static final String CONNECTION = 'Connection';
    public static final String DEFAULTNOTIFICATIONSETTINGS = 'Default_Notification_Settings';
    public static final String HAS_ACCEPTED_YOUR_REQUEST = 'has accepted your request';

    /* HAM_ConnectionTriggerHandler constant*/
    public static final String REQUEST_SENT = 'Request Sent';
    public static final String HAS_SENT_YOU_A_CONNECTION_REQUEST = 'has sent you a connection request';
    public static final String CONNECTION_T = 'Connection';

     /* HAM_NotificationService constant*/
    public static final String UNREAD_S = 'Unread';

    /* HAM_AlumniDirectoryController constant*/
    public static final String BUILD_TAB = 'Search Directory';
    public static final String CONNECTION_TAB = 'My Connections';
    public static final String BOOKMARK_TAB = 'Bookmarked Profiles';
    public static final String INVITATION_TAB = 'Manage Invitations';
    public static final String BLOCKED_TAB = 'Blocked Profiles';
    public static final String CONTACT_SERVICE_INDICATOR_RECORD_TYPE = 'Contact Service Indicator';
    public static final String SI_PRIMARY_CON = 'Connection - Primary';
    public static final String SI_SECONDARY_CON = 'Connection - Secondary';
    public static final String SI_DIRECTORY = 'Directory';
    public static final String CONNECTIONS = 'Connections';
    public static final String DEGREE = 'Degree';
    public static final String LINKED_USER = 'HAM_Linked_Constituent__r';
    public static final String PORTAL_USER = 'HAM_Portal_User__r';
    

    /* HAM_AlumniProfileOverviewController constant*/
    public static final String STUDENT_HOUSING1 = 'Student Housing';
    public static final String STUDENT_NCAA_ATHLETICS = 'Student NCAA Athletics';
    public static final String STUDENT_PRIVATE_SOCIETIES = 'Student Private Societies';
    public static final String STUDENT_CLUBS = 'Student Clubs';
    public static final String PERSONAL_INFO = 'Personal Info';
    public static final String ADDRESS_DETAILS = 'Address Details';
    public static final String CAMPUS_LIFE = 'Campus Life';
    public static final String HEADER = 'Header';
    public static final String KIRKLAND_ALUMNAE = 'Kirkland Alumnae';
    public static final String DECEASED_ALUMNAE = 'Deceased Alumnae';
    public static final String HAMILTON_ALUMNI = 'Hamilton Alumni';
    public static final String SHOW_CLASS_OF = 'Show Class Of';
    public static final String NAME = 'Name';
    public static final String CLASS1 = 'Class';
    public static final String SOCIAL_MEDIA = 'Social Media';
    public static final String FACEBOOK = 'Facebook';
    public static final String INSTAGRAM = 'Instagram';
    public static final String TWITTER = 'Twitter';
    public static final String LINKEDIN = 'LinkedIn';
    public static final String LINKEDIN_URL = 'LinkedIn Url';
    public static final String PROFILE_PICTURE = 'Profile Picture';
    public static final String RESIDENCE_HALLS = 'Residence Halls';
    public static final String UNDERGRAD_ATHLETICS = 'Undergraduate Athletics';
    public static final String STUDENT_ORGANIZATIONS = 'Student Organizations';
    public static final String CURRENT_CHAPTER = 'Current Chapter';
    public static final String FACEBOOK_URL = 'https://www.facebook.com/';
    public static final String INSTAGRAM_URL = 'https://www.instagram.com/';
    public static final String TWITTER_URL = 'https://x.com/';
    public static final String LINKED_LINK = 'https://www.linkedin.com/in/';

    /* HAM_AlumniConnectionService constant*/
    public static final String SEND_REQUEST = 'Send Request';
    public static final String CANCEL_REQUEST = 'Cancel Request';
    public static final String REMOVE_CONNECTION = 'Remove Connection';
    public static final String FAVORITE = 'Favorite';
    public static final String REMOVE_FAVORITE = 'Remove Favorite';
    public static final String BOOKMARK = 'Bookmark';
    public static final String REMOVE_BOOKMARK = 'Remove Bookmark';
    public static final String BLOCK = 'Block';
    public static final String UNBLOCK = 'Unblock';
    public static final String ACCEPT = 'Accept';
    public static final String REJECT = 'Reject';
    public static final String DISCONNECT = 'Disconnect';
    public static final String REJECTED = 'Rejected';
    

    /*Service Indicators*/
    public static final string ALUMNI_PRIVCACY_SVID = 'SIV_VIS_ALUMNI_PRIVACY';
    public static final string CONNECTION_PRIVCACY_SVID = 'SIV_VIS_CONNECTION';
    public static final string PROFILEPIC_PRIVCACY_SVID = 'SIV_VIS_PROFILE_PIC';

    // Email suppression. Unlike the SIV_VIS_* codes above this is the Service Indicator
    // Value's Name, not its HAM_Portal_ID__c, because that field is unpopulated on this
    // record. Swap to a portal ID once HQ populates one — see isEmailSuppressed().
    public static final String NO_CONTACT_MASS_EMAIL_SI = 'No Contact Mass Email';

    /*Events */
    public static final String CVENT_OBJECT_API = 'CventEvents__Event__c';
    public static final String BLACKTHORN_OBJECT_API = 'conference360__Event__c';
    public static final String HOST_AN_EVENT = 'Host an Event';



    public HAM_ConstantsUtil() {}
}