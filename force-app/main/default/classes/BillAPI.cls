public with sharing class BillAPI {
  @AuraEnabled(cacheable=true)
  public static List<Bill__c> searchBills(String searchTerm, String accountId) {
    String query = 'SELECT Id, Invoice_Number__c, Balance__c, Account__r.Name FROM Bill__c';
    List<String> conditions = new List<String>();

    if (String.isNotBlank(accountId)) {
      conditions.add('Account__c = :accountId');
    }

    if (String.isNotBlank(searchTerm)) {
      searchTerm = searchTerm.trim();
      String likeSearchTerm = '%' + String.escapeSingleQuotes(searchTerm) + '%';
      conditions.add(
        '(Invoice_Number__c LIKE :likeSearchTerm OR Account__r.Name LIKE :likeSearchTerm OR Balance__c != NULL)'
      );
    }

    if (!conditions.isEmpty()) {
      query += ' WHERE ' + String.join(conditions, ' AND ');
    }

    query += ' ORDER BY CreatedDate DESC';

    System.debug('Query: ' + query);
    List<Bill__c> results = Database.query(query);

    // If searchTerm is not blank, filter results for Balance
    if (String.isNotBlank(searchTerm)) {
      List<Bill__c> filteredResults = new List<Bill__c>();
      for (Bill__c bill : results) {
        if (
          bill.Invoice_Number__c.containsIgnoreCase(searchTerm) ||
          (bill.Account__r.Name != null &&
          bill.Account__r.Name.containsIgnoreCase(searchTerm)) ||
          (bill.Balance__c != null &&
          String.valueOf(bill.Balance__c).containsIgnoreCase(searchTerm))
        ) {
          filteredResults.add(bill);
        }
      }
      results = filteredResults;
    }

    System.debug('Final results count: ' + results.size());
    return results;
  }

  public static void getBills() {
    try {
      HttpRequest request = new HttpRequest();
      request.setEndpoint(
        'callout:Bill_Callout/grizzleevelyn/231017_dev_clicked/db'
      );
      request.setMethod('GET');

      Http httpObject = new Http();
      HttpResponse response = httpObject.send(request);

      if (response.getStatusCode() != 200) {
        throw new CalloutException(
          'HTTP request failed with status code: ' + response.getStatusCode()
        );
      }

      String responseBody = response.getBody();
      Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(
        responseBody
      );
      List<Object> billsList = (List<Object>) jsonResponse.get('bills');

      List<BillWrapper> bwList = new List<BillWrapper>();
      for (Object billObj : billsList) {
        Map<String, Object> billMap = (Map<String, Object>) billObj;
        BillWrapper bill = new BillWrapper();
        bill.billId = (String) billMap.get('billId');
        bill.accountName = (String) billMap.get('accountName');
        bill.balance = (String) billMap.get('balance');
        bwList.add(bill);
      }

      Map<String, Id> accountMap = new Map<String, Id>();
      for (Account acc : [
        SELECT Id, Name
        FROM Account
        WHERE Active__c = 'Yes'
      ]) {
        accountMap.put(acc.Name, acc.Id);
      }

      Set<String> invoiceNumbers = new Set<String>();
      for (BillWrapper bill : bwList) {
        if (accountMap.containsKey(bill.accountName)) {
          invoiceNumbers.add(bill.billId);
        } else {
          System.debug('Account not found for Bill: ' + bill.billId);
        }
      }

      Map<String, Bill__c> existingBillsMap = new Map<String, Bill__c>();
      for (Bill__c bill : [
        SELECT Id, Invoice_Number__c
        FROM Bill__c
        WHERE Invoice_Number__c IN :invoiceNumbers
      ]) {
        existingBillsMap.put(bill.Invoice_Number__c, bill);
      }

      List<Bill__c> billsToUpsert = new List<Bill__c>();
      for (BillWrapper bill : bwList) {
        if (accountMap.containsKey(bill.accountName)) {
          Bill__c newBill = existingBillsMap.containsKey(bill.billId)
            ? existingBillsMap.get(bill.billId)
            : new Bill__c();

          newBill.Invoice_Number__c = bill.billId;
          newBill.Balance__c = Decimal.valueOf(
            bill.balance.replace('$', '').trim()
          );
          newBill.Account__c = accountMap.get(bill.accountName);

          billsToUpsert.add(newBill);
        }
      }

      if (!billsToUpsert.isEmpty()) {
        upsert billsToUpsert Invoice_Number__c;
        System.debug('Upserted Bills: ' + billsToUpsert.size());
      }
    } catch (Exception e) {
      System.debug('Error in getBills: ' + e.getMessage());
      throw new AuraHandledException(
        'Error fetching and upserting bills: ' + e.getMessage()
      );
    }
  }

  public class BillWrapper {
    public String billId;
    public String accountName;
    public String balance;
  }
}
