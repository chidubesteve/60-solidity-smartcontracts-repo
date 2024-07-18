// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

/// @title Tickky Contract
/// @author Chidube Steve (https://github.com/chidubesteve)
/// @notice This contract is used for buying tickets for the travel industry
/// @dev This contract is used for buying tickets for the travel industry

/// @dev This struct emulates the data model of a ticket
struct TicketDetails {
    uint tokenId;
    uint totalTickets;
    uint price;
    uint ticketsSold;
    address creator;
    uint ticketStartDate;
    uint ticketEndDate;
    bool isSold;
}

/// @dev This struct emulates the data model of a transaction
struct PurchaseDetails {
    uint ticketId;
    uint price;
    uint quantity;
    address buyer;
    uint transactionId;
    uint purchaseTimestamp;
}

contract Tickky is Ownable, ReentrancyGuard, ERC721URIStorage {
    //variables
    TicketDetails[] private tickets;
    mapping(uint => PurchaseDetails[]) private purchases;
    mapping(address => uint256[]) private userTickets;
    uint private tokenIdCount;
    address private constant MY_ADDRESS =
        0xd3c4c9759054ae252DA85293ed54d3E57b7626ef;

    uint256 private creationFeePercentage = 10; // 10% fee percentage for crating tickets
    uint256 private purchaseFeePercentage = 10; // 10% fee percentage for purchasing tickets

    event TicketCreated(
        uint256 indexed tickedId,
        uint256 totalTickets,
        uint256 ticketPrice,
        uint256 ticketStartDate,
        uint256 ticketEndDate
    );

    event TicketPurchased(
        uint256 indexed tickedId,
        address buyer,
        uint256 ticketsBought
    );

    event TicketRefunded(
        address _refundee,
        uint _amount,
        uint indexed ticketId
    );

    // errors
    error InsufficientFunds(uint _amount);
    error TicketAlreadySold();
    error TransactionFailed();
    error TicketNotFound();
    error PurchaseNotFound();
    error TicketNotSold();

    //modifiers
    /// @dev Ensures the caller has enough funds
    modifier hasEnoughFunds(uint256 quantity, uint ticketId) {
        TicketDetails storage ticket = tickets[ticketId];
        require(msg.value >= ticket.price * quantity, "Not enough funds");
        _;
    }

    modifier NonZeroTotalTickets(uint256 _totalTickets) {
        require(_totalTickets > 0, "tickets must be greater than zero");
        _;
    }
    modifier NonZeroPrice(uint256 _price) {
        require(_price > 0, "price must be greater than zero");
        _;
    }

    /// @dev Ensures the address is not zero
    modifier nonZeroAddress(address _caller) {
        require(_caller != address(0), "Zero address not allowed");
        _;
    }

    modifier ticketsAvailable(uint256 quantity, uint ticketId) {
        TicketDetails storage ticket = tickets[ticketId];
        require(
            quantity > 0 &&
                ticket.ticketsSold + quantity <= ticket.totalTickets,
            "Not enough tickets available"
        );
        _;
    }

    constructor() Ownable(msg.sender) ERC721("Tickky", "TKY") {}

    //functions
    ///@dev this function creates a ticket
    ///@param tokenURI the tokenURI of the ticket
    ///@param _totalTickets the total number of tickets to be created
    ///@param _ticketPrice the price of the ticket
    ///@param _ticketEndDate when the ticket will expire
    function createTicket(
        string calldata tokenURI,
        uint256 _totalTickets,
        uint256 _ticketPrice,
        uint256 _ticketEndDate
    )
        external
        payable
        NonZeroTotalTickets(_totalTickets)
        nonZeroAddress(msg.sender)
        NonZeroPrice(_ticketPrice)
    {
        require(
            _ticketEndDate > block.timestamp,
            "Ticket end date must be in the future"
        );
        // create the ticket
        uint currentID = tokenIdCount;
        _safeMint(msg.sender, currentID);
        _setTokenURI(currentID, tokenURI);

        uint256 ticketStartDate = block.timestamp;

        tickets[currentID] = TicketDetails({
            tokenId: currentID,
            totalTickets: _totalTickets,
            price: _ticketPrice,
            ticketsSold: 0,
            creator: msg.sender,
            ticketStartDate: ticketStartDate,
            ticketEndDate: _ticketEndDate,
            isSold: false
        });
        // calculate the creation fee and send to contract owner
        uint256 creationFee = (creationFeePercentage * _ticketPrice * 100) /
            10000;
        if (msg.value >= creationFee) {
            _sendEther(payable(owner()), creationFee);
            // emit the ticket created event
            emit TicketCreated(
                currentID,
                _totalTickets,
                _ticketPrice,
                ticketStartDate,
                _ticketEndDate
            );
            // increase the ticket count
            tokenIdCount++;
        } else {
            revert InsufficientFunds(msg.value);
        }
    }

    ///@dev this function purchases a ticket
    ///@param _quantity the number of tickets to be purchased
    ///@param _ticketId the id of the ticket
    ///@dev this function purchases a ticket
    ///@param _quantity the number of tickets to be purchased
    ///@param _ticketId the id of the ticket
    function purchaseTicket(
        uint _quantity,
        uint _ticketId
    )
        external
        payable
        nonZeroAddress(msg.sender)
        hasEnoughFunds(_quantity, _ticketId)
        ticketsAvailable(_quantity, _ticketId)
    {
        TicketDetails storage ticket = tickets[_ticketId];
        if (ticket.isSold) revert TicketAlreadySold();

        uint totalPrice = ticket.price * _quantity;
        uint256 fee = (totalPrice * purchaseFeePercentage * 100) / 10000;
        if (msg.value < totalPrice + fee) revert InsufficientFunds(msg.value);
        uint256 finalPrice = msg.value - fee;
        _sendEther(payable(address(this)), fee);
        _sendEther(payable(ticket.creator), finalPrice);

        for (uint i = 0; i < _quantity; i++) {
            _mintTicket(msg.sender, _ticketId, ticket.price);
        }

        emit TicketPurchased(_ticketId, msg.sender, _quantity);

        ticket.ticketsSold += _quantity;
        if (ticket.ticketsSold == ticket.totalTickets) {
            ticket.isSold = true;
        }
    }

    function _mintTicket(address buyer, uint _ticketId, uint price) internal {
        uint newTicketId = tokenIdCount++;
        _safeMint(buyer, newTicketId);
        _setTokenURI(newTicketId, tokenURI(_ticketId));

        purchases[newTicketId].push(
            PurchaseDetails({
                ticketId: _ticketId,
                buyer: buyer,
                quantity: 1,
                purchaseTimestamp: block.timestamp,
                price: price,
                transactionId: newTicketId
            })
        );

        userTickets[buyer].push(newTicketId);
    }

    function refundTicket(
        address _userAddress,
        uint _ticketId,
        uint _quantity
    )
        external
        onlyOwner
        nonZeroAddress(msg.sender)
        nonZeroAddress(_userAddress)
    {
        TicketDetails storage ticket = tickets[_ticketId];
        if (ticket.isSold == false) revert TicketNotSold();

        (bool purchaseFound, uint purchaseIndex) = _findUserPurchase(
            _userAddress,
            _ticketId
        );
        if (!purchaseFound) revert PurchaseNotFound();

        PurchaseDetails storage userPurchase = purchases[_ticketId][
            purchaseIndex
        ];
        require(
            userPurchase.quantity >= _quantity,
            "Incorrect ticket quantity"
        );

        uint refundAmount = userPurchase.price * _quantity;
        userPurchase.quantity -= _quantity;
        ticket.ticketsSold -= _quantity;

        _removeUserTickets(_userAddress, _ticketId, _quantity);
        _sendEther(payable(_userAddress), refundAmount);

        emit TicketRefunded(_userAddress, refundAmount, _ticketId);

        if (ticket.ticketsSold == 0) {
            ticket.isSold = false;
        }
    }

    function _findUserPurchase(
        address user,
        uint _ticketId
    ) internal view returns (bool, uint) {
        for (uint i = 0; i < purchases[_ticketId].length; i++) {
            if (purchases[_ticketId][i].buyer == user) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function _removeUserTickets(
        address user,
        uint _ticketId,
        uint _quantity
    ) internal {
        uint count = 0;
        for (
            uint i = 0;
            i < userTickets[user].length && count < _quantity;
            i++
        ) {
            if (userTickets[user][i] == _ticketId) {
                userTickets[user][i] = userTickets[user][
                    userTickets[user].length - 1
                ];
                userTickets[user].pop();
                count++;
            }
        }
    }

    function checkAvailability(uint _ticketId) public view returns (uint) {
        TicketDetails storage ticket = tickets[_ticketId];
        return ticket.totalTickets - ticket.ticketsSold;
    }

    /// @dev function to transfer ownership
    function transferOwnership(
        address _newOwner
    ) public override onlyOwner nonZeroAddress(_newOwner) {
        _transferOwnership(_newOwner);
    }

    /// @dev function to renounce ownership, default it leaves the contract without an owner, address(0), but i'm transfering ownership to my address
    function renounceOwnership()
        public
        override
        onlyOwner
        nonZeroAddress(msg.sender)
    {
        _transferOwnership(MY_ADDRESS);
    }

    ///@dev function to get contrtact balance
    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    ///@dev function to send funcds to my address
    function withdraw() external onlyOwner nonZeroAddress(msg.sender) {
        _sendEther(payable(MY_ADDRESS), address(this).balance);
    }

    /// @dev Internal function to send ether to an address
    /// @param _to The address to send the ether to
    /// @param _amount The amount of ether to send
    function _sendEther(
        address payable _to,
        uint _amount
    ) internal nonReentrant {
        (bool sent, ) = _to.call{value: _amount}("");
        if (!sent) revert TransactionFailed();
    }

    //getter functions

    function getTickets() public view returns (TicketDetails[] memory) {
        return tickets;
    }

    function getTicketInfo(
        uint _ticketId
    ) public view returns (TicketDetails memory) {
        return tickets[_ticketId];
    }

    function getPurchase(
        uint _transactionId
    ) public view returns (PurchaseDetails[] memory) {
        return purchases[_transactionId];
    }

    function getUserTickets(
        address _userAddress
    ) public view returns (uint256[] memory) {
        return userTickets[_userAddress];
    }

    function updateCreationFeePercentage(
        uint256 _creationFeePercentage
    ) external onlyOwner {
        creationFeePercentage = _creationFeePercentage;
    }

    function updatePurchaseFeePercentage(
        uint256 _purchaseFeePercentage
    ) external onlyOwner {
        purchaseFeePercentage = _purchaseFeePercentage;
    }

    function getTicketIdCount() public view returns (uint) {
        return tokenIdCount;
    }

    // Fallback functions
    receive() external payable {}
    fallback() external payable {}
}
