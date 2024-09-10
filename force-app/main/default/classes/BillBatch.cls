
public with sharing class BillBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
  private Id newBillId;

  public BillBatch(Id billId) {
    this.newBillId = billId;
  }

  public BillBatch() {
    this(null);
  }

  public Database.QueryLocator start(Database.BatchableContext bc) {
    if (newBillId != null) {
      // Query for the specific bill ID provided
      return Database.getQueryLocator(
        [
          SELECT Id, Email__c
          FROM Account
          WHERE Id IN (SELECT Account__c FROM Bill__c WHERE Id = :newBillId)
        ]
      );
    } else {
      // Get the most recent bill and find its related account
      Bill__c recentBill = [
        SELECT Account__c
        FROM Bill__c
        ORDER BY CreatedDate DESC
        LIMIT 1
      ];
      return Database.getQueryLocator(
        [SELECT Id, Email__c FROM Account WHERE Id = :recentBill.Account__c]
      );
    }
  }

  public void execute(Database.BatchableContext bc, List<Account> scope) {
    Map<String, Blob> sendMap = new Map<String, Blob>();

    for (Account acct : scope) {
      // Query for the most recent bill for the account
      List<Bill__c> bills = [
        SELECT Id
        FROM Bill__c
        WHERE Account__c = :acct.Id
        ORDER BY CreatedDate DESC
        LIMIT 1
      ];
      if (!bills.isEmpty()) {
        Id billId = bills[0].Id;

        try {
          PageReference pageRef = new PageReference(
            '/apex/BillVFP?id=' + billId
          );
          Blob pdfBlob = pageRef.getContentAsPDF();
          sendMap.put(acct.Email__c, pdfBlob);
        } catch (Exception e) {
          System.debug(
            'Error generating PDF for bill ' + billId + ': ' + e.getMessage()
          );
        }
      } else {
        System.debug('No recent bill found for Account ' + acct.Id);
      }
    }

    if (!sendMap.isEmpty()) {
      try {
        BillEmailer.sendEmails(sendMap);
      } catch (BillEmailer.BillEmailException e) {
        System.debug('Error sending emails: ' + e.getMessage());
      }
    } else {
      System.debug('No emails to send in this batch');
    }
  }

  public void finish(Database.BatchableContext bc) {
    System.debug('Batch processing finished.');
  }
}
