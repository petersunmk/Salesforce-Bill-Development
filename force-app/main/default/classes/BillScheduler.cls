
public with sharing class BillScheduler implements Schedulable {
  // Regular batch processing without specific bill
  public void execute(SchedulableContext ctx) {
    BillBatch bb = new BillBatch(null);
    Database.executeBatch(bb);
  }

  // Schedule batch with specific new bill ID
  public static void scheduleBatchWithNewBill(Id billId) {
    System.debug('Scheduling BillBatch for billId: ' + billId);
    BillBatch bb = new BillBatch(billId); // Process batch for the specific bill
    Database.executeBatch(bb);
  }
}
