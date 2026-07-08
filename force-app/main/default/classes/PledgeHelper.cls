public without sharing class PledgeHelper {
    public static List<HamGivingController.PledgeWrapper> getPledges(String contactId){
        List<HamGivingController.PledgeWrapper> pledgeList = new List<HamGivingController.PledgeWrapper>();
        List<Opportunity> pledges = [
            SELECT Id, ucinn_ascendv2__Remaining_Amount_Due_Formula__c, 
                ucinn_ascendv2__Amount_Paid_to_Date_Roll_Up__c, 
                Amount, 
                ucinn_ascendv2__Designation__r.ucinn_ascendv2__G_L_Effective_Date__c, 
                ucinn_ascendv2__Designation__r.ucinn_ascendv2__Designation_Name__c
            FROM Opportunity
            WHERE StageName != 'Written Off'
            AND StageName != 'Paid'
            AND RecordType.DeveloperName = 'Pledge'
            AND Type != 'Payroll'
            AND Type != 'Revocable Bequest Pledge'
            AND Type != 'PGBEQ (Revocable Bequest)'
            AND ucinn_ascendv2__Designation__c != null
            AND ucinn_ascendv2__Contact__c = :contactId
        ];

        for (Opportunity pledge : pledges) {
            pledgeList.add(new HamGivingController.PledgeWrapper(pledge));
        }
        return pledgeList;
    }
}