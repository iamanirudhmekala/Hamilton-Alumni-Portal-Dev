trigger HAMGroupNotificationTrigger on HAM_Group_Notification__e(after insert) {
	HAM_GroupNotificationHandler.processNotifications(Trigger.new);
}