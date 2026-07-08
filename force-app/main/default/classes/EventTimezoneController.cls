global class EventTimezoneController {
    global Id eventId { get; set; }
    
    global String getStartTimeET() {
        Event e = [SELECT StartDateTime, OwnerId FROM Event WHERE Id = :eventId LIMIT 1];
        User owner = [SELECT TimeZoneSidKey FROM User WHERE Id = :e.OwnerId LIMIT 1];
        return e.StartDateTime.format('MMM d, yyyy \'at\' h:mm a', owner.TimeZoneSidKey);
    }
    
    global String getEndTimeET() {
        Event e = [SELECT EndDateTime, OwnerId FROM Event WHERE Id = :eventId LIMIT 1];
        User owner = [SELECT TimeZoneSidKey FROM User WHERE Id = :e.OwnerId LIMIT 1];
        return e.EndDateTime.format('MMM d, yyyy \'at\' h:mm a', owner.TimeZoneSidKey);
    }

    global String getWhoNameWithSuffix() {
        Event e = [SELECT WhoId FROM Event WHERE Id = :eventId LIMIT 1];
        if (e.WhoId != null) {
            Contact c = [SELECT HAM_Name_w_Suffix__c FROM Contact WHERE Id = :e.WhoId LIMIT 1];
            return c.HAM_Name_w_Suffix__c != null ? c.HAM_Name_w_Suffix__c : '';
        }
        return '';
    }
}