pragma solidity ^0.4.17;

contract CreditUnion {
    struct Account {
        address memberID;
        uint currentBalance;
        uint availableBalance;
        uint startTime;
    }
    mapping(address => Account) public members;
    uint public membersCount;

    struct Loan {
        uint loanID;
        uint beginTime;
        uint loanTime;
        uint amountLoaned;
        bool paid;
    }
    Loan[] public loans;

    struct Transaction {
        string category;
        uint amount;
        uint timestamp;
        uint balance;
    }
    Transaction[] public transactions;

    uint private interestRate = 2;
    uint private mostRecentCompound;

    modifier isMember() {
        require(members[msg.sender].memberID == msg.sender);
        _;
    }

    //should have some kind of DID piece (uPort)
    function createAccount(address memberID) public {
        members[msg.sender] = Account({
            memberID: memberID,
            currentBalance: 0,
            availableBalance: 0,
            startTime: now
        });
        membersCount++;
        mostRecentCompound = now;
    }
    
    //msg.value is in wei, needs to be converted to ether on front-end
    function deposit() public isMember payable {
        members[msg.sender].currentBalance = members[msg.sender].currentBalance + msg.value;
        members[msg.sender].availableBalance = members[msg.sender].availableBalance + msg.value;
        
        Transaction memory newTransaction = Transaction({
            category: "Deposit",
            amount: msg.value,
            timestamp: now,
            balance: members[msg.sender].currentBalance
        });
        transactions.push(newTransaction);        
    }
    
    //amount is in wei, needs to be converted to ether on front-end
    function withdraw(uint amount) public isMember {
        require(amount <= members[msg.sender].availableBalance);
        msg.sender.transfer(amount);
        members[msg.sender].currentBalance = members[msg.sender].currentBalance - amount;
        members[msg.sender].availableBalance = members[msg.sender].availableBalance - amount;
        
        Transaction memory newTransaction = Transaction({
            category: "Withdrawal",
            amount: amount,
            timestamp: now,
            balance: members[msg.sender].currentBalance
        });
        transactions.push(newTransaction);
    }

    //msg.value is in wei, needs to be converted to ether on front-end
    function transfer(address recipient) public isMember payable {
        require(msg.value <= members[msg.sender].availableBalance);
        recipient.transfer(msg.value);
        members[msg.sender].currentBalance = members[msg.sender].currentBalance - msg.value;
        members[msg.sender].availableBalance = members[msg.sender].availableBalance - msg.value;

        Transaction memory newTransaction = Transaction({
            category: "Transfer",
            amount: msg.value,
            timestamp: now,
            balance: members[msg.sender].currentBalance
        });
        transactions.push(newTransaction);
    }

    function checkBalance() public isMember returns(uint[]) {
        // write an algorithm that checks if it has been at least 1 day since the most recent compound.
        // if it has, calculate how many days it has been, compound the balance "that" many times, and add the most recent time + "that" many days to set the new most recent time.
        if (now - mostRecentCompound >= 1 seconds) {
            var n = (now - mostRecentCompound)/1 seconds;
            members[msg.sender].currentBalance = members[msg.sender].currentBalance * (1+interestRate/100)**n;
            members[msg.sender].availableBalance = members[msg.sender].availableBalance * (1+interestRate/100)**n;
            mostRecentCompound = mostRecentCompound + (n * 1 seconds);
        }

        uint[] memory balances = new uint[](2);
        balances[0] = members[msg.sender].currentBalance;
        balances[1] = members[msg.sender].availableBalance;
        return balances;
    }

    //amountLoaned is in wei, needs to be converted to ether on front-end
    function requestLoan(uint loanTime, uint amountLoaned) public isMember {
        require(amountLoaned <= members[msg.sender].availableBalance);
        msg.sender.transfer(amountLoaned);
        members[msg.sender].availableBalance = members[msg.sender].availableBalance - amountLoaned;
        
        Loan memory newLoan = Loan({
            loanID: loans.length + 1,
            beginTime: now,
            loanTime: loanTime,
            amountLoaned: amountLoaned,
            paid:false
        });
        loans.push(newLoan);

        Transaction memory newTransaction = Transaction({
            category: "Loan Issued",
            amount: amountLoaned,
            timestamp: now,
            balance: members[msg.sender].currentBalance
        });
        transactions.push(newTransaction);
    }

    //msg.value is in wei, needs to be converted to ether on front-end
    //needs to add interest payment
    function makePayment(uint loanID) public isMember payable {
        require (msg.value == loans[loanID-1].amountLoaned);
        members[msg.sender].availableBalance = members[msg.sender].availableBalance + loans[loanID-1].amountLoaned;
        loans[loanID-1].paid = true;

        Transaction memory newTransaction = Transaction({
            category: "Loan Repaid",
            amount: loans[loanID-1].amountLoaned,
            timestamp: now,
            balance: members[msg.sender].currentBalance
        });
        transactions.push(newTransaction);
    }

    //users should be able to vote on adjusting the APY once each year
    //vote weight depends on balance
    function interestRateVote() public isMember {
        
    }

    //should pay net earnings on interest as a quarterly dividend to all members
    function payDividend() public isMember {

    }
}