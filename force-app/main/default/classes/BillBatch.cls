// public with sharing class BillBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
//   public List<Id> receivesBillByEmail = new List<Id>();

//   public Database.QueryLocator start(Database.BatchableContext bc) {
//     //this is a method that will query for all accounts that are active and have a value
//     //for Bill_By_Email__c (Account.Active__c = \'Yes\' AND Bill_By_Email != null)
//     //using the Database.getQueryLocator(String) method. Return the result of this method.
//     //Hint: be sure to escape the single quotes surrounding \'Yes\' in your dynamic query!
//     //query for the following fields:
//     //Id, Bill_By_Email__c

//     // Dynamic SOQL query to fetch all active accounts with a Bill_By_Email__c value
//     String query = 'SELECT Id, Bill_By_Email__c FROM Account WHERE Active__c = \'Yes\' AND Bill_By_Email__c != null';

//     // Use Database.getQueryLocator to execute the query and return the result
//     return Database.getQueryLocator(query);
//   }

//   public void execute(Database.BatchableContext bc, List<Account> scope) {
//     //this is a method that will process the queried for records by preparing
//     //a list of account Ids (this.receivesBillByEmail) to carry over to the finish method.
//     //we will do this by iterating over scope and checking whether Bill_By_Email__c == TRUE.
//     //This method will also call our BillAPI.getBills() method.
//     // Iterate over the scope to process each Account record
//     for (Account acct : scope) {
//       // Check if Bill_By_Email__c is TRUE
//       if (acct.Bill_By_Email__c == true) {
//         // Add the account Id to the receivesBillByEmail list
//         receivesBillByEmail.add(acct.Id);
//       }
//     }

//     // Call the BillAPI.getBills() method
//     BillAPI.getBills();
//   }

//   public void finish(Database.BatchableContext bc) {
//     //this is the final method of the class, that will be called after all processing in the
//     //start and execute methods is complete. We will use this method to send an email to each
//     //customer in the receivesBillByEmail list. First, we must query for the recently created bills for
//     //each account with the following nested query:
//     //[SELECT Id, (SELECT Id FROM Bills__r ORDER BY CreatedDate DESC) FROM Account WHERE Id IN :this.receivesBillByEmail]

//     //We will then iterate over the results of this query and associate the Id of the most recent bill (value) with the
//     //corresponding Id of the account Id (key) in a Map<Id, Id> that we will call billMap, using the .put(Id, Id)
//     //method of the Map class:
//     //https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm
//     //we will also create a Map<Id, String> called emailMap, where we'll hold the Account Id (key) and account email (value).

//     //Next, we are going to prepare to call our BillEmailer.sendEmails(Map<String, Blob> emailsWithBills)
//     //method. The String in the map, which we'll call sendMap,will be the Account.Email__c field result, and the Blob
//     //will be the PDF attachment we are sending. We will achieve this by iterating over the keyset for
//     //billMap, putting the email from the account in the key of the key-value pair, and use the following
//     //to generate a PDF for each bill Id in the value of the key-value pair:
//     //PageReference pageRef = new PageReference('/apex/BillVFP?id=' + [BILLID]);
//     //Blob pdfBlob = pageRef.getContentAsPDF();
//     //hint: you'll need to use the .get() method of the Map class a couple of times here.

//     //finally, we will call our BillEmailer.sendEmails(sendMap) method. Remember, this method is VOID,
//     //so there will be no return value;
//     // Query for the most recent bills for accounts in the receivesBillByEmail list
//     List<Account> accountsWithBills = [
//       SELECT
//         Id,
//         (SELECT Id FROM Bills__r ORDER BY CreatedDate DESC LIMIT 1),
//         Email__c
//       FROM Account
//       WHERE Id IN :this.receivesBillByEmail
//     ];

//     // Create maps to hold the bill IDs and account emails
//     Map<Id, Id> billMap = new Map<Id, Id>();
//     Map<Id, String> emailMap = new Map<Id, String>();

