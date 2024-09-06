import { LightningElement, api, wire } from "lwc";
import searchBills from "@salesforce/apex/BillAPI.searchBills";

export default class BillList extends LightningElement {
  @api recordId;
  bills = [];
  error;
  searchTerm = "";

  connectedCallback() {
    this.loadBills();
  }

  @wire(searchBills, {
    searchTerm: "$searchTerm",
    accountId: "$effectiveAccountId"
  })
  wiredBills({ error, data }) {
    if (data) {
      this.bills = data.map((bill) => ({
        ...bill,
        formattedBalance: this.formatBalance(bill.Balance__c)
      }));
      this.error = undefined;
      console.log("Bills retrieved:", this.bills.length);
    } else if (error) {
      this.error = error;
      this.bills = [];
      console.error("Error retrieving bills:", error);
    }
  }

  formatBalance(balance) {
    if (balance == null) return "";
    return `$${balance.toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ",")}`;
  }

  handleSearchChange(event) {
    this.searchTerm = event.target.value;
  }

  loadBills() {
    this.searchTerm = this.searchTerm ? this.searchTerm + " " : " ";
  }

  get hasResults() {
    return this.bills.length > 0;
  }

  get isOnAccountPage() {
    return !!this.recordId;
  }

  get pageTitle() {
    return this.isOnAccountPage ? "Account Bills" : "All Bills";
  }

  get effectiveAccountId() {
    return this.pageTitle === "All Bills" ? null : this.recordId;
  }
}
