global class PrepareSandbox implements SandboxPostCopy {
    public PrepareSandbox(){}

    global void runApexClass(SandboxContext context){
        SandboxEmailInvalidationBatch batch = new SandboxEmailInvalidationBatch();
        Id batchJobId = Database.executeBatch(batch);

        System.debug('PrepareSandbox ran. BatchJobID: ' + batchJobId);
    }
}