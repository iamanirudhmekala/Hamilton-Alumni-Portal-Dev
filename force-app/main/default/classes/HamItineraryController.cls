public with sharing class HamItineraryController {
    private static String PRIMARY_CONSTITUENT = 'Primary Constituent';

    public Map<String, List<EventDetail>> outputMap= new Map<String, List<EventDetail>>();
    List<ContactReport> contactReports = new List<ContactReport>();
    String tripDetailId;
    String tripName;

    public HamItineraryController() {
        List<EventDetail> eventDetails = new List<EventDetail>();
        Map<String, String> params = ApexPages.currentPage().getParameters();
        this.tripDetailId = params.get('tripDetailId');

        try {
            HAM_Trip_Details__c tripDetail = [SELECT Id, 
                                                    HAM_Title__c, 
                                                    HAM_Start_Date_Time__c , 
                                                    HAM_End_Date_Time__c 
                                                FROM HAM_Trip_Details__c 
                                                WHERE Id = :tripDetailId 
                                                    LIMIT 1];
                                        
            this.tripName = tripDetail.HAM_Title__c;
        } catch (Exception e) {
            System.debug('ERROR:::' + e.getMessage());
        }

        Map<Id, String> meetingMap = new Map<Id, String>();
        for (Event evt : [
                SELECT Id, 
                    Subject, 
                    Description, 
                    StartDateTime, 
                    HAM_Start_Date_Time__c, 
                    HAM_Source_Airport__c, 
                    HAM_Destination_Airport__c,
                    HAM_Mode__c,
                    HAM_Stay_Name__c,
                    HAM_Address__c,
                    Who.Name,
                    WhoId,
                    RecordType.DeveloperName 
                FROM Event 
                WHERE WhatId = :tripDetailId 
                AND RecordType.DeveloperName IN ('HAM_Meeting', 'HAM_Transportation', 'HAM_Accommodation') 
                    ORDER BY StartDateTime ]) {
            EventDetail edt = buildEventDetail(evt, meetingMap);
            eventDetails.add(edt);
            
        }

        buildOutputMap(eventDetails);

        Map<Id,ucinn_ascendv2__Contact_Report__c> reportMap = new Map<Id,ucinn_ascendv2__Contact_Report__c>();
        for (ucinn_ascendv2__Contact_Report__c contactReport : [
                SELECT ucinn_ascendv2__Contact__c, 
                    ucinn_ascendv2__Contact__r.ucinn_ascendv2__Expanded_Name_Formula__c, 
                    ucinn_ascendv2__Description__c, ucinn_ascendv2__Contact_Report_Body__c 
                FROM ucinn_ascendv2__Contact_Report__c 
                WHERE Trip_Details__c = :tripDetailId]) {
            reportMap.put(contactReport.ucinn_ascendv2__Contact__c, contactReport);
        }

        for (String constituentId : meetingMap.keySet()) {
            if (reportMap.containsKey(constituentId)) {
                this.contactReports.add(new ContactReport(reportMap.get(constituentId).ucinn_ascendv2__Contact__r.ucinn_ascendv2__Expanded_Name_Formula__c, reportMap.get(constituentId).ucinn_ascendv2__Contact_Report_Body__c));
            } else {
                this.contactReports.add(new ContactReport(meetingMap.get(constituentId), '<p>--No report--</p>'));
            }
        }

    }

    private void buildOutputMap(List<EventDetail> eventDetails) {
        for (EventDetail ed : eventDetails) {
            if (this.outputMap.containsKey(ed.eventDate)) {
                this.outputMap.get(ed.eventDate).add(ed);
            } else {
                this.outputMap.put(ed.eventDate, new EventDetail[]{ed});
            }
        }
    }

    private EventDetail buildEventDetail(Event evt, Map<Id, String> meetingMap) {
        EventDetail edt = new EventDetail(evt.Subject, evt.StartDateTime.format('MMMM d'), evt.StartDateTime.format('h:mm a'), evt.Description);
        populateEventDetailDescription(edt, evt, meetingMap);
        return edt;
    }

    private void populateEventDetailDescription(EventDetail edt, Event evt, Map<Id, String> meetingMap) {
        if (evt.RecordType.DeveloperName == 'HAM_Meeting') {
            edt.description = String.format('<td style="width:70px;">{0}</td><td style="padding-left: 30px;">{1} <strong>{2}</strong></td>', 
                new List<Object>{
                    edt.eventTime, 
                    'Meeting with', 
                    evt.Who.Name
                });
            meetingMap.put(evt.WhoId, evt.Who.Name);

        } else if (evt.RecordType.DeveloperName == 'HAM_Transportation') {
            edt.description = String.format('<td style="width: 70px;">{0}</td>' + '<td style="padding-left: 30px;">' 
                    + (String.isBlank(evt.HAM_Source_Airport__c) ? '{1}{2} to {3}' :'{1} {2} to {3}')+'</td>', 
                new List<Object>{
                    edt.eventTime, 
                    String.isBlank(evt.HAM_Source_Airport__c) ? '' : evt.HAM_Source_Airport__c, 
                    evt.HAM_Mode__c, 
                    evt.HAM_Destination_Airport__c
                });

        } else if (evt.RecordType.DeveloperName == 'HAM_Accommodation') {
            edt.description = String.format('<td colspan="2" style="padding-top: 20px; width: 70px;">Overnight {0}</td>', new List<Object>{evt.HAM_Stay_Name__c});
        }
    }

    @AuraEnabled(cacheable=true)
    public static string getBaseUrl(){
        return URL.getOrgDomainUrl().toExternalForm();
    }

    @AuraEnabled(cacheable=true)
    public static List<Event> getStays(String tripDetailId){
        if (String.isBlank(tripDetailId)) {
            return new List<Event>();
        }

        List<Event> stays = [SELECT Id, Subject, 
                    Description, 
                    StartDateTime, 
                    HAM_Start_Date_Time__c, 
                    HAM_Source_Airport__c, 
                    HAM_Destination_Airport__c,
                    HAM_Mode__c,
                    HAM_Stay_Name__c,
                    HAM_Address__c,
                    Who.Name, 
                    RecordType.DeveloperName  
                FROM Event 
                WHERE WhatId = :tripDetailId
                AND RecordType.DeveloperName = 'HAM_Accommodation'];
        
        return stays;
    }

    @AuraEnabled(cacheable=true)
    public static List<Event> getEvents(String tripDetailId){
        if (String.isBlank(tripDetailId)) {
            return new List<Event>();
        }

        List<Event> events = [SELECT 
                    Id, 
                    Subject, 
                    Description, 
                    WhatId,
                    StartDateTime, 
                    EndDateTime,
                    Who.Name, 
                    RecordType.DeveloperName,
                    HAM_Meeting_Title__c,
                    HAM_Meeting_Status__c,
                    HAM_Start_Date_Time__c, 
                    HAM_Source_Airport__c, 
                    HAM_Destination_Airport__c,
                    HAM_Flight_Train_Number__c,
                    HAM_Mode__c,
                    HAM_Stay_Name__c,
                    HAM_Address__c,
                    HAM_Contact_Report__c 
                FROM Event 
                WHERE (WhatId = :tripDetailId OR HAM_Trip_Details__c = :tripDetailId)
                AND RecordType.DeveloperName IN ('HAM_Accommodation' , 'HAM_Meeting', 'HAM_Transportation')
                    ORDER BY StartDateTime];

        Map<String, Event> eventMap = new Map<String, Event>();
        for (Event evt : events) {
            eventMap.put(
                evt.RecordType.DeveloperName + evt.Who.Name + evt.WhatId + evt.StartDateTime.format('dMMYYYYhmm') + evt.EndDateTime.format('dMMYYYYhmm'), evt
            );
        }
            
        
        return eventMap.values();
    }


    @AuraEnabled(cacheable=true)
    public static List<EventDetail> getEventsByUser(){
        String userId = UserInfo.getUserId();

        Datetime now = Datetime.now();
        Datetime thirtyDaysFromNow = now.addDays(30);

        List<Event> events = [SELECT 
                    Id, 
                    Subject, 
                    Description, 
                    WhatId,
                    StartDateTime, 
                    EndDateTime,
                    Who.Name, 
                    RecordType.DeveloperName,
                    HAM_Meeting_Title__c,
                    HAM_Meeting_Status__c,
                    HAM_Start_Date_Time__c, 
                    HAM_Source_Airport__c, 
                    HAM_Destination_Airport__c,
                    HAM_Flight_Train_Number__c,
                    HAM_Mode__c,
                    HAM_Stay_Name__c,
                    HAM_Address__c,
                    HAM_Trip_Details__c,
                    HAM_Trip_Details__r.HAM_Title__c,
                    HAM_Trip_Details__r.HAM_Start_Date_Time__c,
                    HAM_Trip_Details__r.HAM_End_Date_Time__c
                FROM Event 
                WHERE OwnerId = :userId
                AND HAM_Trip_Details__c != null
                AND HAM_Trip_Details__r.HAM_Start_Date_Time__c >= :now
                AND HAM_Trip_Details__r.HAM_Start_Date_Time__c <= :thirtyDaysFromNow
                AND RecordType.DeveloperName IN ('HAM_Meeting')
                    ORDER BY StartDateTime];

        List<EventDetail> eventDetails = new List<EventDetail>();

        for (Event evt : events) {
            if (evt.HAM_Trip_Details__r.HAM_Start_Date_Time__c == null || evt.HAM_Trip_Details__r.HAM_End_Date_Time__c == null) continue;
            
            EventDetail ed = new EventDetail();
            ed.tripId = evt.WhatId;
            ed.tripTitle = evt.HAM_Trip_Details__r.HAM_Title__c;
            ed.tripStartDateTime = evt.HAM_Trip_Details__r.HAM_Start_Date_Time__c.format('MMMM d, YYYY h:mm a');
            ed.tripEndtDateTime = evt.HAM_Trip_Details__r.HAM_End_Date_Time__c.format('MMMM d, YYYY h:mm a');
            ed.address = evt.HAM_Address__c;
            ed.description = evt.Description;
            eventDetails.add(ed);
        }
        
        return eventDetails; 
    }

    @AuraEnabled
    public static Event saveEvent(EventDetail eventDetail){
        HAM_Trip_Details__c tripDetail = [
            SELECT Id, Name, HAM_Title__c, HAM_Start_Date_Time__c, HAM_End_Date_Time__c 
            FROM HAM_Trip_Details__c
            WHERE Id = :eventDetail.tripDetailId];

        Event event = new Event();
        event.Id = eventDetail.id;
        event.StartDateTime = eventDetail.startDateTime;
        event.EndDateTime = eventDetail.endDateTime;
        event.WhatId = eventDetail.tripDetailId;
        event.HAM_Trip_Details__c = eventDetail.tripDetailId;
        event.RecordTypeId = Schema.SObjectType.Event.getRecordTypeInfosByDeveloperName().get(eventDetail.type).getRecordTypeId();

        if (eventDetail.type == 'HAM_Accommodation') {
            buildStayEvent(eventDetail, event);
        }

        if (eventDetail.type == 'HAM_Meeting') {
            buildMeetingEvent(eventDetail, event, tripDetail);
            System.debug('@@subject:: ' + event.Subject);
        }

        if (eventDetail.type == 'HAM_Transportation') {
            buildTranspoEvent(eventDetail, event);
        }

        upsert event;

        createEventRelations(eventDetail, event);

        return event;
    }

    private static void buildStayEvent(EventDetail eventDetail, Event event) {
        event.Subject = String.format('{0} Stay Detail', new List<String>{eventDetail.stayDetailsName});
        event.HAM_Stay_Name__c = eventDetail.stayDetailsName;
        event.HAM_Address__c = eventDetail.address;
        event.Location = eventDetail.address;
    }

    private static void buildMeetingEvent(EventDetail eventDetail, Event event, HAM_Trip_Details__c tripDetail) {
        event.HAM_Meeting_Title__c = eventDetail.meetingTitle;
        event.Subject = String.format('Meeting with {0} for Trip: {1}', new List<String>{UserInfo.getName(), tripDetail.HAM_Title__c});
        event.HAM_Meeting_Status__c = eventDetail.meetingStatus;
        event.WhoId = eventDetail.contactId;
        event.HAM_Address__c = eventDetail.address;
        event.Description = eventDetail.description;
        if (eventDetail.id == null) { // only create contact report if it's a new event
            event.HAM_Contact_Report__c = createContactReport(eventDetail);
        } else {
            if (eventDetail.contactReport == null) {
                event.HAM_Contact_Report__c = createContactReport(eventDetail);
            } else {
                event.HAM_Contact_Report__c = eventDetail.contactReport;
            }
        }
    }

    private static void buildTranspoEvent(EventDetail eventDetail, Event event) {
        event.Subject = String.format('{0} Transportation', new List<String>{eventDetail.mode});
        event.HAM_Mode__c = eventDetail.mode;
        event.HAM_Flight_Train_Number__c = eventDetail.flightOrTrainNumber;
        event.HAM_Source_Airport__c = eventDetail.sourceAirport;
        event.HAM_Destination_Airport__c = eventDetail.destinationAirport;
    }

    private static void createEventRelations(EventDetail eventDetail, Event event) {
        if (eventDetail.type == 'HAM_Meeting') {
            Map<String, EventRelation> eventRelations = new Map<String, EventRelation>();
            Id eventOwnerId = [SELECT Id, OwnerId FROM Event WHERE Id = :event.Id LIMIT 1].OwnerId;

            saveAttendees(event, eventDetail, eventOwnerId, eventRelations);

            if (eventDetail.Id == null) {
                createEventRelation(event.Id, eventDetail.contactId, eventOwnerId, eventRelations);
                createEventRelation(event.Id, UserInfo.getUserId(), eventOwnerId, eventRelations);
            }

            System.debug('@@eventRelations: ' + eventRelations.values());
            
            Database.SaveResult[] srList = Database.insert(eventRelations.values(), false);
            for (Database.SaveResult sr : srList) {
                if (!sr.isSuccess()) {
                    for(Database.Error err : sr.getErrors()) {
                        System.debug('The following error has occurred.');
                        System.debug(err.getStatusCode() + ': ' + err.getMessage());
                        System.debug('EventRelation fields that affected this error: ' + err.getFields());
                    }
                }
            }
        }
    }

    private static Id createContactReport(EventDetail eventDetail) {
        ucinn_ascendv2__Contact_Report__c contactReport = new ucinn_ascendv2__Contact_Report__c();
        contactReport.Trip_Details__c = eventDetail.tripDetailId;
        contactReport.ucinn_ascendv2__Date__c = Date.today();
        contactReport.ucinn_ascendv2__Description__c = eventDetail.description;
        contactReport.ucinn_ascendv2__Contact_Report_Body__c = '<p>' + eventDetail.description + '</p>';
        contactReport.ucinn_ascendv2__Contact__c = eventDetail.contactId;
        contactReport.ucinn_ascendv2__Account__c = eventDetail.getAccountId();
        insert contactReport;

        createContactReportRelation(eventDetail, contactReport.Id, contactReport.ucinn_ascendv2__Account__c);
        return contactReport.Id;
    }

    private static void createContactReportRelation(EventDetail eventDetail, Id contactReport, Id accountId) {
        ucinn_ascendv2__Contact_Report_Relation__c cpr = new ucinn_ascendv2__Contact_Report_Relation__c();
        cpr.ucinn_ascendv2__Contact_Report__c = contactReport;
        cpr.ucinn_ascendv2__Contact__c = eventDetail.contactId;
        cpr.ucinn_ascendv2__Account__c = accountId;
        cpr.ucinn_ascendv2__Contact_Role__c = PRIMARY_CONSTITUENT;
        insert cpr;
    }

    private static void saveAttendees(Event evt, EventDetail eventDetail, Id eventOwnerId, Map<String, EventRelation> eventRelations) {
        List<Attendee> attendees = eventDetail.attendees;
        Id contactReport = evt.HAM_Contact_Report__c;

        if (attendees == null || attendees.isEmpty()) return;

        List<ucinn_ascendv2__Fundraiser_Contact_Report_Relation__c> cprs = new List<ucinn_ascendv2__Fundraiser_Contact_Report_Relation__c>();
        List<EventRelation> ers = new List<EventRelation>();
        List<Sobject> objs = new List<Sobject>();
        for (Attendee att : attendees) {
            cprs.add(new ucinn_ascendv2__Fundraiser_Contact_Report_Relation__c(
                ucinn_ascendv2__Fundraiser_Role__c = att.fundraiserRole,
                ucinn_ascendv2__Fundraiser__c = att.fundraiser,
                ucinn_ascendv2__Contact_Report__c = contactReport
            ));

            createEventRelation(evt.Id, att.fundraiser, eventOwnerId, eventRelations);

        }

        objs.addAll(cprs);
        objs.addAll(ers);

        insert objs;
    }

    private static void createEventRelation(Id evtId, Id relationId, Id eventOwnerId, Map<String, EventRelation> eventRelations) {
        if (relationId == eventOwnerId) // because of SF limitation: You cannot add the owner of the event as an invitee
            return;

        String objectApiName = relationId.getSObjectType().getDescribe().getName();
        eventRelations.put(evtId + '' + relationId ,new EventRelation(
            EventId = evtId,
            RelationId = relationId,
            // AccountId = eventDetail.getAccountId(), NOT writable
            IsInvitee = objectApiName == 'Contact' ? true : false,
            // IsParent = UserInfo.getUserId() == relationId ? true : false
            IsParent = false
            // IsParent = objectApiName == 'Contact' ? false : UserInfo.getUserId() == relationId ? true : false
        ));
    }

    @AuraEnabled
    public static void deleteAttendee(String attendeeId) {
        delete new ucinn_ascendv2__Fundraiser_Contact_Report_Relation__c(Id = attendeeId);
    }

    @AuraEnabled
    public static void deleteEvent(String eventId){
        try {
            Database.delete(Id.valueOf(eventId));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string sendDigitalTrip(String tripDetailId, String subject, String body){
        String result = '';

        try {
            HAM_Trip_Details__c tripDetail = [SELECT Id, Name, HAM_Title__c FROM HAM_Trip_Details__c WHERE Id = :tripDetailId LIMIT 1];
        
            String fileName = 'Itinerary {0} {1}-{2}-{3}.pdf';
            fileName = String.format(fileName, new List<Object>{tripDetail.HAM_Title__c, rPadDateElem(Date.today().month()), rPadDateElem(Date.today().day()), Date.today().year()});

            PageReference pageRef = Page.hamItineraryPdf;
            pageRef.getParameters().put('tripDetailId', tripDetailId);
            pageRef.setRedirect(true);

            EmailTemplate et = [SELECT Id, Subject, Body FROM EmailTemplate WHERE DeveloperName = 'Digital_Trip_Itinerary'];
            HAM_Itinerary_Email_Setting__c emailSetting = HAM_Itinerary_Email_Setting__c.getInstance();

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTemplateId(et.Id);
            mail.setSubject(String.isBlank(subject.trim()) ? et.Subject : subject);
            mail.setSaveAsActivity(false);
            mail.setToAddresses(filterEmails(emailSetting.Recipient__c));
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] { 
                HamEmailUtil.preparePdfEmailAttachment(
                    fileName, Test.isRunningTest() ? Blob.valueOf('test') : pageRef.getContent()) 
            });

            if (!String.isBlank(body)) {
                mail.setHtmlBody(body);
            }

            if (mail.getToAddresses() != null && !mail.toaddresses.isEmpty()) {
                List<OrgWideEmailAddress> owa = [
                    SELECT Id 
                    FROM OrgWideEmailAddress 
                    WHERE Address = 'hamily@hamilton.edu'];
                if (owa.size() > 0) {
                    mail.setOrgWideEmailAddressId(owa[0].Id);
                }
                if (!Test.isRunningTest()) {
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                    result = 'sent';
                }
            } else {
                result = 'No emails to send to.';
            }
        } catch (QueryException qEx) {
            System.debug('ERROR:::' + qEx.getMessage());
            result = 'No trip detail found.';
        } catch (Exception ex) {
            System.debug('ERROR:::' + ex.getMessage());
            result = 'Error sending email.';
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<String > searchAddress(String searchString){
        List<String> results = new List<String>();
        GeocodingCallout call = new GeocodingCallout();
        GeocodeResponse geoResp = call.getCoordinates(searchString);
        if (geoResp != null) {
            for (GeocodeResponse.results result : geoResp.results) {
                results.add(result.formatted_address);
            }
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getMeetingStatusOptions(){
        Schema.DescribeFieldResult fieldDetail = Event.HAM_Meeting_Status__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldDetail.getPicklistValues();
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (Schema.PicklistEntry entry : picklistValues) {
            // options.put(entry.getValue(), entry.getLabel());
            options.add(new Map<String, String>{
                'value' => entry.getValue(),
                'label' => entry.getLabel()
            });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getInvolvementOptions(List<String> categories) {
        List<Map<String, String>> options = new List<Map<String, String>>{
            new Map<String, String>{
                'value' => null,
                'label' => '--None--'
            }
        };

        for (ucinn_ascendv2__Involvement_Value__c involvementVal: [SELECT Id, HAM_Category__c, ucinn_ascendv2__Code__c , ucinn_ascendv2__Involvement_Description__c 
            FROM ucinn_ascendv2__Involvement_Value__c 
            WHERE ucinn_ascendv2__Type__c = 'Student Involvement' 
            AND HAM_Category__c IN :categories ORDER BY ucinn_ascendv2__Involvement_Description__c]) {
            options.add(
                new Map<String, String>{
                    'value' => involvementVal.Id,
                    'label' => involvementVal.ucinn_ascendv2__Involvement_Description__c
                }
            );

        }

        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List <ucinn_ascendv2__Fundraiser_Contact_Report_Relation__c> getStakeholders(String tripDetailId) {
        List<Id> contactReportIds = new List<Id>();
        for (Event evt : [SELECT Id, HAM_Trip_Details__c, HAM_Contact_Report__c 
            FROM Event 
            WHERE RecordType.DeveloperName = 'HAM_Meeting' 
            AND HAM_Trip_Details__c = :tripDetailId]) {

            contactReportIds.add(evt.HAM_Contact_Report__c);
        }

        List <ucinn_ascendv2__Fundraiser_Contact_Report_Relation__c> reportRelations = new List <ucinn_ascendv2__Fundraiser_Contact_Report_Relation__c>();
        List<ucinn_ascendv2__Contact_Report__c> contactReport = [
            SELECT Id, (SELECT Id, ucinn_ascendv2__Contact_Report__c, ucinn_ascendv2__Fundraiser__r.Name 
                        FROM ucinn_ascendv2__Fundraiser_Contact_Report_Relations__r) 
            FROM ucinn_ascendv2__Contact_Report__c 
            WHERE Id IN :contactReportIds];

        for (ucinn_ascendv2__Contact_Report__c cr : contactReport) {
            if (cr.ucinn_ascendv2__Fundraiser_Contact_Report_Relations__r.size() > 0) {
                reportRelations.addAll(cr.ucinn_ascendv2__Fundraiser_Contact_Report_Relations__r);
            }
        }

        return reportRelations;
    }

    @AuraEnabled(cacheable=true)
    public static List<ucinn_ascendv2__Fundraiser_Contact_Report_Relation__c> getStakeholdersByMeetingId(String meetingId) {
        List<ucinn_ascendv2__Fundraiser_Contact_Report_Relation__c> reportRelations;
        try {
            Event evt = [SELECT Id, HAM_Contact_Report__c, HAM_Trip_Details__r.name FROM Event WHERE Id = :meetingId AND HAM_Contact_Report__c != null];
            reportRelations = [SELECT Id, ucinn_ascendv2__Fundraiser__r.Name, ucinn_ascendv2__Fundraiser__c, ucinn_ascendv2__Fundraiser_Role__c FROM ucinn_ascendv2__Fundraiser_Contact_Report_Relation__c WHERE ucinn_ascendv2__Contact_Report__c = :evt.HAM_Contact_Report__c];
            
        } catch (QueryException qEx) {
        }

        return reportRelations;
    }
    
    private static List<String> filterEmails(String commaDelimitedEmails) {
        List<String> emails = HamEmailUtil.trimCommaDelimitedEmails(commaDelimitedEmails);
        HamEmailUtil.removeEmailConstituents(emails);
        HamEmailUtil.filterEmails(emails);

        return emails;
    }

    private static String rPadDateElem(Integer ele) {
        return String.valueOf(ele).length() == 1 ? String.valueOf(ele).leftPad(2, '0') : String.valueOf(ele);
    }

    public String getTripName() {
        return this.tripName;
    }

    public Map<String, List<EventDetail>> getOutputMap() {
        return this.outputMap;
    }

    public List<ContactReport> getContactReports() {
        return this.contactReports;
    }

    public class EventDetail {
        @AuraEnabled public String id {get; set;}
        public String name {get; set;}
        public String eventDate {get; set;}
        public String eventTime {get; set;}
        @AuraEnabled public String description {get; set;}
        @AuraEnabled public String type {get; set;}
        @AuraEnabled public String stayDetailsName {get; set;}
        @AuraEnabled public String address {get; set;}
        @AuraEnabled public String sourceAirport {get; set;}
        @AuraEnabled public String destinationAirport {get; set;}
        @AuraEnabled public String mode {get; set;}
        @AuraEnabled public Datetime startDateTime {get; set;}
        @AuraEnabled public Datetime endDateTime {get; set;}
        @AuraEnabled public String flightOrTrainNumber {get; set;}
        @AuraEnabled public String tripDetailId {get; set;}
        @AuraEnabled public String meetingTitle {get; set;}
        @AuraEnabled public String meetingStatus {get; set;}
        @AuraEnabled public String contactId {get; set;}

        @AuraEnabled public String tripId {get; set;}
        @AuraEnabled public string tripTitle {get; set;}
        @AuraEnabled public String tripStartDateTime {get; set;}
        @AuraEnabled public String tripEndtDateTime {get; set;}

        @AuraEnabled public String contactReport {get; set;}
        @AuraEnabled public List<Attendee> attendees {get; set;}

        public Id accountId;

        public EventDetail() {}

        public EventDetail(String name, String eventDate, String eventTime, String description) {
            this.name = name;
            this.eventDate = eventDate;
            this.eventTime = eventTime;
            this.description = description;
        }

        public EventDetail(String name, String eventDate, String eventTime, String description, String type) {
            this.name = name;
            this.eventDate = eventDate;
            this.eventTime = eventTime;
            this.description = description;
            this.type = type;
        }

        public Id getAccountId() {
            if (this.accountId == null)
                this.accountId = [SELECT Id, AccountId FROM Contact WHERE Id = :this.contactId LIMIT 1].AccountId;
            return this.accountId;
        }
    }

    public class ContactReport {
        public String name {get; set;}
        public String result {get; set;}

        public ContactReport(String name, String result) {
            this.name = name;
            this.result = result;
        }
    }
}