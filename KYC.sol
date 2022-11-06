//SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

contract KYC {
    address public admin;

    constructor() {
        admin = msg.sender;
    }

    // Modifier
    modifier onlyAdmin() {
        require(msg.sender == admin, "You are not the admin");
        _;
    }

    modifier authorized(address _bankAddress,  string memory _message) {
        require(msg.sender == _bankAddress, _message);
        _;
    }

    struct Bank {
        string bankName;
        address bankAddress;
        uint256 kycCount;
        bool addCustomer;
        bool privilege;
    }

    // we need to map the customer info with bank address
    struct Customer {
        string custName;
        uint256 custPhone;
        string custData;
        string bankName;
        address bankAddress;
        bool isKycDone;
    }

    mapping(address => Bank) public bankDb;
    address[] public bankArray;

    // we consider phone number as unique
    mapping(uint256 => Customer) public customerDb;

    // Functions

    // 1. Add new Bank
    function addBank(
        string calldata _bankName,
        address _bankAddress
    ) public onlyAdmin {
        // banned is set to false for all banks at first
        bankDb[_bankAddress] = Bank(_bankName, _bankAddress, 0, true, true);
        bankArray.push(_bankAddress); 
    }

    // 2. Add New customer to the bank
    function addCustomer(
        string calldata _custName,
        uint256 _custPhone,
        string calldata _custData,
        string calldata _bankName,
        address _bankAddress
    ) public authorized(_bankAddress, "Intruder suspected") {
        require(bankDb[msg.sender].addCustomer == true, "Bank is temporarily unable to add customer");

        // At first KYC is false for all customers
        customerDb[_custPhone] = Customer(_custName, _custPhone , _custData, _bankName, _bankAddress, false);
    }

    // 3. Check KYC status of existing bank customers
    function kycStatus(uint256 _custPhone) public authorized(customerDb[_custPhone].bankAddress, "Customer do not exist in your bank") view returns (bool) {
        return customerDb[_custPhone].isKycDone;
    }

    // 4. Perform the KYC of the customer and update the status
    function addUpdateKyc(uint256 _custPhone) public authorized(customerDb[_custPhone].bankAddress, "Customer do not exist in your bank") {
        require(bankDb[msg.sender].privilege == true, "Your bank is temporarily banned to perform any KYC");

        customerDb[_custPhone].isKycDone = true;
    }

    // 5. Block bank to add any new customer
    function blockBankToAddCustomer(address _bankAddress) public  onlyAdmin {
        bankDb[_bankAddress].addCustomer = false;
    }

    // 6. Block bank to do KYC of the customers
    function blockBankToKyc(address _bankAddress) public onlyAdmin {
        bankDb[_bankAddress].privilege = false;
    }

    // 7. Allow the bank to add new customers which was banned earlier
    function activateAddCustomer(address _bankAddress) public onlyAdmin {
        bankDb[_bankAddress].addCustomer = true;
    }

    // 8. Allow the bank to perform customer KYC which was banned earlier
    function activateBankKyc(address _bankAddress) public {
        bankDb[_bankAddress].privilege = true;
    }

    function customerInfo(uint256 _custPhone) 
        public 
        authorized(customerDb[_custPhone].bankAddress, "Customer do not exist in your bank") 
        view 
        returns (Customer memory)
    {
        return customerDb[_custPhone];
    }

    // 9. View customer data
    function customerDetails(uint256 _custPhone) 
        public 
        authorized(customerDb[_custPhone].bankAddress, "Customer do not exist in your bank") 
        view 
        returns(string memory) 
    {
        return customerDb[_custPhone].custData;
    }
}