//     // Iterate over the accounts and populate the maps
//     for (Account acct : accountsWithBills) {
//       if (acct.Bills__r != null && !acct.Bills__r.isEmpty()) {
//         // Get the most recent bill ID
//         Id recentBillId = acct.Bills__r[0].Id;

//         // Put the account ID and recent bill ID into billMap
//         billMap.put(acct.Id, recentBillId);

//         // Put the account ID and email into emailMap
//         emailMap.put(acct.Id, acct.Email__c);
//       }
//     }

//     // Prepare the map for sending emails
//     Map<String, Blob> sendMap = new Map<String, Blob>();

//     // Iterate over the billMap to generate PDFs and prepare the sendMap
//     for (Id acctId : billMap.keySet()) {
//       // Get the recent bill ID using the account ID
//       Id billId = billMap.get(acctId);

//       // Get the email address using the account ID
//       String email = emailMap.get(acctId);

//       // Generate the PDF for the bill
//       PageReference pageRef = new PageReference('/apex/BillVFP?id=' + billId);
//       Blob pdfBlob = pageRef.getContentAsPDF();

//       // Put the email and PDF blob into the sendMap
//       sendMap.put(email, pdfBlob);
//     }

//     // Call the BillEmailer.sendEmails method to send the emails
//     BillEmailer.sendEmails(sendMap);
//   }
// }
// public with sharing class BillBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
//   public List<Id> receivesBillByEmail = new List<Id>();
//   private Integer processedBillsCount = 0;
//   private Integer emailsSentCount = 0;
//   private List<String> errors = new List<String>();
//   private Boolean emailLimitReached = false;

//   public Database.QueryLocator start(Database.BatchableContext bc) {
//     String query = 'SELECT Id, Bill_By_Email__c FROM Account WHERE Active__c = \'Yes\' AND Bill_By_Email__c != null';
//     System.debug('BillBatch query: ' + query);
//     return Database.getQueryLocator(query);
//   }

//   public void execute(Database.BatchableContext bc, List<Account> scope) {
//     for (Account acct : scope) {
//       if (acct.Bill_By_Email__c == true) {
//         receivesBillByEmail.add(acct.Id);
//       }
//     }

//     try {
//       BillAPI.getBills();
//     } catch (Exception e) {
//       String errorMsg = 'Error calling BillAPI.getBills(): ' + e.getMessage();
//       System.debug(errorMsg);
//       errors.add(errorMsg);
//     }
//   }

//   public void finish(Database.BatchableContext bc) {
//     if (emailLimitReached) {
//       System.debug(
//         'Email limit was reached in a previous batch. Skipping email sending.'
//       );
//       return;
//     }

//     List<Account> accountsWithBills = [
//       SELECT
//         Id,
//         (SELECT Id FROM Bills__r ORDER BY CreatedDate DESC LIMIT 1),
//         Email__c
//       FROM Account
//       WHERE Id IN :this.receivesBillByEmail
//     ];

//     Map<Id, Id> billMap = new Map<Id, Id>();
//     Map<Id, String> emailMap = new Map<Id, String>();

//     for (Account acct : accountsWithBills) {
//       if (acct.Bills__r != null && !acct.Bills__r.isEmpty()) {
//         Id recentBillId = acct.Bills__r[0].Id;
//         billMap.put(acct.Id, recentBillId);
//         emailMap.put(acct.Id, acct.Email__c);
//       }
//     }

//     Map<String, Blob> sendMap = new Map<String, Blob>();

//     for (Id acctId : billMap.keySet()) {
//       Id billId = billMap.get(acctId);
//       String email = emailMap.get(acctId);

//       if (String.isNotBlank(email)) {
//         try {
//           PageReference pageRef = new PageReference(
//             '/apex/BillVFP?id=' + billId
//           );
//           Blob pdfBlob = pageRef.getContentAsPDF();
//           sendMap.put(email, pdfBlob);
//           processedBillsCount++;
//         } catch (Exception e) {
//           String errorMsg =
//             'Error generating PDF for bill ' +
//             billId +
//             ': ' +
//             e.getMessage();
//           System.debug(errorMsg);
//           errors.add(errorMsg);
//         }
//       } else {
//         String errorMsg = 'No email address found for Account ' + acctId;
//         System.debug(errorMsg);
//         errors.add(errorMsg);
//       }
//     }

