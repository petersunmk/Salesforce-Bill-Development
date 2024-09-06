trigger BillTrigger on Bill__c(before insert, after insert) {
  if (Trigger.isBefore & Trigger.isInsert) {
    BillTriggerHandler.beforeInsert(Trigger.new);
  }

  if (Trigger.isAfter & Trigger.isInsert) {
    BillTriggerHandler.afterInsert(Trigger.new);
  }
}
