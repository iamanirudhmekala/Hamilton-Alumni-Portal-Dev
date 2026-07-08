//
// Scheduler Class for ham_BATCH_GLFeeder
// scripts:
// String cronExp = '0 0 0 * * ?'; 
// System.schedule('Nightly GL Feeder Batch', cronExp, new ham_SCHED_GLFeeder());
// 
public class ham_SCHED_GLFeeder implements Schedulable {
    
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new ham_BATCH_GLFeeder(), 200);
    }
}