//     if (!sendMap.isEmpty()) {
//       try {
//         BillEmailer.sendEmails(sendMap);
//         emailsSentCount += sendMap.size();
//       } catch (BillEmailer.BillEmailException e) {
//         String errorMsg = 'Error sending emails: ' + e.getMessage();
//         System.debug(errorMsg);
//         errors.add(errorMsg);
//         if (
//           e.getMessage().contains('Email limit exceeded') ||
//           e.getMessage().contains('Daily email limit reached')
//         ) {
//           emailLimitReached = true;
//         }
//       } catch (System.EmailException e) {
//         String errorMsg = 'Email limit exceeded: ' + e.getMessage();
//         System.debug(errorMsg);
//         errors.add(errorMsg);
//         emailLimitReached = true;
//       } catch (Exception e) {
//         String errorMsg = 'Unexpected error sending emails: ' + e.getMessage();
//         System.debug(errorMsg);
//         errors.add(errorMsg);
//       }
//     } else {
//       System.debug('No emails to send in this batch');
//     }

//     System.debug(
//       'BillBatch job completed. Total bills processed: ' + processedBillsCount
//     );
//     System.debug('Total emails sent: ' + emailsSentCount);
//     if (emailLimitReached) {
//       System.debug(
//         'Email limit was reached during processing. Some bills may not have been processed.'
//       );
//     }
//     if (!errors.isEmpty()) {
//       System.debug('Errors encountered during processing:');
//       for (String error : errors) {
//         System.debug(error);
//       }
//     }
//   }
// }
// public with sharing class BillBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
//   private Id newBillId;

//   public BillBatch(Id billId) {
//     this.newBillId = billId;
//   }

//   public BillBatch() {
//     this(null);
//   }

//   public Database.QueryLocator start(Database.BatchableContext bc) {
//     if (newBillId != null) {
//       // If a specific bill ID is provided, query for that bill's associated accounts
//       return Database.getQueryLocator(
//         [
//           SELECT Id, Email__c
//           FROM Account
//           WHERE Id IN (SELECT Account__c FROM Bill__c WHERE Id = :newBillId)
//         ]
//       );
//     } else {
//       // Regular batch process: get accounts with recent bills
//       return Database.getQueryLocator(
//         'SELECT Id, Email__c FROM Account WHERE Id IN (SELECT Account__c FROM Bill__c ORDER BY CreatedDate DESC LIMIT 1)'
//       );
//     }
//   }

//   public void execute(Database.BatchableContext bc, List<Account> scope) {
//     Map<String, Blob> sendMap = new Map<String, Blob>();

//     for (Account acct : scope) {
//       // Query for the most recent bill for the account
//       List<Bill__c> bills = [
//         SELECT Id
//         FROM Bill__c
//         WHERE Account__c = :acct.Id
//         ORDER BY CreatedDate DESC
//         LIMIT 1
//       ];
//       if (!bills.isEmpty()) {
//         Id billId = bills[0].Id;

//         try {
//           PageReference pageRef = new PageReference(
//             '/apex/BillVFP?id=' + billId
//           );
//           Blob pdfBlob = pageRef.getContentAsPDF();
//           sendMap.put(acct.Email__c, pdfBlob);
//         } catch (Exception e) {
//           System.debug(
//             'Error generating PDF for bill ' + billId + ': ' + e.getMessage()
//           );
//         }
//       } else {
//         System.debug('No recent bill found for Account ' + acct.Id);
//       }
//     }

//     if (!sendMap.isEmpty()) {
//       try {
//         BillEmailer.sendEmails(sendMap);
//       } catch (BillEmailer.BillEmailException e) {
//         System.debug('Error sending emails: ' + e.getMessage());
//       }
//     } else {
//       System.debug('No emails to send in this batch');
//     }
//   }

//   public void finish(Database.BatchableContext bc) {
//     System.debug('Batch processing finished.');
//   }
// }
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
