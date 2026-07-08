trigger ContentDocumentLinkTrigger on ContentDocumentLink (before insert) {
    HAM_ContentDocumentLinkHandler.handleBeforeInsert(Trigger.new);
}