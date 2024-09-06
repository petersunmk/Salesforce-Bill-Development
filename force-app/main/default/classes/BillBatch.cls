public with sharing class BillBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
  public List<Id> receivesBillByEmail = new List<Id>();

  public Database.QueryLocator start(Database.BatchableContext bc) {
    //this is a method that will query for all accounts that are active and have a value
    //for Bill_By_Email__c (Account.Active__c = \'Yes\' AND Bill_By_Email != null)
    //using the Database.getQueryLocator(String) method. Return the result of this method.
    //Hint: be sure to escape the single quotes surrounding \'Yes\' in your dynamic query!
    //query for the following fields:
    //Id, Bill_By_Email__c

    // Dynamic SOQL query to fetch all active accounts with a Bill_By_Email__c value
    String query = 'SELECT Id, Bill_By_Email__c FROM Account WHERE Active__c = \'Yes\' AND Bill_By_Email__c != null';

    // Use Database.getQueryLocator to execute the query and return the result
    return Database.getQueryLocator(query);
  }

  public void execute(Database.BatchableContext bc, List<Account> scope) {
    //this is a method that will process the queried for records by preparing
    //a list of account Ids (this.receivesBillByEmail) to carry over to the finish method.
    //we will do this by iterating over scope and checking whether Bill_By_Email__c == TRUE.
    //This method will also call our BillAPI.getBills() method.
    // Iterate over the scope to process each Account record
    for (Account acct : scope) {
      // Check if Bill_By_Email__c is TRUE
      if (acct.Bill_By_Email__c == true) {
        // Add the account Id to the receivesBillByEmail list
        receivesBillByEmail.add(acct.Id);
      }
    }

    // Call the BillAPI.getBills() method
    BillAPI.getBills();
  }

  public void finish(Database.BatchableContext bc) {
    //this is the final method of the class, that will be called after all processing in the
    //start and execute methods is complete. We will use this method to send an email to each
    //customer in the receivesBillByEmail list. First, we must query for the recently created bills for
    //each account with the following nested query:
    //[SELECT Id, (SELECT Id FROM Bills__r ORDER BY CreatedDate DESC) FROM Account WHERE Id IN :this.receivesBillByEmail]

    //We will then iterate over the results of this query and associate the Id of the most recent bill (value) with the
    //corresponding Id of the account Id (key) in a Map<Id, Id> that we will call billMap, using the .put(Id, Id)
    //method of the Map class:
    //https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm
    //we will also create a Map<Id, String> called emailMap, where we'll hold the Account Id (key) and account email (value).

    //Next, we are going to prepare to call our BillEmailer.sendEmails(Map<String, Blob> emailsWithBills)
    //method. The String in the map, which we'll call sendMap,will be the Account.Email__c field result, and the Blob
    //will be the PDF attachment we are sending. We will achieve this by iterating over the keyset for
    //billMap, putting the email from the account in the key of the key-value pair, and use the following
    //to generate a PDF for each bill Id in the value of the key-value pair:
    //PageReference pageRef = new PageReference('/apex/BillVFP?id=' + [BILLID]);
    //Blob pdfBlob = pageRef.getContentAsPDF();
    //hint: you'll need to use the .get() method of the Map class a couple of times here.

    //finally, we will call our BillEmailer.sendEmails(sendMap) method. Remember, this method is VOID,
    //so there will be no return value;
    // Query for the most recent bills for accounts in the receivesBillByEmail list
    List<Account> accountsWithBills = [
      SELECT
        Id,
        (SELECT Id FROM Bills__r ORDER BY CreatedDate DESC LIMIT 1),
        Email__c
      FROM Account
      WHERE Id IN :this.receivesBillByEmail
    ];

    // Create maps to hold the bill IDs and account emails
    Map<Id, Id> billMap = new Map<Id, Id>();
    Map<Id, String> emailMap = new Map<Id, String>();

    // Iterate over the accounts and populate the maps
    for (Account acct : accountsWithBills) {
      if (acct.Bills__r != null && !acct.Bills__r.isEmpty()) {
        // Get the most recent bill ID
        Id recentBillId = acct.Bills__r[0].Id;

        // Put the account ID and recent bill ID into billMap
        billMap.put(acct.Id, recentBillId);

        // Put the account ID and email into emailMap
        emailMap.put(acct.Id, acct.Email__c);
      }
    }

    // Prepare the map for sending emails
    Map<String, Blob> sendMap = new Map<String, Blob>();

    // Iterate over the billMap to generate PDFs and prepare the sendMap
    for (Id acctId : billMap.keySet()) {
      // Get the recent bill ID using the account ID
      Id billId = billMap.get(acctId);

      // Get the email address using the account ID
      String email = emailMap.get(acctId);

      // Generate the PDF for the bill
      PageReference pageRef = new PageReference('/apex/BillVFP?id=' + billId);
      Blob pdfBlob = pageRef.getContentAsPDF();

      // Put the email and PDF blob into the sendMap
      sendMap.put(email, pdfBlob);
    }

    // Call the BillEmailer.sendEmails method to send the emails
    BillEmailer.sendEmails(sendMap);
  }
}
