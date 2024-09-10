// trigger BillTrigger on Bill__c(before insert, after insert) {
//   if (Trigger.isBefore & Trigger.isInsert) {
//     BillTriggerHandler.beforeInsert(Trigger.new);
//   }

//   if (Trigger.isAfter & Trigger.isInsert) {
//     BillTriggerHandler.afterInsert(Trigger.new);
//   }
// }
trigger BillTrigger on Bill__c(before insert, after insert) {
  if (Trigger.isBefore && Trigger.isInsert) {
    BillTriggerHandler.beforeInsert(Trigger.new);
  }

  if (Trigger.isAfter && Trigger.isInsert) {
    for (Bill__c bill : Trigger.new) {
      BillScheduler.scheduleBatchWithNewBill(bill.Id); // Pass the new bill's ID to the scheduler
    }
  }
}
