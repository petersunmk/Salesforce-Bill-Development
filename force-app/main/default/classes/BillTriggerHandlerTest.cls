@isTest
public class BillTriggerHandlerTest {
  @testSetup
  static void setupTestData() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    Bill__c bill1 = new Bill__c(Account__c = acc.Id, Balance__c = 100.0);
    Bill__c bill2 = new Bill__c(Account__c = acc.Id, Balance__c = 200.0);

    insert new List<Bill__c>{ bill1, bill2 };
  }

  @isTest
  static void testCreateOpportunitiesForNewBills() {
    List<Opportunity> opportunities = [SELECT Name, Amount FROM Opportunity];
    System.assertEquals(
      2,
      opportunities.size(),
      'Two opportunities should be created.'
    );

    for (Opportunity opp : opportunities) {
      String expectedNamePrefix = 'Test Account - Opportunity ';
      System.assert(
        opp.Name.startsWith(expectedNamePrefix),
        'Opportunity name format is incorrect.'
      );
      System.assertNotEquals(
        0,
        opp.Amount,
        'Opportunity amount should be set.'
      );
    }
  }

  @isTest
  static void testNoAccountId() {
    Bill__c bill = new Bill__c(Balance__c = 100.0);

    Test.startTest();
    try {
      insert bill;
      System.assert(false, 'Expected DML to fail due to missing Account__c.');
    } catch (DmlException e) {
      System.assert(
        e.getMessage().contains('Account field cannot be blank.'),
        'Expected error message not found.'
      );
    }
    Test.stopTest();
  }
}
