// 04/08/2026 NVV: ASC-13038 - Added Funding Interest factory methods; applied ApexDoc standards
//#HAMJediActivityControllerTest
/**
 * @description Shared test data factory for all HAMJedi test classes.
 * Add new builder methods here rather than creating inline test data in individual test classes.
 */
@IsTest
public class HAMJediTestDataFactory {
    
    // Constants for better maintainability
    private static final String DEFAULT_CANCELLATION_REASON = 'Other';
    private static final String DEFAULT_TASK_STATUS = 'Open';
    private static final Integer DEFAULT_MEETING_DURATION_HOURS = 1;
    
    // ---- Generic helpers ----
    /**
     * @description Safely retrieves a valid picklist value, preferring the specified value if active
     * @param objectApi The API name of the SObject
     * @param fieldApi The API name of the picklist field
     * @param preferred The preferred picklist value if it exists and is active
     * @param fallback The fallback value if preferred is not available
     * @return A valid picklist value or the fallback
     */
    private static String pickValue(String objectApi, String fieldApi, String preferred, String fallback) {
        try {
            Schema.SObjectType sObj = Schema.getGlobalDescribe().get(objectApi);
            if (sObj == null) return fallback;
            
            Schema.SObjectField field = sObj.getDescribe().fields.getMap().get(fieldApi);
            if (field == null) return fallback;
            
            Schema.DescribeFieldResult f = field.getDescribe();

            // If preferred exists & active, return it
            if (preferred != null) {
                for (Schema.PicklistEntry e : f.getPicklistValues()) {
                    if (e.isActive() && e.getValue() == preferred) {
                        return preferred;
                    }
                }
            }
            
            // Else return first active
            for (Schema.PicklistEntry e : f.getPicklistValues()) {
                if (e.isActive()) {
                    return e.getValue();
                }
            }
        } catch (Exception e) {
            // Log exception in debug logs for troubleshooting
            System.debug(LoggingLevel.WARN, 'Error getting picklist value: ' + e.getMessage());
        }
        return fallback;
    }

    // ---- Core records ----
    /**
     * @description Creates a test Account with a unique name
     * @return The inserted Account record
     */
    public static Account makeAccount() {
        return makeAccount('Test Acct ' + System.now().getTime());
    }
    
    /**
     * @description Creates a test Account with a specific name
     * @param accountName The name for the account
     * @return The inserted Account record
     */
    public static Account makeAccount(String accountName) {
        Account a = new Account(Name = accountName);
        insert a;
        return a;
    }

    /**
     * @description Creates a test Contact associated with an Account
     * @param accountId The ID of the parent Account
     * @return The inserted Contact record
     */
    public static Contact makeContact(Id accountId) {
        return makeContact('Test ' + System.now().getTime(), accountId);
    }
    
    /**
     * @description Creates a test Contact with specific name and Account
     * @param lastName The last name for the contact
     * @param accountId The ID of the parent Account
     * @return The inserted Contact record
     */
    public static Contact makeContact(String lastName, Id accountId) {
        Contact c = new Contact(
            LastName = lastName, 
            AccountId = accountId
        );
        insert c;
        return c;
    }

    // ---- Event builders ----
    /**
     * @description Creates a completed Event
     * @param whoId The ID of the related Contact or Lead
     * @param start The start datetime of the event
     * @return The inserted Event record
     */
    public static Event makeCompletedEvent(Id whoId, Datetime start) {
        return makeCompletedEvent(whoId, start, 'Completed Meeting');
    }
    
    /**
     * @description Creates a completed Event with custom subject
     * @param whoId The ID of the related Contact or Lead
     * @param start The start datetime of the event
     * @param subject The subject of the event
     * @return The inserted Event record
     */
    public static Event makeCompletedEvent(Id whoId, Datetime start, String subject) {
        Event e = new Event(
            Subject = subject,
            StartDateTime = start,
            EndDateTime = start.addHours(DEFAULT_MEETING_DURATION_HOURS),
            WhoId = whoId,
            HAM_Meeting_Status__c = 'Completed'
        );
        insert e;
        return e;
    }

    /**
     * @description Creates a cancelled Event
     * @param whoId The ID of the related Contact or Lead
     * @param start The start datetime of the event
     * @return The inserted Event record
     */
    public static Event makeCancelledEvent(Id whoId, Datetime start) {
        return makeCancelledEvent(whoId, start, null);
    }
    
