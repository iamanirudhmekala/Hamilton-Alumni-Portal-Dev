public with sharing class HAM_ReceiptPDFQueueable
    implements Queueable, Database.AllowsCallouts {

    private List<Id> receiptIds;

    @TestVisible
    private static Map<String, ReceiptPageWrapper> testMappingOverride;

    public HAM_ReceiptPDFQueueable(List<Id> ids) {
        this.receiptIds = ids;
    }

    public void execute(QueueableContext context) {

        Map<String, ReceiptPageWrapper> typeToPages =
            loadMetadataMapping();

        List<Receipt__c> receipts = [
            SELECT Id, Name, Receipt_Date__c, HAM_Receipt_Type__c
            FROM Receipt__c
            WHERE Id IN :receiptIds
            AND HAM_Is_Processed__c = FALSE
        ];

        for(Receipt__c receipt :receipts){
            receipt.Receipt_Date__c = date.today();
        }
        system.debug('selectedReceipts------'+receipts);
        List<Database.SaveResult> results = Database.update(receipts, false);
        System.debug('results-------->'+results);

        if (receipts.isEmpty()) {
            return;
        }

        List<ContentVersion> versionsToInsert =
            new List<ContentVersion>();

        List<Receipt_PDF_Error__c> errors =
            new List<Receipt_PDF_Error__c>();

        Map<Id, List<ContentVersion>> receiptToVersions =
            new Map<Id, List<ContentVersion>>();

        for (Receipt__c receipt : receipts) {

            try {

                ReceiptPageWrapper pages =
                    typeToPages.get(receipt.HAM_Receipt_Type__c);

                if (pages == null) {
                    continue;
                }

                if (!String.isBlank(pages.brandedPage)) {

                    ContentVersion brandedVersion =
                        generatePdf(
                            receipt,
                            pages.brandedPage,
                            true
                        );

                    versionsToInsert.add(brandedVersion);

                    addToReceiptMap(
                        receiptToVersions,
                        receipt.Id,
                        brandedVersion
                    );
                }

                if (!String.isBlank(pages.unbrandedPage)) {

                    ContentVersion unbrandedVersion =
                        generatePdf(
                            receipt,
                            pages.unbrandedPage,
                            false
                        );

                    versionsToInsert.add(unbrandedVersion);

                    addToReceiptMap(
                        receiptToVersions,
                        receipt.Id,
                        unbrandedVersion
                    );
                }

            } catch (Exception e) {

                errors.add(
                    new Receipt_PDF_Error__c(
                        Receipt__c = receipt.Id,
                        Error_Message__c = e.getMessage()
                    )
                );
            }
        }

        if (!versionsToInsert.isEmpty()) {
            insert versionsToInsert;
            linkFiles(receiptToVersions);
        }

        if (!errors.isEmpty()) {
            insert errors;
        }

        markReceiptsAsGenerated(receipts);
    }

    // ---------------------------------------------
    // PDF Generator
    // ---------------------------------------------

   private static ContentVersion generatePdf(
        Receipt__c receipt,
        String pageName,
        Boolean isBranded
    ) {

        Blob pdfBlob;

        if (Test.isRunningTest()) {
            pdfBlob = Blob.valueOf('Test PDF Content');
        } else {
            PageReference pageRef =
                new PageReference('/apex/' + pageName);

            pageRef.getParameters().put(
                'id',
                receipt.Id
            );

            pdfBlob = pageRef.getContentAsPDF();
        }

        String baseName = 'Receipt_' + receipt.Name;
        String suffix = isBranded
            ? '_DigitalCopy'
            : '_Unbranded';

        return new ContentVersion(
            Title = baseName + suffix,
            PathOnClient = baseName + suffix + '.pdf',
            VersionData = pdfBlob
        );
    }

    // ---------------------------------------------
    // Metadata Loader
    // ---------------------------------------------

    private static Map<String, ReceiptPageWrapper>
        loadMetadataMapping() {

        if (Test.isRunningTest()
            && testMappingOverride != null) {
            return testMappingOverride;
        }

        Map<String, ReceiptPageWrapper> mapping =
            new Map<String, ReceiptPageWrapper>();

        for (Receipt_PDF_Mapping__mdt m : [
            SELECT Receipt_Type__c,
                   VF_Page_Name__c,
                   VF_Page_Branded__c,
                   Is_Active__c
            FROM Receipt_PDF_Mapping__mdt
            WHERE Is_Active__c = TRUE
        ]) {

            mapping.put(
                m.Receipt_Type__c,
                new ReceiptPageWrapper(
                    m.VF_Page_Branded__c,
                    m.VF_Page_Name__c
                )
            );
        }

        return mapping;
    }

    // ---------------------------------------------
    // File Linking
    // ---------------------------------------------

    private static void linkFiles(
        Map<Id, List<ContentVersion>> receiptToVersions
    ) {

        Set<Id> versionIds = new Set<Id>();

        for (List<ContentVersion> listCV :
            receiptToVersions.values()) {

            for (ContentVersion cv : listCV) {
                versionIds.add(cv.Id);
            }
        }

        Map<Id, Id> versionToDocId =
            new Map<Id, Id>();

        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :versionIds
        ]) {
            versionToDocId.put(
                cv.Id,
                cv.ContentDocumentId
            );
        }

        List<ContentDocumentLink> links =
            new List<ContentDocumentLink>();

        for (Id receiptId :
            receiptToVersions.keySet()) {

            for (ContentVersion cv :
                receiptToVersions.get(receiptId)) {

                links.add(
                    new ContentDocumentLink(
                        ContentDocumentId =
                            versionToDocId.get(cv.Id),
                        LinkedEntityId = receiptId,
                        ShareType = 'V'
                    )
                );
            }
        }

        if (!links.isEmpty()) {
            insert links;
        }
    }

    // ---------------------------------------------
    // Helpers
    // ---------------------------------------------

    private static void addToReceiptMap(
        Map<Id, List<ContentVersion>> mapRef,
        Id receiptId,
        ContentVersion version
    ) {

        if (!mapRef.containsKey(receiptId)) {
            mapRef.put(
                receiptId,
                new List<ContentVersion>()
            );
        }

        mapRef.get(receiptId).add(version);
    }

    private static void markReceiptsAsGenerated(
        List<Receipt__c> receipts
    ) {
        for (Receipt__c r : receipts) {
            r.HAM_Is_Processed__c = true;
        }
        update receipts;
    }

    // ---------------------------------------------
    // Wrapper (PUBLIC STATIC)
    // ---------------------------------------------

    public class ReceiptPageWrapper {

        public String brandedPage;
        public String unbrandedPage;

        public ReceiptPageWrapper(
            String branded,
            String unbranded
        ) {
            this.brandedPage = branded;
            this.unbrandedPage = unbranded;
        }
    }
}