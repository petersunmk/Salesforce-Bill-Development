// public with sharing class BillTriggerHandler {
//   public static void beforeInsert(List<Bill__c> bills) {
//     validateAccount(bills);
//     populateInvoiceNumber(bills);
//   }

//   public static void afterInsert(List<Bill__c> bills) {
//     createOpportunitiesForNewBills(bills);

//     // Schedule the batch to send the new bill email
//     for (Bill__c bill : bills) {
//       BillScheduler.scheduleBatchWithNewBill(bill.Id);
//     }
//   }

//   private static void validateAccount(List<Bill__c> bills) {
//     for (Bill__c bill : bills) {
//       if (String.isBlank(bill.Account__c)) {
//         bill.Account__c.addError('Account field cannot be blank.');
//       }
//     }
//   }

//   private static void populateInvoiceNumber(List<Bill__c> bills) {
//     for (Bill__c bill : bills) {
//       if (String.isBlank(bill.Invoice_Number__c)) {
//         bill.Invoice_Number__c =
//           'INV-' +
//           Math.abs(Crypto.getRandomInteger()).toString().substring(0, 8);
//       }
//     }
//   }

//   public static void createOpportunitiesForNewBills(List<Bill__c> bills) {
//     Set<Id> accountIds = new Set<Id>();
//     for (Bill__c bill : bills) {
//       if (bill.Account__c != null) {
//         accountIds.add(bill.Account__c);
//       }
//     }

//     // Fetch existing open opportunities
//     List<Opportunity> openOpportunities = [
//       SELECT AccountId
//       FROM Opportunity
//       WHERE
//         AccountId IN :accountIds
//         AND StageName != 'Closed Won'
//         AND StageName != 'Closed Lost'
//     ];

//     // Get a list of account IDs that already have open opportunities
//     Set<Id> accountIdsWithOpportunities = new Set<Id>();
//     for (Opportunity opp : openOpportunities) {
//       accountIdsWithOpportunities.add(opp.AccountId);
//     }

//     // Fetch the accounts
//     List<Account> accounts = [
//       SELECT Id, Name
//       FROM Account
//       WHERE Id IN :accountIds
//     ];

//     List<Opportunity> opportunitiesToInsert = new List<Opportunity>();

//     for (Bill__c bill : bills) {
//       if (
//         bill.Account__c != null &&
//         !accountIdsWithOpportunities.contains(bill.Account__c)
//       ) {
//         Opportunity newOpportunity = new Opportunity();
//         newOpportunity.AccountId = bill.Account__c;
//         newOpportunity.Amount = bill.Balance__c;

//         Account account = null;
//         for (Account acc : accounts) {
//           if (acc.Id == bill.Account__c) {
//             account = acc;
//             break;
//           }
//         }

//         String accountName = account != null ? account.Name : 'Unknown Account';
//         newOpportunity.Name =
//           accountName +
//           ' - Opportunity ' +
//           bill.Invoice_Number__c;

//         newOpportunity.StageName = 'Prospecting';
//         newOpportunity.CloseDate = Date.today().addMonths(1);

//         opportunitiesToInsert.add(newOpportunity);
//       }
//     }

