/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : Ham_DirectoryController
 * Author          : <YourName>
 * Created Date    : Jan 5, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Jan 5, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jan 5, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

 /*----DO NOT USE THIS CLASS----*/

public class Ham_DirectoryController {

	@AuraEnabled(cacheable=true)
	public static List <Ham_Directory_Tabset__mdt> getDirectoryTabset () {
		return [SELECT Id,Label,Is_Active__c,Tab_Order__c FROM Ham_Directory_Tabset__mdt WHERE Is_Active__c = true ORDER BY Tab_Order__c ];
	}

}