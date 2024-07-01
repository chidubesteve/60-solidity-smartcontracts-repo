// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DeBank is Ownable, ReentrancyGuard {
    struct Account {
        uint256 balance;
        string name;
        string email;
        bool exists;
    }
    // Mapping
    mapping(address => Account) private accounts;
    uint256 private totalBankBalance;

    /** @notice this is the minimum amount required to create an account*/
    uint256 private constant MINIMUM_DEPOSIT = 0.01 ether;
    address private constant MY_ADDRESS = 0xd3c4c9759054ae252DA85293ed54d3E57b7626ef;

    // Events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event AccountCreated(Account);

    // Errors
    error MinimumDepositNotMet(uint256 depositAmount, uint256 requiredAmount);
    error AccountDoesNotExist();
    error AccountAlreadyExists(address addr);
    error NotPermittedToCallThisFunction();
    error InsufficientFunds();

    // Modifiers
    /** @notice this modifier ensures that only account owners can call a function eg. withdraw*/
    modifier onlyAccountOwners() {
        if (!accounts[msg.sender].exists) {
            revert AccountDoesNotExist();
        }
        _;
    }

    // Constructor
    constructor() Ownable(msg.sender) {}

    // Functions

    /** @dev this function will create an account for a user provided that the minimum deposit is met */
    function createAccount(
        string memory _name,
        string memory _email
    ) public payable {
        if (msg.value < MINIMUM_DEPOSIT) {
            revert MinimumDepositNotMet(msg.value, MINIMUM_DEPOSIT);
        }

        if (accounts[msg.sender].exists) {
            revert AccountAlreadyExists(msg.sender);
        }

        accounts[msg.sender] = Account({
            balance: msg.value,
            name: _name,
            email: _email,
            exists: true
        });
        emit AccountCreated(accounts[msg.sender]);
    }

    /** @dev this function will return the total balance of the bank */
    function getTotalBankBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    /** @dev this function will return the balance of an account */
    function getAccountBalance() public view onlyAccountOwners returns (uint256) {
        return accounts[msg.sender].balance;
    }

    /** @dev This function enables ether to be deposited to an account and can only be called within the contract */
    function deposit(address _user, uint256 _amount) internal {
        if (!accounts[_user].exists) {
            revert AccountDoesNotExist();
        }
        require(_amount > 0, "Amount must be greater than zero");
        accounts[_user].balance += _amount;
        emit Deposited(_user, _amount);
    }

    /** @dev this function will deposit ether into the user account */
    function depositIntoMyAccount() public payable onlyAccountOwners {
        deposit(msg.sender, msg.value);
    }

    /** @dev this function will deposit ether into another user's account */
    function depositIntoOtherAccount(address _user) public payable onlyAccountOwners {
        require(
            _user != msg.sender,
            "Can't use to deposit"
        );
        deposit(_user, msg.value);
    }

    /** @dev this function will withdraw funds from an account */
    function withdraw(address payable _to, uint256 _amount) public nonReentrant onlyAccountOwners {
        Account storage account = accounts[_to];

        if (account.balance < _amount) {
            revert InsufficientFunds();
        }

        account.balance -= _amount;
        (bool sent, ) = _to.call{value: _amount}("");
        require(sent, "Withdraw failed");

        emit Withdrawn(_to, _amount);
    }

    //** @dev this function is the destroy the contract */
    //** @notice selfdestruct is deprecated!! */
    function destroy() public onlyOwner {
        selfdestruct(payable(MY_ADDRESS));
    }

    //** @dev  this function is to grant ownership of the contract */
    function transferOwnership(address _newOwner) override  public onlyOwner {
        require(_newOwner != address(0), "Non-zero address");
        _transferOwnership(_newOwner);
    }

    //** @dev this function is to revoke access to the contract */
    function renounceOwnership() override public onlyOwner {
        _transferOwnership(msg.sender);
    }

    // The functions below are called when ether is sent to the contract in this case the bank contract
    receive() external payable {}

    fallback() external payable {}
}
