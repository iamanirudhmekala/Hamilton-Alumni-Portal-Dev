public with sharing class HAM_ServiceIndicatorFlagHandler {

    public class FlowInput {
        @InvocableVariable(required=true)
        public Id contactId;

        @InvocableVariable(required=true)
        public String serviceIndicatorValueName;

        @InvocableVariable(required=true)
        public Boolean isActive;
    }

    private static final Map<String, String> SI_TO_FIELD = new Map<String, String>{
        'Do Not Send Athletic Updates'      => 'HAM_Send_Athletic_Updates__c',
        'Do Not Send College Updates'       => 'HAM_Send_College_Updates__c',
        'Do Not Send Event Invitations'     => 'HAM_Send_Event_Invitations__c',
        'Do Not Send Hamilton Headlines'    => 'HAM_Send_Hamilton_Headlines__c',
        'Do Not Send Virtual Events Digest' => 'HAM_Send_Virtual_Events_Digest__c',
        'Do Not Sent Impact Report'         => 'HAM_Send_Impact_Report__c',
        'No Hamilton Calendar'              => 'HAM_Hamilton_Calendar__c'
    };

    @InvocableMethod(label='Update Contact Marketing Preference Flag' category='Contact')
    public static void updateFlags(List<FlowInput> inputs) {
        Map<Id, Contact> contactsToUpdate = new Map<Id, Contact>();

        for (FlowInput input : inputs) {
            if (input.contactId == null) {
                continue;
            }
            String fieldName = SI_TO_FIELD.get(input.serviceIndicatorValueName);
            if (fieldName == null) {
                continue;
            }

            Contact c = contactsToUpdate.containsKey(input.contactId)
                ? contactsToUpdate.get(input.contactId)
                : new Contact(Id = input.contactId);

            // Active SI = "Do Not" flag is on → uncheck the send flag
            c.put(fieldName, !input.isActive);
            contactsToUpdate.put(input.contactId, c);
        }

        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate.values();
        }
    }
}