//     if (!opportunitiesToInsert.isEmpty()) {
//       try {
//         insert opportunitiesToInsert;
//       } catch (DmlException e) {
//         System.debug(
//           'Error occurred during opportunity insertion: ' + e.getMessage()
//         );
//       }
//     }
//   }
// }
public with sharing class BillTriggerHandler {
  public static void beforeInsert(List<Bill__c> bills) {
    validateAccount(bills);
    populateInvoiceNumber(bills);
  }

  public static void afterInsert(List<Bill__c> bills) {
    createOpportunitiesForNewBills(bills);
    sendBillEmails(bills); // New method to handle email sending for new bills
  }

  private static void validateAccount(List<Bill__c> bills) {
    for (Bill__c bill : bills) {
      if (String.isBlank(bill.Account__c)) {
        bill.Account__c.addError('Account field cannot be blank.');
      }
    }
  }

  private static void populateInvoiceNumber(List<Bill__c> bills) {
    for (Bill__c bill : bills) {
      if (String.isBlank(bill.Invoice_Number__c)) {
        bill.Invoice_Number__c =
          'INV-' +
          Math.abs(Crypto.getRandomInteger()).toString().substring(0, 8);
      }
    }
  }

  public static void createOpportunitiesForNewBills(List<Bill__c> bills) {
    Set<Id> accountIds = new Set<Id>();
    for (Bill__c bill : bills) {
      if (bill.Account__c != null) {
        accountIds.add(bill.Account__c);
      }
    }

    List<Opportunity> openOpportunities = [
      SELECT AccountId
      FROM Opportunity
      WHERE
        AccountId IN :accountIds
        AND StageName != 'Closed Won'
        AND StageName != 'Closed Lost'
    ];

    Set<Id> accountIdsWithOpportunities = new Set<Id>();
    for (Opportunity opp : openOpportunities) {
      accountIdsWithOpportunities.add(opp.AccountId);
    }

    List<Account> accounts = [
      SELECT Id, Name
      FROM Account
      WHERE Id IN :accountIds
    ];

    List<Opportunity> opportunitiesToInsert = new List<Opportunity>();

    for (Bill__c bill : bills) {
      if (
        bill.Account__c != null &&
        !accountIdsWithOpportunities.contains(bill.Account__c)
      ) {
        Opportunity newOpportunity = new Opportunity();
        newOpportunity.AccountId = bill.Account__c;
        newOpportunity.Amount = bill.Balance__c;

        // Find the account related to this bill
        Account account = null;
        for (Account acc : accounts) {
          if (acc.Id == bill.Account__c) {
            account = acc;
            break; // Exit the loop once the account is found
          }
        }

        // Set the account name or default to 'Unknown Account'
        String accountName = account != null ? account.Name : 'Unknown Account';
        newOpportunity.Name =
          accountName +
          ' - Opportunity ' +
          bill.Invoice_Number__c;
        newOpportunity.StageName = 'Prospecting';
        newOpportunity.CloseDate = Date.today().addMonths(1);

        opportunitiesToInsert.add(newOpportunity);
      }
    }

    if (!opportunitiesToInsert.isEmpty()) {
      try {
        insert opportunitiesToInsert;
      } catch (DmlException e) {
        System.debug(
          'Error occurred during opportunity insertion: ' + e.getMessage()
        );
      }
    }
  }

  // New method to send emails for the new bills
  private static void sendBillEmails(List<Bill__c> bills) {
    Set<Id> accountIds = new Set<Id>();
    for (Bill__c bill : bills) {
      if (bill.Account__c != null) {
        accountIds.add(bill.Account__c);
      }
    }

    // Query accounts to get Bill_By_Email__c and Email__c
    List<Account> accountsWithBills = [
      SELECT
        Id,
        Bill_By_Email__c,
        Email__c,
        (SELECT Id FROM Bills__r ORDER BY CreatedDate DESC LIMIT 1)
      FROM Account
      WHERE Id IN :accountIds AND Bill_By_Email__c = TRUE
    ];

    Map<Id, String> emailMap = new Map<Id, String>();
    Map<Id, Id> billMap = new Map<Id, Id>();

    for (Account acct : accountsWithBills) {
      if (acct.Bills__r != null && !acct.Bills__r.isEmpty()) {
        billMap.put(acct.Id, acct.Bills__r[0].Id);
        emailMap.put(acct.Id, acct.Email__c);
      }
    }

    // Generate PDFs and send emails
    Map<String, Blob> sendMap = new Map<String, Blob>();
    for (Id acctId : billMap.keySet()) {
      Id billId = billMap.get(acctId);
      String email = emailMap.get(acctId);

      if (String.isNotBlank(email)) {
        try {
          PageReference pageRef = new PageReference(
            '/apex/BillVFP?id=' + billId
          );
          Blob pdfBlob = pageRef.getContentAsPDF();
          sendMap.put(email, pdfBlob);
        } catch (Exception e) {
          System.debug(
            'Error generating PDF for bill ' + billId + ': ' + e.getMessage()
          );
        }
      } else {
        System.debug('No email address found for Account ' + acctId);
      }
    }

    // Send emails if PDFs were generated
    if (!sendMap.isEmpty()) {
      try {
        BillEmailer.sendEmails(sendMap);
      } catch (Exception e) {
        System.debug('Error sending emails: ' + e.getMessage());
      }
    }
  }
}