    /**
     * @description Creates a cancelled Event with specific cancellation reason
     * @param whoId The ID of the related Contact or Lead
     * @param start The start datetime of the event
     * @param cancellationReason The reason for cancellation (null to use default)
     * @return The inserted Event record
     */
    public static Event makeCancelledEvent(Id whoId, Datetime start, String cancellationReason) {
        String reason = cancellationReason != null ? 
            cancellationReason : 
            pickValue('Event', 'HAM_Meeting_cancellation_Reason__c', DEFAULT_CANCELLATION_REASON, DEFAULT_CANCELLATION_REASON);
            
        Event e = new Event(
            Subject = 'Cancelled Meeting',
            StartDateTime = start,
            EndDateTime = start.addHours(DEFAULT_MEETING_DURATION_HOURS),
            WhoId = whoId,
            HAM_Meeting_Status__c = 'Cancelled',
            HAM_Meeting_cancellation_Reason__c = reason
        );
        insert e;
        return e;
    }

    /**
     * @description Creates a planned/upcoming Event (status intentionally null)
     * @param whoId The ID of the related Contact or Lead
     * @param start The start datetime of the event
     * @return The inserted Event record
     */
    public static Event makePlannedEvent(Id whoId, Datetime start) {
        return makePlannedEvent(whoId, start, 'Planned Meeting');
    }
    
    /**
     * @description Creates a planned/upcoming Event with custom subject
     * @param whoId The ID of the related Contact or Lead
     * @param start The start datetime of the event
     * @param subject The subject of the event
     * @return The inserted Event record
     */
    public static Event makePlannedEvent(Id whoId, Datetime start, String subject) {
        Event e = new Event(
            Subject = subject,
            StartDateTime = start,
            EndDateTime = start.addHours(DEFAULT_MEETING_DURATION_HOURS),
            WhoId = whoId
            // HAM_Meeting_Status__c intentionally left null for "upcoming" bucket
        );
        insert e;
        return e;
    }

    // ---- Task builders ----
    /**
     * @description Creates an open Task
     * @param whoId The ID of the related Contact or Lead
     * @param dueDate The due date for the task
     * @return The inserted Task record
     */
    public static Task makeOpenTask(Id whoId, Date dueDate) {
        return makeOpenTask(whoId, dueDate, 'Follow up');
    }
    
    /**
     * @description Creates an open Task with custom subject
     * @param whoId The ID of the related Contact or Lead
     * @param dueDate The due date for the task
     * @param subject The subject of the task
     * @return The inserted Task record
     */
    public static Task makeOpenTask(Id whoId, Date dueDate, String subject) {
        String openStatus = pickValue('Task', 'Status', DEFAULT_TASK_STATUS, DEFAULT_TASK_STATUS);
        Task t = new Task(
            Subject = subject,
            ActivityDate = dueDate,
            WhoId = whoId,
            Status = openStatus
        );
        insert t;
        return t;
    }
    
    /**
     * @description Creates a completed Task
     * @param whoId The ID of the related Contact or Lead
     * @param dueDate The due date for the task
     * @return The inserted Task record
     */
    public static Task makeCompletedTask(Id whoId, Date dueDate) {
        String completedStatus = pickValue('Task', 'Status', 'Completed', 'Completed');
        Task t = new Task(
            Subject = 'Completed task',
            ActivityDate = dueDate,
            WhoId = whoId,
            Status = completedStatus
        );
        insert t;
        return t;
    }

