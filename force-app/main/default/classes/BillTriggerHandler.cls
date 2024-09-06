
public with sharing class BillTriggerHandler {
    
    public static void beforeInsert(List<Bill__c> bills) {
        validateAccount(bills);
        populateInvoiceNumber(bills);
    }
    
    public static void afterInsert(List<Bill__c> bills) {
        createOpportunitiesForNewBills(bills);
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
                bill.Invoice_Number__c = 'INV-' + Math.abs(Crypto.getRandomInteger()).toString().substring(0, 8);
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
        
        // Fetch existing open opportunities
        List<Opportunity> openOpportunities = [
            SELECT AccountId 
            FROM Opportunity 
            WHERE AccountId IN :accountIds 
            AND StageName != 'Closed Won' 
            AND StageName != 'Closed Lost'
        ];
        
        // Get a list of account IDs that already have open opportunities
        Set<Id> accountIdsWithOpportunities = new Set<Id>();
        for (Opportunity opp : openOpportunities) {
            accountIdsWithOpportunities.add(opp.AccountId);
        }
        
        // Fetch the accounts
        List<Account> accounts = [
            SELECT Id, Name 
            FROM Account 
            WHERE Id IN :accountIds
        ];
        
        List<Opportunity> opportunitiesToInsert = new List<Opportunity>();
        
        for (Bill__c bill : bills) {
            if (bill.Account__c != null && !accountIdsWithOpportunities.contains(bill.Account__c)) {
                Opportunity newOpportunity = new Opportunity();
                newOpportunity.AccountId = bill.Account__c;
                newOpportunity.Amount = bill.Balance__c;
                
                Account account = null;
                for (Account acc : accounts) {
                    if (acc.Id == bill.Account__c) {
                        account = acc;
                        break;
                    }
                }
                
                String accountName = account != null ? account.Name : 'Unknown Account';
                newOpportunity.Name = accountName + ' - Opportunity ' + bill.Invoice_Number__c;
                
                newOpportunity.StageName = 'Prospecting';
                newOpportunity.CloseDate = Date.today().addMonths(1);
                
                opportunitiesToInsert.add(newOpportunity);
            }
        }
        
        if (!opportunitiesToInsert.isEmpty()) {
            try {
                insert opportunitiesToInsert;
            } catch (DmlException e) {
                System.debug('Error occurred during opportunity insertion: ' + e.getMessage());
            }
        }
    }
    
}
