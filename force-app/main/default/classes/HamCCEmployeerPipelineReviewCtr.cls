/**
 * @description Controller for Employer Engagement Dashboard. 
 * Aggregates account involvement data into charts and tables.
 */
public with sharing class HamCCEmployeerPipelineReviewCtr {
    
    // Wrapper to hold Chart and Table data
    public class EngagementData {
        @AuraEnabled public List<EmployerChartData> chartData { get; set; }
        @AuraEnabled public Map<String, List<Account>> barData { get; set; }
    }
    
    // Wrapper for specific chart bar visual properties
    public class EmployerChartData {
        @AuraEnabled public Integer id { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Integer value { get; set; }
        @AuraEnabled public String style { get; set; }
    }
     
    @AuraEnabled(cacheable=true)
    public static EngagementData getEmployerEngagementData() {
        EngagementData result = new EngagementData();
        result.chartData = new List<EmployerChartData>();
        result.barData = new Map<String, List<Account>>();
        
        //Set Fiscal Dates
        Integer orgFiscalMonth = [SELECT FiscalYearStartMonth FROM Organization].FiscalYearStartMonth;
        
        Date today = System.today();
        
        // Determine fiscal year start calendar year
        Integer fiscalYearStartYear;
        if (today.month() >= orgFiscalMonth) {
            // We are on or after fiscal start month
            fiscalYearStartYear = today.year();
        } else {
            // We are before fiscal start month
            fiscalYearStartYear = today.year() - 1;
        }
        
        // Fiscal year start and end dates
        Date currentFiscalYearStart = Date.newInstance(fiscalYearStartYear, orgFiscalMonth, 1);
        Date currentFiscalYearEnd   = currentFiscalYearStart.addYears(1).addDays(-1);
        
        // Optional: next fiscal year start
        Date nextFiscalYearStart = currentFiscalYearStart.addYears(1);

		system.debug('Current Fiscal Date ---'+currentFiscalYearStart);
        system.debug('next Fiscal Date ---'+nextFiscalYearStart);
        try {
            // 1. Fetch relevant Involvement Values (Configuration)
            List<ucinn_ascendv2__Involvement_Value__c> involvementValues = [
                SELECT Id FROM ucinn_ascendv2__Involvement_Value__c
                WHERE ucinn_ascendv2__Type__c = 'Volunteer Engagement'
                AND HAM_Category__c = 'Career Center'
            ];
            system.debug('Inv Results --------'+involvementValues);
            
            // If config is missing, return empty structure (chartData will be populated with 0s below if desired, 
            // but usually we return early if configuration is missing). 
            if (involvementValues.isEmpty()) return result;

            // 2. Aggregate Involvements per Account
            List<AggregateResult> aggResults = [
                SELECT ucinn_ascendv2__Account__c accId, COUNT(Id) cnt
                FROM ucinn_ascendv2__Involvement__c
                WHERE ucinn_ascendv2__Involvement_Code__c IN :involvementValues
                AND ucinn_ascendv2__Start_Date__c >=: currentFiscalYearStart 
                AND ucinn_ascendv2__Account__c != null
                GROUP BY ucinn_ascendv2__Account__c
            ];
            
            system.debug('Agg Results --------'+aggResults);

            // 3. Group Accounts by Engagement Level
            Map<String, List<Id>> stageToAccountIds = new Map<String, List<Id>>{
                'Prospect' => new List<Id>(),
                'Engaged' => new List<Id>(),
                'Highly Engaged' => new List<Id>(),
                'Impact' => new List<Id>()
            };
            
            Set<Id> allAccountIds = new Set<Id>();
            Map<Id, Integer> accountToInvolvementCount = new Map<Id, Integer>();

            for (AggregateResult ar : aggResults) {
                Id accountId = (Id) ar.get('accId');
                Integer countVal = (Integer) ar.get('cnt');
                accountToInvolvementCount.put(accountId, countVal);
                system.debug('Map Values---'+accountId+'---'+countVal);
            }
            
            

            for (AggregateResult ar : aggResults) {
                Id accId = (Id)ar.get('accId');
                Integer count = (Integer)accountToInvolvementCount.get(accId);
                allAccountIds.add(accId);

                // Logic from your provided snippet
                if (count == 0) stageToAccountIds.get('Prospect').add(accId);
                else if (count == 1) stageToAccountIds.get('Engaged').add(accId);
                else if (count == 2) stageToAccountIds.get('Highly Engaged').add(accId);
                else if (count >= 3) stageToAccountIds.get('Impact').add(accId);
            }

            Integer totalAccs = allAccountIds.size();
            
            // 4. Fetch Account Details
            // Only query if we have accounts to look up
            Map<Id, Account> accountDetailsMap = new Map<Id, Account>();
            if (totalAccs > 0) {
                accountDetailsMap = new Map<Id, Account>([
                    SELECT Id, Name, ucinn_ascendv2__Donor_ID__c,
                           ucinn_ascendv2__Primary_Contact__c, ucinn_ascendv2__Primary_Contact__r.Name,
                           AccountNumber, Type, Industry
                    FROM Account
                    WHERE Id IN :allAccountIds
                    AND HAM_Is_Career_Center_Org__c = TRUE
                ]);
            }

            // 5. Build Chart Data and Result Map
            Integer index = 1;
            List<String> orderedStages = new List<String>{'Prospect', 'Engaged', 'Highly Engaged', 'Impact'};
            
            Map<String, String> stageColors = new Map<String, String>{
                'Prospect' => 'linear-gradient(135deg, #0066cc 0%, #0099ff 100%)',
                'Engaged' => 'linear-gradient(135deg, #0052a3 0%, #0073e6 100%)',
                'Highly Engaged' => 'linear-gradient(135deg, #003d7a 0%, #0059b3 100%)',
                'Impact' => 'linear-gradient(135deg, #002952 0%, #003d7a 100%)'
            };

            for (String stage : orderedStages) {

                List<Id> idsInStage = stageToAccountIds.get(stage);

                // ============================================================
                // Filter to only count accounts that match Career Center criteria
                // ============================================================
                Integer stageCount = 0;
                if (idsInStage != null) {
                    for (Id accId : idsInStage) {
                        if (accountDetailsMap.containsKey(accId)) {
                            stageCount++;
                        }
                    }
                }

                // Calculate width safely (Avoid Division by Zero if totalAccs is 0)
                Decimal widthPercent = 0;
                if (totalAccs > 0 && stageCount > 0) {
                    widthPercent = (Decimal.valueOf(stageCount) * 100) / totalAccs;
                }
                
                EmployerChartData chartItem = new EmployerChartData();
                chartItem.id = index++;
                chartItem.category = stage;
                chartItem.label = stage;
                if(stage.equalsIgnoreCase('Prospect')){
                    chartItem.value = [SELECT count() FROM Account WHERE Id NOT IN :allAccountIds AND HAM_Is_Career_Center_Org__c = TRUE ];
                    if(chartItem.value <= 5){
                        chartItem.style = 'width: 5%; background: ' + stageColors.get(stage) + ';';
                    }else if(chartItem.value > 100){
                        chartItem.style = 'width:100%; background: ' + stageColors.get(stage) + ';';
                    }else{
                        chartItem.style = 'width:'+ chartItem.value +'%; background: ' + stageColors.get(stage) + ';';
                    }
                }else{
                    chartItem.value = stageCount;
                    if(widthPercent == 0){
                        widthPercent = 5;
                    }else if(widthPercent > 100){
                        widthPercent = 100;
                    }

                    chartItem.style = 'width: ' + widthPercent + '%; background: ' + stageColors.get(stage) + ';';
                }
               
                
                
                result.chartData.add(chartItem);

                // Add detailed accounts to map (or empty list if none)
                List<Account> accountsInStage = new List<Account>();
                if(stage.equalsIgnoreCase('Prospect')){
                    accountsInStage = [SELECT  Id, Name, ucinn_ascendv2__Donor_ID__c, 
                           ucinn_ascendv2__Primary_Contact__c, ucinn_ascendv2__Primary_Contact__r.Name, 
                           AccountNumber, Type, Industry FROM Account WHERE ID NOT IN: allAccountIds AND HAM_Is_Career_Center_Org__c = TRUE Limit 5000];
                }else{
                    if (stageCount > 0 && idsInStage != null) {
                        for (Id accId : idsInStage) {
                            if (accountDetailsMap.containsKey(accId)) {
                                accountsInStage.add(accountDetailsMap.get(accId));
                            }
                        }
                    }
                }
                result.barData.put(stage, accountsInStage);
                
            }

        } catch (Exception e) {
            throw new AuraHandledException('Error loading engagement data: ' + e.getMessage());
        }
        
        return result;
    }
}