    // ---- Bulk creation methods ----
    /**
     * @description Creates multiple test Accounts
     * @param count The number of accounts to create
     * @return List of inserted Account records
     */
    public static List<Account> makeAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(Name = 'Test Acct ' + i + '_' + System.now().getTime()));
        }
        insert accounts;
        return accounts;
    }
    
    /**
     * @description Creates multiple test Contacts for a single Account
     * @param accountId The ID of the parent Account
     * @param count The number of contacts to create
     * @return List of inserted Contact records
     */
    public static List<Contact> makeContacts(Id accountId, Integer count) {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            contacts.add(new Contact(
                LastName = 'Test ' + i + '_' + System.now().getTime(),
                AccountId = accountId
            ));
        }
        insert contacts;
        return contacts;
    }

    // ---- Dataset seeding methods ----
    /**
     * @description Seeds a basic set of activities for a contact
     * @param contactId The ID of the contact to create activities for
     */
    public static void seedBasicActivityDataset(Id contactId) {
        makeCompletedEvent(contactId, System.now().addDays(-2));
        makeCancelledEvent(contactId, System.now().addDays(1));
        makePlannedEvent(contactId, System.now().addDays(3));
        makeOpenTask(contactId, Date.today().addDays(1));
    }
    
    /**
     * @description Creates a complete test dataset with Account, Contact, and Activities
     * @return Map containing 'account', 'contact', 'events', and 'tasks' keys
     */
    public static Map<String, Object> createFullTestDataset() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id);
        
        List<Event> events = new List<Event>{
            makeCompletedEvent(con.Id, System.now().addDays(-2)),
            makeCancelledEvent(con.Id, System.now().addDays(1)),
            makePlannedEvent(con.Id, System.now().addDays(3))
        };
        
        List<Task> tasks = new List<Task>{
            makeOpenTask(con.Id, Date.today().addDays(1)),
            makeCompletedTask(con.Id, Date.today().addDays(-1))
        };
        
        return new Map<String, Object>{
            'account' => acc,
            'contact' => con,
            'events' => events,
            'tasks' => tasks
        };
    }

    

   
    

    // ---- ExactTarget Email Send Definition builder ----
    /**
     * @description Creates a test Email Send Definition record
     * @return The inserted Email Send Definition record
     */
    public static et4ae5__SendDefinition__c makeEmailSendDefinition() {
        et4ae5__SendDefinition__c sendDef = new et4ae5__SendDefinition__c();
        insert sendDef;
        return sendDef;
    }

    // ---- ExactTarget Email Result builders ----
    /**
     * @description Creates a test Individual Email Result record with default values
     * @param contactId The ID of the related Contact
     * @return The inserted Email Result record
     */
    public static et4ae5__IndividualEmailResult__c makeEmailResult(Id contactId) {
        et4ae5__SendDefinition__c sendDef = makeEmailSendDefinition();
        return makeEmailResult(contactId, sendDef.Id, 'Test Sender', 'test@example.com', 'Test Subject');
    }
    
    /**
     * @description Creates a test Individual Email Result record with custom values
     * @param contactId The ID of the related Contact
     * @param sendDefinitionId The ID of the Email Send Definition
     * @param fromName The sender name
     * @param fromAddress The sender email address
     * @param subject The email subject
     * @return The inserted Email Result record
     */
    public static et4ae5__IndividualEmailResult__c makeEmailResult(Id contactId, Id sendDefinitionId, String fromName, String fromAddress, String subject) {
        et4ae5__IndividualEmailResult__c emailResult = new et4ae5__IndividualEmailResult__c(
            Name = 'Test Email Result ' + System.now().getTime(),
            et4ae5__Contact__c = contactId,
            et4ae5__SendDefinition__c = sendDefinitionId,
            et4ae5__FromName__c = fromName,
            et4ae5__FromAddress__c = fromAddress,
            et4ae5__SubjectLine__c = subject,
            et4ae5__HardBounce__c = false,
            et4ae5__SoftBounce__c = false,
            et4ae5__Opened__c = true,
            et4ae5__DateOpened__c = System.now().addHours(-1),
            et4ae5__NumberOfTotalClicks__c = 5,
            et4ae5__NumberOfUniqueClicks__c = 3
        );
        insert emailResult;
        return emailResult;
    }
    
    /**
     * @description Creates multiple test Email Result records for a contact
     * @param contactId The ID of the related Contact
     * @param count The number of email result records to create
     * @return List of inserted Email Result records
     */
    public static List<et4ae5__IndividualEmailResult__c> makeEmailResults(Id contactId, Integer count) {
        List<et4ae5__IndividualEmailResult__c> emailResults = new List<et4ae5__IndividualEmailResult__c>();
        
        for (Integer i = 0; i < count; i++) {
            et4ae5__SendDefinition__c sendDef = makeEmailSendDefinition();
            emailResults.add(new et4ae5__IndividualEmailResult__c(
                Name = 'Test Email Result ' + i + '_' + System.now().getTime(),
                et4ae5__Contact__c = contactId,
                et4ae5__SendDefinition__c = sendDef.Id,
                et4ae5__FromName__c = 'Sender ' + i,
                et4ae5__FromAddress__c = 'sender' + i + '@example.com',
                et4ae5__SubjectLine__c = 'Email Subject ' + i,
                et4ae5__HardBounce__c = false,
                et4ae5__SoftBounce__c = false,
                et4ae5__Opened__c = true,
                et4ae5__DateOpened__c = System.now().addHours(-i),
                et4ae5__NumberOfTotalClicks__c = 5,
                et4ae5__NumberOfUniqueClicks__c = 3
            ));
        }
        insert emailResults;
        return emailResults;
    }

    

    //#HAMJediSearchControllerTest
   // ---- Contact builders with donor ID for search testing ----
    /**
     * @description Creates a test Contact with donor ID for search functionality
     * @param lastName The last name for the contact
     * @param accountId The ID of the parent Account
     * @param donorId The donor ID for the contact
     * @return The inserted Contact record
     */
    public static Contact makeContactWithDonorId(String lastName, Id accountId, String donorId) {
        Contact c = new Contact(
            LastName = lastName,
            AccountId = accountId,
            ucinn_ascendv2__Donor_ID__c = donorId,
            Email = lastName.toLowerCase() + '@test.com',
            Phone = '5551234567'
        );
        insert c;
        return c;
    }

    /**
     * @description Creates a test Contact with auto-generated donor ID
     * @param lastName The last name for the contact
     * @param accountId The ID of the parent Account
     * @return The inserted Contact record
     */
    public static Contact makeContactWithDonorId(String lastName, Id accountId) {
        return makeContactWithDonorId(lastName, accountId, 'D' + String.valueOf(System.now().getTime()).right(8));
    }

    /**
     * @description Creates multiple test Contacts with donor IDs
     * @param accountId The ID of the parent Account
     * @param count The number of contacts to create
     * @return List of inserted Contact records
     */
    public static List<Contact> makeContactsWithDonorIds(Id accountId, Integer count) {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            String lastName = 'TestContact' + i;
            contacts.add(new Contact(
                LastName = lastName,
                AccountId = accountId,
                ucinn_ascendv2__Donor_ID__c = 'D' + String.valueOf(System.now().getTime() + i).right(8),
                Email = lastName.toLowerCase() + '@test.com',
                Phone = '555123456' + i
            ));
        }
        insert contacts;
        return contacts;
    }

    //#HAMProspectOverviewApexControllerTest
    // ---- ucinn_ascendv2 objects for prospect testing ----
    /**
     * @description Creates a test Designation record
     * @return The inserted Designation record
     */
    public static ucinn_ascendv2__Designation__c makeDesignation() {
        ucinn_ascendv2__Designation__c designation = new ucinn_ascendv2__Designation__c(
            ucinn_ascendv2__Designation_Name__c = 'Test Fund ' + System.now().getTime(),
            ucinn_ascendv2__Fund_Name__c = 'Test Fund'
        );
        insert designation;
        return designation;
    }

    /**
     * @description Creates a test Designation Stewardship record
     * @param contactId The ID of the related Contact
     * @param designationId The ID of the related Designation
     * @return The inserted Designation Stewardship record
     */
    public static ucinn_ascendv2__Designation_Stewardship__c makeDesignationStewardship(Id contactId, Id designationId) {
        ucinn_ascendv2__Designation_Stewardship__c stewardship = new ucinn_ascendv2__Designation_Stewardship__c(
            ucinn_ascendv2__Contact_Stewardee__c = contactId,
            ucinn_ascendv2__Designation__c = designationId,
            ucinn_ascendv2__Status__c = 'Current',
            HAM_Reporting_Type__c = 'Active'
        );
        insert stewardship;
        return stewardship;
    }

    /**
     * @description Creates a test Service Indicator record
     * @param contactId The ID of the related Contact
     * @return The inserted Service Indicator record
     */
    public static ucinn_ascendv2__Service_Indicator__c makeServiceIndicator(Id contactId) {
        ucinn_ascendv2__Service_Indicator__c indicator = new ucinn_ascendv2__Service_Indicator__c(
            ucinn_ascendv2__Contact__c = contactId
        );
        insert indicator;
        return indicator;
    }

    /**
     * @description Creates a test Degree Information record
     * @param contactId The ID of the related Contact
     * @return The inserted Degree Information record
     */
    public static ucinn_ascendv2__Degree_Information__c makeDegreeInformation(Id contactId) {
        ucinn_ascendv2__Degree_Information__c degree = new ucinn_ascendv2__Degree_Information__c(
            ucinn_ascendv2__Contact__c = contactId,
            ucinn_ascendv2__Conferred_Degree_Year__c = '2020'
        );
        insert degree;
        return degree;
    }

    /**
     * @description Creates a test Involvement record
     * @param contactId The ID of the related Contact
     * @return The inserted Involvement record
     */
    public static ucinn_ascendv2__Involvement__c makeInvolvement(Id contactId) {
        ucinn_ascendv2__Involvement__c involvement = new ucinn_ascendv2__Involvement__c(
            ucinn_ascendv2__Contact__c = contactId
        );
        insert involvement;
        return involvement;
    }

    /**
     * @description Creates a test Designation Beneficiary record (for awards)
     * @param contactId The ID of the related Contact
     * @return The inserted Designation Beneficiary record
     */
    public static ucinn_ascendv2__Designation_Beneficiary__c makeDesignationBeneficiary(Id contactId) {
        ucinn_ascendv2__Designation__c designation = makeDesignation();
        
        ucinn_ascendv2__Designation_Beneficiary__c beneficiary = new ucinn_ascendv2__Designation_Beneficiary__c(
            ucinn_ascendv2__Contact__c = contactId,
            ucinn_ascendv2__Designation__c = designation.Id,
            ucinn_ascendv2__Type__c = 'Award',
            ucinn_ascendv2__Fiscal_Year__c = String.valueOf(Date.today().year())
        );
        insert beneficiary;
        return beneficiary;
    }

    //#HAMJediContactReportControllerTest
    /**
     * @description Creates a test Contact Report record
     * @param contactId The ID of the related Contact
     * @return The inserted Contact Report record
     */
    public static ucinn_ascendv2__Contact_Report__c makeContactReport(Id contactId) {
        ucinn_ascendv2__Contact_Report__c contactReport = new ucinn_ascendv2__Contact_Report__c(
            ucinn_ascendv2__Contact__c = contactId,
            ucinn_ascendv2__Contact_Method__c = 'In Person',
            ucinn_ascendv2__Substantive_Contact__c = 'Yes',
            ucinn_ascendv2__Description__c = 'Test contact report',
            ucinn_ascendv2__Contact_Report_Body__c = 'This is a test contact report body',
            ucinn_ascendv2__Date__c = Date.today()
        );
        insert contactReport;
        return contactReport;
    }

    /**
     * @description Creates multiple test Contact Report records
     * @param contactId The ID of the related Contact
     * @param count The number of contact reports to create
     * @return List of inserted Contact Report records
     */
    public static List<ucinn_ascendv2__Contact_Report__c> makeContactReports(Id contactId, Integer count) {
        List<ucinn_ascendv2__Contact_Report__c> reports = new List<ucinn_ascendv2__Contact_Report__c>();
        for (Integer i = 0; i < count; i++) {
            String substantiveValue = Math.mod(i, 2) == 0 ? 'Yes' : 'No';
            reports.add(new ucinn_ascendv2__Contact_Report__c(
                ucinn_ascendv2__Contact__c = contactId,
                ucinn_ascendv2__Contact_Method__c = 'Email',
                ucinn_ascendv2__Substantive_Contact__c = substantiveValue,
                ucinn_ascendv2__Description__c = 'Test report ' + i,
                ucinn_ascendv2__Contact_Report_Body__c = 'Test body ' + i,
                ucinn_ascendv2__Date__c = Date.today().addDays(-i)
            ));
        }
        insert reports;
        return reports;
    }

   
