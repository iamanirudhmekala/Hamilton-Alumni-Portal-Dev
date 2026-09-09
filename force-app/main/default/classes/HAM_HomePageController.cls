/**
* @File Name : HAM_HomePageController.cls
* @Description : This class is used to fetch contact and philanthropy details on Home page.
* @Author : Cube84 - Asheesh
* @Last Modified By : Asheesh
* @Last Modified On : Dec 4, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | Dec 4, 2025 |  Asheesh | Initial Version
**/
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ExcessiveClassLength,PMD.ApexDoc,PMD.DebugsShouldUseLoggingLevel, PME.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
public without sharing class HAM_HomePageController {

    // Wrapper for child metadata fields
    public class DisplayFieldMetadata {
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String fieldPurpose;
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String fieldType;
        @AuraEnabled public Integer displayOrder;
        
        // Constructor for clean instantiation 
        public DisplayFieldMetadata(String api, String purpose, String label, String type, Integer order) {
            this.fieldApiName = api;
            this.fieldPurpose = purpose;
            this.fieldLabel = label;
            this.fieldType = type;
            this.displayOrder = order;
        }
    }

    // Consolidated structure to return metadata configuration details
    public class ComponentConfigData {
        @AuraEnabled public String sourceObjectApiName;
        @AuraEnabled public String whereClause;
        @AuraEnabled public Integer maxRecords;
        @AuraEnabled public String sortField;
        @AuraEnabled public String componentType;
        @AuraEnabled public Boolean isActive;
        
        @AuraEnabled public List<DisplayFieldMetadata> displayFields;
        @AuraEnabled public Map<String, String> purposeToApiMap; 
        @AuraEnabled public List<SObject> records;  // Added to get apex data
        @AuraEnabled public Map<String,VolunteerConfig> interestIdMap;
        
    }
    
    public class VolunteerConfig{
        @AuraEnabled public Boolean isInterested;
        @AuraEnabled public String activeInterestId;
    }


    // --- Private Central Metadata Fetcher ---

    /**
     * @description Fetches all metadata configuration and related display fields for a given key.
     * @param componentKey The unique key (CMP_Key__c) for the configuration.
     * @return ComponentConfigData object containing all configuration details.
     */
    private static ComponentConfigData getConfigData(String componentKey) {
        
        // Fetch Parent Configuration (Ham_Home_Page_Component_Config__mdt)
        HAM_Home_Page_Component_Config__mdt config = [
            SELECT Id, CMP_Type__c, Is_Active__c, Source_Object__c, Max_Records__c, 
                   Sort_Field__c, WHERE_Clause__c 
            FROM HAM_Home_Page_Component_Config__mdt 
            WHERE Is_Active__c = TRUE AND CMP_Key__c = :componentKey
            LIMIT 1
        ];

        if (config == null || !config.Is_Active__c) return null;

        // Fetch Child Display Fields (Ham_Home_Page_Child__mdt)
        // NOTE: The relationship field API Name is 'Ham_Home_Page_Component_Config__c'
        List<Ham_Home_Page_Child__mdt> fieldsMDT = [
            SELECT Field_Purpose__c, Field_API_Name__c, Display_Order__c, Field_Label__c, 
                   Field_Type__c
            FROM Ham_Home_Page_Child__mdt 
            WHERE Ham_Home_Page_Component_Config__c = :config.Id 
            ORDER BY Display_Order__c ASC
        ];
        
        if (fieldsMDT.isEmpty()) return null;
        
        ComponentConfigData data = new ComponentConfigData();
        data.sourceObjectApiName = config.Source_Object__c;
        data.whereClause = config.WHERE_Clause__c;
        data.maxRecords = config.Max_Records__c != null ? config.Max_Records__c.intValue() : 0;
        data.sortField = config.Sort_Field__c;
        data.componentType = config.CMP_Type__c;
        data.isActive = config.Is_Active__c;
        data.displayFields = new List<DisplayFieldMetadata>();
        data.purposeToApiMap = new Map<String, String>();

        // Map Child Metadata to the Apex output structure
        List<String> fieldApiNames = new List<String>();
        
        // Map Child Metadata to the Apex output structure
        for (Ham_Home_Page_Child__mdt mdt : fieldsMDT) {
            
            // Using the explicit constructor with positional arguments
            data.displayFields.add(new DisplayFieldMetadata(
                mdt.Field_API_Name__c, 
                mdt.Field_Purpose__c, 
                mdt.Field_Label__c, 
                mdt.Field_Type__c, 
                mdt.Display_Order__c != null ? mdt.Display_Order__c.intValue() : 0 
            ));
            
            // Populate the map for easy calculation reference in the LWC
            if (String.isNotBlank(mdt.Field_Purpose__c)) {
                 data.purposeToApiMap.put(mdt.Field_Purpose__c, mdt.Field_API_Name__c);
            }
            
            // ADDITION: Collect API names
            if (String.isNotBlank(mdt.Field_API_Name__c)) {
                fieldApiNames.add(mdt.Field_API_Name__c);
            }
        }
        
        // --- Dynamic SOQL Execution ---
        // Always select Id for LWC iteration keys
        fieldApiNames.add('Id'); 
        
        String fieldsToSelect = String.join(new Set<String>(fieldApiNames), ',');
        
        // Construct the SOQL query
        String soql = 'SELECT ' + fieldsToSelect + 
                      ' FROM ' + config.Source_Object__c + 
                      ' WHERE ' + config.WHERE_Clause__c;
                      
        if (String.isNotBlank(config.Sort_Field__c)) {
            //  ASC sorting for most feeds 
            soql += ' ORDER BY ' + config.Sort_Field__c + ' ASC'; 
        }
        
        soql += ' LIMIT ' + (config.Max_Records__c != null ? config.Max_Records__c.intValue() : 5);
        
        try {
            if(componentKey != HAM_ConstantsUtil.MY_VOLUNTEER_OPP)
            	data.records = Database.query(soql);
        } catch (Exception e) {
            System.debug('Dynamic SOQL Error for key ' + componentKey + ': ' + e.getMessage() + ' Query: ' + soql);
            data.records = new List<SObject>(); 
        }

        return data;
    }


    // --- Public LWC Callable Methods (Wrappers) ---

    /**
     * @Description : Fetches Logged in user's Portal Contact Id.
     * @return Data Type: String - Portal Contact Id
     */
    @AuraEnabled(cacheable=true)
    public static string fetchLoggedInUserInfo() {
        Id currentUserId = UserInfo.getUserId();
		// Query the User object to get the ContactId
        Id currentUserContactId;
        List<User> usr = [SELECT Id,Email,ContactId FROM User WHERE Id = :currentUserId LIMIT 1];
        if(usr != null && usr[0].ContactId != null) {
            currentUserContactId = usr[0].ContactId;
        }
		else {
            List<User> portalUsr = [Select Id,Name,ContactId FROM User WHERE Email = :usr[0].Email AND ContactId != null AND IsActive = true AND Profile.Name = 'Partner Community Login User' LIMIT 1];
            currentUserContactId = (portalUsr != null && !portalUsr.isEmpty()) ? portalUsr[0].ContactId : null;
        }
        return currentUserContactId;
    }

    /**
     * @description LWC entry point for the News Feed component.
     */
    @AuraEnabled(cacheable=true)
    public static ComponentConfigData getNewsConfig(String componentKey) {
        return getConfigData(componentKey); // Must match CMP_Key__c for News
    }

    /**
     * @description LWC entry point for the Events List component.
     */
    @AuraEnabled(cacheable=true)
    public static ComponentConfigData getEventsConfig(String componentKey) {
        
        ComponentConfigData data = getConfigData(componentKey); // Must match CMP_Key__c for News
        System.debug('getEventsConfig ' + data);
        return data;
        
    }

    /**
     * @description LWC entry point for the Gallery component.
     */
    @AuraEnabled(cacheable=true)
    public static ComponentConfigData getGalleryConfig(String componentKey) {
        return getConfigData(componentKey); // Must match CMP_Key__c for News
    }

    @AuraEnabled
    public static ComponentConfigData getVolunteerConfig(String componentKey) {
        
        // Initialize configuration wrapper with component metadata
        ComponentConfigData configData = new ComponentConfigData();
        configData = getConfigData(componentKey);
        
        // Initialize collections for opportunity data and user interest tracking
        List<SObject> opportunityList = new List<SObject>();
        configData.interestIdMap = new Map<String, VolunteerConfig>();
        
        // Fetch volunteer opportunities with current user's interest status
        List<HAM_VolunteerOpportunityController.OpportunityWrapper> opportunityData = 
            HAM_VolunteerOpportunityController.getOpportunities(
                HAM_ConstantsUtil.VOLUNTEER_OPP_HOME,
                0, 
                HAM_HomePageController.fetchLoggedInUserInfo()
            );
        
        // Process each opportunity and build interest tracking map
        for (HAM_VolunteerOpportunityController.OpportunityWrapper opr : opportunityData) {
            SObject volOpportunity = opr.opp;
            
            // Create volunteer config to track user's interest state
            VolunteerConfig vc = new VolunteerConfig();
            vc.isInterested = opr.isInterested;
            vc.activeInterestId = opr.activeInterestId;
            
            // Map opportunity Id to its interest configuration
            configData.interestIdMap.put(opr.opp.Id, vc);
            opportunityList.add(volOpportunity);
        }
        
        configData.records = opportunityList;
        
        return configData;
    }
    
    /**
     * @description LWC entry point for the Giving Day component.
     */
    @AuraEnabled(cacheable=true)
    public static ComponentConfigData getGivingDayConfig(String componentKey) {
        return getConfigData('GivingDayComponent'); // Must match CMP_Key__c for Giving Day
    }

    /**
     * @description Fetches up to 2 most recent volunteer involvements for the My Impact widget.
     * @param contactId The Contact Id of the logged-in portal user.
     */
    @AuraEnabled(cacheable=true)
    public static List<ucinn_ascendv2__Involvement__c> getVolunteerActivitiesForWidget(String contactId) {
        if (String.isBlank(contactId)) return new List<ucinn_ascendv2__Involvement__c>();

        return [
            SELECT Id, Name, ucinn_ascendv2__Involvement_Code__r.Name,
                   ucinn_ascendv2__Start_Date__c
            FROM ucinn_ascendv2__Involvement__c
            WHERE ucinn_ascendv2__Contact__c = :contactId
            AND ucinn_ascendv2__Start_Date__c != null
            AND ucinn_ascendv2__Start_Date__c <= TODAY
            AND HAM_Category__c = 'Career Center'
            ORDER BY ucinn_ascendv2__Start_Date__c DESC
            LIMIT 2
        ];
    }
    
    
     /**
    * @description : Method to get current user's Contact details and Philanthropy data for Home page
    * @param : currentUserContactId - contactId of logged in portal user.
    * @Returns : HAM_MyImpactController.MyImpactDataWrapper - wrapper  object.
    **/
    @AuraEnabled(cacheable=true)
	public static HAM_MyImpactController.MyImpactDataWrapper getContactAndPhilanthropyDataForHome(String currentUserContactId){
		HAM_MyImpactController.MyImpactDataWrapper response = new HAM_MyImpactController.MyImpactDataWrapper();
    
		// Dynamically building the SOQL query string for Constituent fields based on Custom Metadata and populating wrapper classes MyProfileBioData & MyProfileMyConnect
        String whereClause = 'HAM_Level_1__c IN (\'My Impact\')';
        List<HAM_MyImpactController.MyImpactMetadata> myImpactMetadataFieldsToQuery = HAM_MyImpactController.getMyImpactMetadata(whereClause);
        List<HAM_MyImpactController.BadgeMetadata> badgeMetdataFieldsToQuery = HAM_MyImpactController.getBadgeMetadata();

        Set<String> fieldApiNames = new Set<String>();
        response.philanthropyField = new list<HAM_MyImpactController.philanthropyField>();
        
        for(HAM_MyImpactController.MyImpactMetadata field : myImpactMetadataFieldsToQuery) {
            fieldApiNames.add(field.fieldApiName);            
        }

        for(HAM_MyImpactController.BadgeMetadata field : badgeMetdataFieldsToQuery) {
            fieldApiNames.add(field.mappingFieldApi);            
        }

        fieldApiNames.add('Is_Volunteer__c');

        String queryFields = String.join(new List<String>(fieldApiNames), ', ');


		
		
        // Main query to fetch constituent
		String queryString = 'SELECT Id, HAM_Total_Years_of_Giving__c,'+ queryFields + ' FROM Contact WHERE Id = \'' + String.escapeSingleQuotes(currentUserContactId) + '\' LIMIT 1';
        //system.debug('queryString---->'+ queryString);
		Contact constituentSObject = null;
		try {
            List<Contact> results = (List<Contact>)Database.query(queryString);
            
            if (!results.isEmpty()) {
                constituentSObject = results[0];
            }
        } catch (Exception e) {
             response.error = 'Failed to retrieve constituent details.';
             return response;
        }

        if (constituentSObject != null) {
           
            try{
                response.contact = new HAM_MyImpactController.ContactInfo();
                // populate ContactInfo wrapper from SObject
                response.contact.Id = constituentSObject.get('Id') != null ? (Id)constituentSObject.get('Id') : '';
                
                response.otherInfo = new HAM_MyImpactController.OtherInfo();
                //response.otherInfo.isGift = (constituentSObject.get('HAM_Current_FY_Paid__c') != null && (Decimal)constituentSObject.get('HAM_Current_FY_Paid__c') > 0) ? false : true;
                response.otherInfo.totalYearsOfGiving = constituentSObject.get('HAM_Total_Years_of_Giving__c') != null ? (Decimal)constituentSObject.get('HAM_Total_Years_of_Giving__c') : null;
                response.otherInfo.isVolunteer = constituentSObject.get('Is_Volunteer__c') != null ? (Boolean)constituentSObject.get('Is_Volunteer__c') : false;
                for(HAM_MyImpactController.MyImpactMetadata field: myImpactMetadataFieldsToQuery){

                    
                    //Populate philanthropy wrapper fields
                    if(field.level1 == HAM_ConstantsUtil.MY_IMPACT){
                        HAM_MyImpactController.PhilanthropyField myPhilanthropy = new HAM_MyImpactController.PhilanthropyField();
                        myPhilanthropy.label = field.displayLabel;
                        myPhilanthropy.order = field.displayOrder;
                        myPhilanthropy.sectionOrder = field.sectionOrder;
                        myPhilanthropy.value = ((field.fieldApiName != null) && constituentSObject.get(field.fieldApiName) != null)? String.valueOf(constituentSObject.get(field.fieldApiName)) : ' '; 
                        myPhilanthropy.type = field.type;
                        myPhilanthropy.sectionLabel = field.level2;
                        response.philanthropyField.add(myPhilanthropy);
                    }
                }

                // populate BadgeMetadata
                response.hcBadges = new List<HAM_MyImpactController.HCBadge>();                

                for (HAM_MyImpactController.BadgeMetadata badgeMdt : badgeMetdataFieldsToQuery) {
                    try {
                        // Check if the Contact has the corresponding boolean field set to true
                        Boolean hasBadge = constituentSObject.get(badgeMdt.mappingFieldApi) != null ? (Boolean)constituentSObject.get(badgeMdt.mappingFieldApi): false;
                        if (hasBadge == true) { 
                            HAM_MyImpactController.HCBadge badge = new HAM_MyImpactController.HCBadge();
                            badge.label = badgeMdt.displayName;
                            badge.imageUrl = badgeMdt.imagePath;
                            badge.order = badgeMdt.displayOrder;
                            response.hcBadges.add(badge);
                        }
                    } catch (Exception e) {
                        System.debug('Error checking badge field ' + badgeMdt.mappingFieldApi + ': ' + e.getMessage());
                    }
                }            

            }
            catch (Exception e){
                response.error = e.getMessage() + ' at line ' + e.getLineNumber();
                System.debug('Error processing constituentSObject data: ' + response.error);
            }                    
        }
        
        return response;
    }



    // ─────────────────────────────────────────────────────────────────────────
    // HOME PAGE REDIRECTION CARDS — DYNAMIC THUMBNAILS
    // ─────────────────────────────────────────────────────────────────────────

    // Card ids — must match the ids in the ham_redirectionCards LWC CARDS array
    private static final String CARD_DIRECTORY = 'directory';
    private static final String CARD_NEWS      = 'news';
    private static final String CARD_EVENTS    = 'events';
    private static final String CARD_GALLERY   = 'gallery';
    private static final String CARD_VOLUNTEER = 'volunteer';
    private static final String CARD_WEBCAM    = 'webcam';

    // Component keys of the News and Gallery home page widgets — reusing their config
    // keeps each card in step with the widget it points at.
    private static final String NEWS_CMP_KEY    = 'NewsFeedLWC';
    private static final String GALLERY_CMP_KEY = 'GalleryGridLWC';

    private static final String LISTING_IMAGE_PURPOSE = 'Image';
    private static final String RESOURCES_CATEGORY    = 'Resources';
    private static final String VIDEO_FLAG_FIELD      = 'HAM_Is_Video_Content__c';

    /** Resolved thumbnail for a single redirection card. linkUrl is only used by Webcam. */
    public class RedirectionCardImage {
        @AuraEnabled public String imageUrl;
        @AuraEnabled public String linkUrl;

        public RedirectionCardImage(String imageUrl, String linkUrl) {
            this.imageUrl = imageUrl;
            this.linkUrl  = linkUrl;
        }
    }

    /**
     * @description Resolves the dynamic thumbnail for each Home Page redirection card:
     *                Directory  — profile picture of the latest connection made.
     *                News       — image of the first article the News widget shows.
     *                Events     — next registered upcoming event, else next upcoming event.
     *                Gallery    — first non-video image in the homepage gallery set.
     *                Volunteer  — latest current volunteer service, else first opportunity.
     *                Webcam     — image and link of the Webcam resource listing.
     *              My Impact and Trivia have no rule and are never returned.
     *
     *              A card only appears in the map when a real value resolved; the LWC
     *              keeps its static production image for anything absent. Every card
     *              resolves in isolation so one failure cannot blank the whole strip.
     *
     * @param contactId Contact Id of the logged-in portal user.
     * @return Map of card id to RedirectionCardImage.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, RedirectionCardImage> getRedirectionCardImages(String contactId) {

        Map<String, RedirectionCardImage> cardImages = new Map<String, RedirectionCardImage>();

        if (String.isBlank(contactId)) {
            return cardImages;
        }

        putCard(cardImages, CARD_DIRECTORY, resolveDirectoryImage(contactId));
        putCard(cardImages, CARD_NEWS,      resolveListingImage(NEWS_CMP_KEY, false));
        putCard(cardImages, CARD_GALLERY,   resolveListingImage(GALLERY_CMP_KEY, true));
        putCard(cardImages, CARD_EVENTS,    resolveEventsImage(contactId));
        putCard(cardImages, CARD_VOLUNTEER, resolveVolunteerImage(contactId));

        // Webcam carries a link as well as an image, so it is added directly.
        RedirectionCardImage webcamCard = resolveWebcamCard();
        if (webcamCard != null) {
            cardImages.put(CARD_WEBCAM, webcamCard);
        }

        return cardImages;
    }

    /**
     * @description Profile picture of the most recently made connection. A connection
     *              without a picture is treated the same as having no connections at
     *              all — the card falls back to its production image.
     */
    private static String resolveDirectoryImage(String contactId) {
        try {
            List<HAM_Connection__c> connections = [
                SELECT HAM_Linked_Constituent__r.HAM_Profile_Picture_URL__c
                FROM HAM_Connection__c
                WHERE HAM_Portal_User__c = :contactId
                  AND HAM_Is_Connected__c = true
                  AND HAM_Is_Blocked__c = false
                  AND HAM_Linked_Constituent__r.ucinn_ascendv2__Is_Deceased__c = false
                  AND HAM_Linked_Constituent__r.HAM_Is_Active__c = true
                ORDER BY CreatedDate DESC, Id DESC
                LIMIT 1
            ];

            if (connections.isEmpty() || connections[0].HAM_Linked_Constituent__r == null) {
                return null;
            }

            return connections[0].HAM_Linked_Constituent__r.HAM_Profile_Picture_URL__c;

        } catch (Exception e) {
            System.debug('getRedirectionCardImages — directory: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Image of the first record a HAM_Listing__c backed widget shows, read
     *              through that widget's own metadata config so the card and the widget
     *              cannot drift apart.
     * @param componentKey   CMP_Key__c of the widget config to reuse.
     * @param skipVideoItems Gallery only — pass over video entries to reach a real image.
     */
    private static String resolveListingImage(String componentKey, Boolean skipVideoItems) {
        try {
            ComponentConfigData config = getConfigData(componentKey);

            if (config == null || config.records == null || config.records.isEmpty()) {
                return null;
            }

            String imageApiName = config.purposeToApiMap != null
                ? config.purposeToApiMap.get(LISTING_IMAGE_PURPOSE)
                : null;

            if (String.isBlank(imageApiName)) {
                return null;
            }

            for (SObject record : config.records) {
                if (skipVideoItems == true && isVideoItem(record)) {
                    continue;
                }
                // First eligible record wins — a blank image on it falls back to the
                // static card rather than walking further down the list.
                return safeStringField(record, imageApiName);
            }

            return null;

        } catch (Exception e) {
            System.debug('getRedirectionCardImages — listing ' + componentKey + ': ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Next upcoming event the user is registered for, else the next
     *              upcoming event. Delegated to the events controller, which owns the
     *              Cvent field metadata and the "upcoming" rule.
     */
    private static String resolveEventsImage(String contactId) {
        try {
            return Ham_UpcomingEventsController.getHomePageEventThumbnail(contactId);
        } catch (Exception e) {
            System.debug('getRedirectionCardImages — events: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Latest current volunteer service image; when the user has no service
     *              history, the first volunteering opportunity shown on the home page.
     */
    private static String resolveVolunteerImage(String contactId) {
        try {
            String serviceImage = HAM_VolunteerOpportunityController.getLatestCurrentVolunteerImage(contactId);

            if (String.isNotBlank(serviceImage)) {
                return serviceImage;
            }

            List<HAM_VolunteerOpportunityController.OpportunityWrapper> opportunities =
                HAM_VolunteerOpportunityController.getOpportunities(
                    HAM_ConstantsUtil.VOLUNTEER_OPP_HOME,
                    0,
                    contactId
                );

            if (opportunities.isEmpty() || opportunities[0].opp == null) {
                return null;
            }

            return opportunities[0].opp.HAM_Image_URL__c;

        } catch (Exception e) {
            System.debug('getRedirectionCardImages — volunteer: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Image and click-through link of the Webcam resource — the same
     *              HAM_Listing__c record the community Resources tab renders. The title
     *              to match lives in the ham_webcamResourceTitle custom label so it can
     *              be renamed without a code change.
     */
    private static RedirectionCardImage resolveWebcamCard() {
        try {
            String webcamTitle = System.Label.ham_webcamResourceTitle;

            if (String.isBlank(webcamTitle)) {
                return null;
            }

            String titleFilter = '%' + webcamTitle.trim() + '%';

            List<HAM_Listing__c> resources = [
                SELECT HAM_Image_URL__c, HAM_Actual_link__c
                FROM HAM_Listing__c
                WHERE HAM_Category__c = :RESOURCES_CATEGORY
                  AND HAM_Is_Active__c = true
                  AND HAM_Title__c LIKE :titleFilter
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (resources.isEmpty()) {
                return null;
            }

            String imageUrl = resources[0].HAM_Image_URL__c;
            String linkUrl  = resources[0].HAM_Actual_link__c;

            // The link alone is worth returning — the card can still open the webcam
            // while showing its static image.
            if (String.isBlank(imageUrl) && String.isBlank(linkUrl)) {
                return null;
            }

            return new RedirectionCardImage(
                String.isBlank(imageUrl) ? null : imageUrl,
                String.isBlank(linkUrl)  ? null : linkUrl
            );

        } catch (Exception e) {
            System.debug('getRedirectionCardImages — webcam: ' + e.getMessage());
            return null;
        }
    }

    /** Adds a card only when an image actually resolved. */
    private static void putCard(Map<String, RedirectionCardImage> cardImages, String cardId, String imageUrl) {
        if (String.isNotBlank(imageUrl)) {
            cardImages.put(cardId, new RedirectionCardImage(imageUrl, null));
        }
    }

    /** True when a gallery listing holds video content rather than an image. */
    private static Boolean isVideoItem(SObject record) {
        try {
            Object value = record.get(VIDEO_FLAG_FIELD);
            return value != null && (Boolean) value;
        } catch (Exception e) {
            // Field not part of the widget's configured query — treat it as an image.
            return false;
        }
    }

    /** Reads a field that was resolved dynamically from metadata, tolerating gaps. */
    private static String safeStringField(SObject record, String fieldApiName) {
        try {
            Object value = record.get(fieldApiName);
            return value == null ? null : String.valueOf(value);
        } catch (Exception e) {
            return null;
        }
    }
}