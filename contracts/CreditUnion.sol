pragma solidity ^0.4.23;

contract CreditUnion {
    struct Account {
        uint currentBalance;
        uint availableBalance;
        uint startTime; //Timestamp
        uint lastCompoundBlockNumber;
    }
    mapping(address => Account) public members;
    mapping(uint => address) public memberIDs;
    uint public membersCount;

    struct Loan {
        uint beginTime; //Timestamp
        uint loanTime; //Days
        uint amountLoaned;
        bool paid;
    }
    mapping(uint => Loan) public loans;
    uint public loansCount;

    struct Transaction {
        bytes32 category;
        uint amount;
        uint timestamp;
        uint balance;
    }
    mapping(uint => Transaction) public transactions;
    uint public transactionsCount;

    uint public APY; //interest rate earned on deposits
    uint public interestRate; //interest rate paid on loans

    uint public totalBalance;
    uint public dividendsBalance;
    uint public loanPayments;
    uint public dividendPayouts;

    modifier isMember(address sender) {
        require(members[sender].startTime > 0);
        _;
    }

    modifier isNotMember(address sender) {
        require(members[sender].startTime == 0);
        _;
    }

    constructor() public {
        //set initial interest rates
        APY = 5;
        interestRate = 10;
    }

    //should have some kind of DID piece (uPort)
    function createAccount() public isNotMember(msg.sender) {
        membersCount++;
        memberIDs[membersCount] = msg.sender;

        members[msg.sender].currentBalance = 0;
        members[msg.sender].availableBalance = 0;
        members[msg.sender].startTime = now;
        members[msg.sender].lastCompoundBlockNumber = block.number;
        
    }
    
    //msg.value is in wei, needs to be converted to ether on front-end
    function deposit() public isMember(msg.sender) payable {
        members[msg.sender].currentBalance += msg.value;
        members[msg.sender].availableBalance += msg.value;

        addTransaction("Deposit", msg.value, msg.sender);
        totalBalance += msg.value;        
    }
    
    //amount is in wei, needs to be converted to ether on front-end
    function withdraw(uint amount) public isMember(msg.sender) {
        require(amount <= members[msg.sender].availableBalance);
        msg.sender.transfer(amount);
        members[msg.sender].currentBalance -= amount;
        members[msg.sender].availableBalance -= amount;
        
        addTransaction("Withdrawal", amount, msg.sender);   
        totalBalance -= amount;
    }

    //msg.value is in wei, needs to be converted to ether on front-end
    function transfer(address recipient) public isMember(msg.sender) payable {
        require(msg.value <= members[msg.sender].availableBalance);
        recipient.transfer(msg.value);
        members[msg.sender].currentBalance -= msg.value;
        members[msg.sender].availableBalance -= msg.value;

        addTransaction("Transfer", msg.value, msg.sender);  
        totalBalance -= msg.value; 
    }

    //Compound the balance every 2,100,000 blocks (~1 year)
    function checkBalance() public isMember(msg.sender) returns(uint[]) {
        uint lastCompound = members[msg.sender].lastCompoundBlockNumber;
        uint n = block.number - lastCompound;

        if (n >= 2100000) {
            uint interestPayment = members[msg.sender].currentBalance * (1+APY/100)**(n/2100000) - members[msg.sender].currentBalance;
            totalBalance += members[msg.sender].currentBalance + interestPayment;
            members[msg.sender].currentBalance += interestPayment;
            members[msg.sender].availableBalance += interestPayment;
            members[msg.sender].lastCompoundBlockNumber = block.number;
        }

        uint[] memory balances = new uint[](2);
        balances[0] = members[msg.sender].currentBalance;
        balances[1] = members[msg.sender].availableBalance;
        return balances;
    }

    //amountLoaned is in wei, needs to be converted to ether on front-end
    function requestLoan(uint _loanTime, uint _amountLoaned) public isMember(msg.sender) {
        require(_amountLoaned <= members[msg.sender].availableBalance);
        msg.sender.transfer(_amountLoaned);
        members[msg.sender].availableBalance -= _amountLoaned;

        loansCount++;

        loans[loansCount].beginTime = now;
        loans[loansCount].loanTime = _loanTime * 1 days;
        loans[loansCount].amountLoaned = _amountLoaned;
        loans[loansCount].paid = false;

        addTransaction("Loan Issued", _amountLoaned, msg.sender);  
        totalBalance -= _amountLoaned; 
    }

    //msg.value is in wei, needs to be converted to ether on front-end
    function makePayment(uint loanID) public isMember(msg.sender) payable {
        require (msg.value == loans[loanID].amountLoaned * (1+interestRate/100));
        dividendsBalance += msg.value - loans[loanID].amountLoaned;
        members[msg.sender].availableBalance += loans[loanID].amountLoaned;
        loans[loanID].paid = true;

        addTransaction("Loan Repaid", msg.value, msg.sender);  
        totalBalance += msg.value;
        
        loanPayments++;
        if (loanPayments % 20 == 0) {
            payDividends();
        } 
    }

    //should pay dividends every 20 loan payments
    //amount should depend on balance
    function payDividends() internal {
        uint totalBalance = totalBalance;
        uint amount = dividendsBalance / membersCount;
        for(uint i = 1; i <= membersCount; i++) {
            uint shares = members[memberIDs[i]].currentBalance / totalBalance;
            memberIDs[i].transfer(amount * shares);
        }

        dividendsBalance = 0;
        dividendPayouts++;
    }

    function addTransaction(bytes32 _category, uint _amount, address sender) internal {
        transactionsCount++;

        transactions[transactionsCount].category = _category;
        transactions[transactionsCount].amount = _amount;
        transactions[transactionsCount].timestamp = now;
        transactions[transactionsCount].balance = members[sender].currentBalance;
    }
}