// ============================================
// ADD THIS TO BOTTOM OF HAMJediTestDataFactory
// ============================================

    /**
     * @description Creates a test Contact with all fields needed for search testing
     * @param lastName The last name for the contact
     * @param accountId The ID of the parent Account
     * @param donorId The donor ID
     * @param classYear The class/reunion year
     * @return The inserted Contact record
     */
    public static Contact makeSearchContact(String lastName, Id accountId, String donorId, String classYear) {
        Contact c = new Contact(
            LastName = lastName,
            AccountId = accountId,
            ucinn_ascendv2__Donor_ID__c = donorId,
            HAM_Reunion_Year__c = classYear,
            Email = lastName.toLowerCase() + '@test.com',
            Phone = '5551234567'
        );
        insert c;
        return c;
    }

    /**
     * @description Creates a test Involvement Value record for search options
     * @param category The HAM_Category value
     * @param description The involvement description
     * @return The inserted Involvement Value record
     */
    public static ucinn_ascendv2__Involvement_Value__c makeInvolvementValue(String category, String description) {
        ucinn_ascendv2__Involvement_Value__c invValue = new ucinn_ascendv2__Involvement_Value__c(
            Name = description,
            HAM_Category__c = category,
            ucinn_ascendv2__Involvement_Description__c = description
        );
        insert invValue;
        return invValue;
    }

    /**
     * @description Links a Contact to an Involvement using existing method
     * @param contactId The ID of the contact
     * @return The inserted Involvement record
     */
    public static ucinn_ascendv2__Involvement__c makeContactInvolvement(Id contactId) {
        return makeInvolvement(contactId);
    }

    //#HAMJediSearchControllerTest - getAssignedRecords
    /**
     * @description Creates a test Assignment record
     * @param contactId The ID of the contact
     * @param accountId The ID of the account
     * @param userId The ID of the user
     * @return The inserted Assignment record
     */
    public static ucinn_ascendv2__Assignment__c makeAssignment(Id contactId, Id accountId, Id userId) {
        ucinn_ascendv2__Assignment__c assignment = new ucinn_ascendv2__Assignment__c(
            ucinn_ascendv2__Contact__c = contactId,
            ucinn_ascendv2__Account__c = accountId,
            ucinn_ascendv2__Assigned_Relationship_Manager_User__c = userId,
            ucinn_ascendv2__Assignment_Type__c = 'Career Advising'
        );
        insert assignment;
        return assignment;
    }

    /**
     * @description Creates a test Involvement Value for Career Center
     * @return The inserted Involvement Value record
     */
    public static ucinn_ascendv2__Involvement_Value__c makeCareerCenterInvolvementValue() {
        ucinn_ascendv2__Involvement_Value__c invValue = new ucinn_ascendv2__Involvement_Value__c(
            Name = 'Career Center Activity',
            HAM_Category__c = 'Career Center',
            ucinn_ascendv2__Type__c = 'Volunteer Engagement',
            ucinn_ascendv2__Involvement_Description__c = 'Career Center Engagement'
        );
        insert invValue;
        return invValue;
    }

    /**
     * @description Creates a test Involvement record linked to an account
     * @param accountId The ID of the account
     * @param involvementCodeId The ID of the involvement value
     * @param startDate The start date of the involvement
     * @return The inserted Involvement record (or null if insert fails due to validation)
     */
    public static ucinn_ascendv2__Involvement__c makeAccountInvolvement(Id accountId, Id involvementCodeId, Date startDate) {
        try {
            ucinn_ascendv2__Involvement__c involvement = new ucinn_ascendv2__Involvement__c(
                ucinn_ascendv2__Account__c = accountId,
                ucinn_ascendv2__Involvement_Code__c = involvementCodeId,
                ucinn_ascendv2__Start_Date__c = startDate
            );
            insert involvement;
            return involvement;
        } catch (DmlException e) {
            // If validation fails (e.g., record type mismatch), return null
            System.debug('Could not create account involvement: ' + e.getMessage());
            return null;
        }
    }

    //#HAMCCInterestViewControllerTest
    /**
     * @description Creates a test Foundation Funding Interest record for a given category.
     * @param category The HAM_Category__c value (e.g. 'Career Center')
     * @return The inserted Foundation Funding Interest record
     */
    public static ucinn_ascendv2__Foundation_Funding_Interests__c makeFoundationFundingInterest(String category) {
        ucinn_ascendv2__Foundation_Funding_Interests__c obj = new ucinn_ascendv2__Foundation_Funding_Interests__c(
            Name                       = 'Foundation Interest ' + System.now().getTime(),
            HAM_Category__c            = category,
            HAM_Is_Publicly_Visible__c = true,
            HAM_Is_Volunteer__c        = true
        );
        insert obj;
        return obj;
    }

    /**
     * @description Creates a test Funding Interest record linked to a Contact.
     * @param contactId The ID of the related Contact
     * @param ffiId The ID of the Foundation Funding Interest lookup (nullable)
     * @param startDate The start date
     * @param endDate The end date (nullable)
     * @return The inserted Funding Interest record
     */
    public static ucinn_ascendv2__Funding_Interest__c makeFundingInterestForContact(Id contactId, Id ffiId, Date startDate, Date endDate) {
        ucinn_ascendv2__Funding_Interest__c fi = new ucinn_ascendv2__Funding_Interest__c(
            ucinn_ascendv2__Contact__c                     = contactId,
            ucinn_ascendv2__Foundation_Funding_Interest__c = ffiId,
            HAM_Category__c                                = 'Career Center',
            ucinn_ascendv2__Start_Date__c                  = startDate,
            ucinn_ascendv2__End_Date__c                    = endDate
        );
        insert fi;
        return fi;
    }

    /**
     * @description Creates a test Funding Interest record linked to an Account.
     * @param accountId The ID of the related Account
     * @param ffiId The ID of the Foundation Funding Interest lookup (nullable)
     * @param startDate The start date
     * @param endDate The end date (nullable)
     * @return The inserted Funding Interest record
     */
    public static ucinn_ascendv2__Funding_Interest__c makeFundingInterestForAccount(Id accountId, Id ffiId, Date startDate, Date endDate) {
        ucinn_ascendv2__Funding_Interest__c fi = new ucinn_ascendv2__Funding_Interest__c(
            ucinn_ascendv2__Account__c                     = accountId,
            ucinn_ascendv2__Foundation_Funding_Interest__c = ffiId,
            HAM_Category__c                                = 'Career Center',
            ucinn_ascendv2__Start_Date__c                  = startDate,
            ucinn_ascendv2__End_Date__c                    = endDate
        );
        insert fi;
        return fi;
    }

    //#HAMJEDIGivingSocietyCtrlTest
    // ---- Giving Society builders ----
    /**
     * @description Creates a test Giving Society record
     * @param name The name of the Giving Society
     * @return The inserted Giving Society record
     */
    public static ucinn_ascendv2__Giving_Society__c makeGivingSociety(String name) {
        ucinn_ascendv2__Giving_Society__c society = new ucinn_ascendv2__Giving_Society__c(
            Name = name
        );
        insert society;
        return society;
    }

    /**
     * @description Creates a test Society Membership record with default values
     * @param contactId The ID of the related Contact
     * @param givingSocietyId The ID of the related Giving Society
     * @return The inserted Society Membership record
     */
    public static ucinn_ascendv2__Society_Membership__c makeSocietyMembership(Id contactId, Id givingSocietyId) {
        ucinn_ascendv2__Society_Membership__c membership = new ucinn_ascendv2__Society_Membership__c(
            ucinn_ascendv2__Contact__c = contactId,
            ucinn_ascendv2__Giving_Society__c = givingSocietyId,
            ucinn_ascendv2__Member_Since__c = Date.today().addYears(-1),
            ucinn_ascendv2__Anniversary_Date__c = Date.today().addMonths(6),
            ucinn_ascendv2__Expiration_Date__c = Date.today().addYears(1),
            HAM_JBA_Anonymous__c = false,
            HAM_Will_Provision__c = false,
            HAM_Planned_Gift__c = false,
            HAM_Documented__c = false,
            HAM_Unknown__c = false
        );
        insert membership;
        return membership;
    }

    /**
     * @description Creates multiple test Society Membership records for a contact
     * @param contactId The ID of the related Contact
     * @param count The number of society membership records to create
     * @return List of inserted Society Membership records
     */
    public static List<ucinn_ascendv2__Society_Membership__c> makeSocietyMemberships(Id contactId, Integer count) {
        List<ucinn_ascendv2__Society_Membership__c> memberships = new List<ucinn_ascendv2__Society_Membership__c>();

        for (Integer i = 0; i < count; i++) {
            ucinn_ascendv2__Giving_Society__c society = makeGivingSociety('Test Society ' + i + '_' + System.now().getTime());
            memberships.add(new ucinn_ascendv2__Society_Membership__c(
                ucinn_ascendv2__Contact__c = contactId,
                ucinn_ascendv2__Giving_Society__c = society.Id,
                ucinn_ascendv2__Member_Since__c = Date.today().addYears(-i - 1),
                ucinn_ascendv2__Anniversary_Date__c = Date.today().addMonths(i),
                ucinn_ascendv2__Expiration_Date__c = Date.today().addYears(1),
                HAM_JBA_Anonymous__c = Math.mod(i, 2) == 0,
                HAM_Will_Provision__c = Math.mod(i, 3) == 0,
                HAM_Planned_Gift__c = Math.mod(i, 2) == 1,
                HAM_Documented__c = Math.mod(i, 3) == 1,
                HAM_Unknown__c = Math.mod(i, 3) == 2,
                ucinn_ascendv2__Comments__c = 'Test membership ' + i
            ));
        }
        insert memberships;
        return memberships;
    }

    //#HAMJediEventControllerTest
    // ---- CventEvents Event builders ----
    /**
     * @description Creates a test CventEvents Event record with all required fields
     * @param title The title of the event
     * @return The inserted CventEvents Event record
     */
    public static CventEvents__Event__c makeCventEvent(String title) {
        CventEvents__Event__c evt = new CventEvents__Event__c(
            CventEvents__pkg_Title__c       = title,
            CventEvents__pkg_Code__c        = 'CODE-' + System.now().getTime(),
            CventEvents__pkg_Category__c    = 'Other',
            CventEvents__pkg_EventStub__c   = String.valueOf(System.now().getTime()).right(36),
            CventEvents__pkg_EventStatus__c = 'Upcoming',
            CventEvents__pkg_Status__c      = 'Active',
            CventEvents__pkg_EndDate__c     = Date.today().addDays(30)
        );
        insert evt;
        return evt;
    }
 
    // ---- CventEvents Attendee builders ----
    /**
     * @description Creates a test CventEvents Attendee record with default values
     * @param contactId The ID of the related Contact
     * @return The inserted Attendee record
     */
    public static CventEvents__Attendee__c makeAttendee(Id contactId) {
        CventEvents__Event__c evt = makeCventEvent('Test Event ' + System.now().getTime());
        return makeAttendee(contactId, evt.Id, 'Accepted');
    }
 
    /**
     * @description Creates a test CventEvents Attendee record with a specific status
     * @param contactId The ID of the related Contact
     * @param eventId The ID of the related CventEvents Event
     * @param status The CventEvents__Status__c value
     * @return The inserted Attendee record
     */
    public static CventEvents__Attendee__c makeAttendee(Id contactId, Id eventId, String status) {
        String resolvedStatus = pickValue('CventEvents__Attendee__c', 'CventEvents__Status__c', status, 'Accepted');
        CventEvents__Attendee__c attendee = new CventEvents__Attendee__c(
            CventEvents__Contact__c = contactId,
            CventEvents__Event__c   = eventId,
            CventEvents__Status__c  = resolvedStatus
        );
        insert attendee;
        return attendee;
    }
 
    /**
     * @description Creates multiple test CventEvents Attendee records, each with its own Event
     * @param contactId The ID of the related Contact
     * @param count The number of attendee records to create
     * @return List of inserted Attendee records
     */
    public static List<CventEvents__Attendee__c> makeAttendees(Id contactId, Integer count) {
        String resolvedStatus = pickValue('CventEvents__Attendee__c', 'CventEvents__Status__c', 'Accepted', 'Accepted');
        List<CventEvents__Attendee__c> attendees = new List<CventEvents__Attendee__c>();
        for (Integer i = 0; i < count; i++) {
            CventEvents__Event__c evt = makeCventEvent('Test Event ' + i + '_' + System.now().getTime());
            attendees.add(new CventEvents__Attendee__c(
                CventEvents__Contact__c = contactId,
                CventEvents__Event__c   = evt.Id,
                CventEvents__Status__c  = resolvedStatus
            ));
        }
        insert attendees;
        return attendees;
    }
 
    // ---- Dataset seeding methods for Event Controller ----
    /**
     * @description Creates a complete dataset for testing HAMJediEventController
     * @return Map containing 'account', 'contact', 'attendees', and 'emails' keys
     */
    public static Map<String, Object> createEventControllerTestDataset() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id);
 
        List<CventEvents__Attendee__c> attendees = makeAttendees(con.Id, 3);
        List<et4ae5__IndividualEmailResult__c> emails = makeEmailResults(con.Id, 2);
 
        return new Map<String, Object>{
            'account'   => acc,
            'contact'   => con,
            'attendees' => attendees,
            'emails'    => emails
        };
    }

}