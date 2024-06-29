// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DeBank is Ownable, ReentrancyGuard {
    struct Account {
        uint256 balance;
        string name;
        string email;
        bool exists;
    }
    //mapping
    mapping(address => Account) private accounts;
    address private  owner;
    uint256 private totalBankBalance;
    /** @notice this is the minimum amount required to create an account*/
    uint256 private constant MINIMUM_DEPOSIT = 0.01 ether;

    //events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event AccountCreated(Account);

    // errors
    error MinimumDepositNotMet(uint256 depositAmount, uint256 requiredAmount);
    error AccountDoesNotExist();
    error AccountAlreadyExists(address addr);



    constructor() Ownable(msg.sender) {
        owner = msg.sender;
    }

    // functions
    /** @notice this function will create an account for a user provided that the minimum deposit is met*/
    // how can i write not greater than or equal to in solidity


    function createAccount(string memory _name, string memory _email) public payable {
        bool condition = msg.value >= MINIMUM_DEPOSIT;
        if (!condition) {
            revert MinimumDepositNotMet(msg.value, MINIMUM_DEPOSIT);
        }

        if (accounts[msg.sender].exists) {
            revert AccountAlreadyExists(msg.sender);
        }
        accounts[msg.sender] = Account({balance: msg.value, name: _name, email: _email, exists: true});
        emit AccountCreated(accounts[msg.sender]);
    }
}
