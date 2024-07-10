// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Retail Industry Contract
/// @author Chidube Steve(https://github.com/chidubesteve)
/// @dev This smart contract includes basic functionalities, such as creating products and purchasing products.
/// @notice This smart contract can be used in the e-commerce industry to enhance transparency, tracing, reliability, and security.
contract StringToBytes32 {
    function getBytes32(string memory text) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(text));
    }
}

contract Retail is Ownable, ReentrancyGuard {
    // Structs
    /// @dev This struct emulates the data model of a product
    struct Product {
        string sku; // Stock Keeping Unit
        bytes32 name;
        string description;
        uint price;
        uint stockLevel;
    }

    /// @dev This struct emulates the data model of a transaction
    struct Transaction {
        uint transactionId;
        address buyer;
        uint quantity;
        uint price;
        uint timestamp;
    }

    // Mappings
    mapping(string => Product) private products;
    mapping(uint => Transaction) private transactions;
    mapping(uint => address[]) private customerPurchases;
    uint private transactionCount;
    uint256 private feePercentage = 400; // 4% fee
    address payable private shopOwner;
    address private constant MY_ADDRESS =
        0xd3c4c9759054ae252DA85293ed54d3E57b7626ef;

    // Events
    event ProductAdded(Product product);
    event ProductPurchased(Product product);
    event ProductUpdated(Product product);
    event TransactionCreated(Transaction transaction);
    event TransactionFulfilled(Transaction transaction);

    // Errors
    error ProductNotFound();
    error InsufficientStock();
    error InsufficientFunds(uint amount);
    error TransactionFailed();

    // Constructor
    /// @dev Sets the shop owner to the contract deployer
    constructor() Ownable(msg.sender) payable {
        shopOwner = payable(msg.sender);
    }

    // Modifiers
    /// @dev Ensures the address is not zero
    modifier nonZeroAddress(address _caller) {
        require(_caller != address(0), "Zero address not allowed");
        _;
    }

    // Functions

    /// @notice Adds a new product to the store
    /// @param _sku The stock keeping unit of the product
    /// @param _name The name of the product
    /// @param _description The description of the product
    /// @param _price The price of the product
    /// @param stockLevel The initial stock level of the product
    function addProduct(
        string memory _sku,
        bytes32 _name,
        string memory _description,
        uint _price,
        uint stockLevel
    ) public onlyOwner nonZeroAddress(msg.sender) {
        require(stockLevel > 0, "Stock level must be greater than zero");
        products[_sku] = Product({
            sku: _sku,
            name: _name,
            description: _description,
            price: _price,
            stockLevel: stockLevel
        });
        emit ProductAdded(products[_sku]);
        transactionCount++;
    }

    /// @notice Purchases a product from the store
    /// @param _sku The stock keeping unit of the product
    /// @param _quantity The quantity of the product to purchase
    function purchaseProduct(
        string memory _sku,
        uint _quantity
    ) public payable nonZeroAddress(msg.sender) {
        Product storage product = products[_sku];
        if (product.name == "") revert ProductNotFound();
        if (product.stockLevel < _quantity) revert InsufficientStock();
        uint totalPrice = product.price * _quantity;
        uint256 fee = (totalPrice * feePercentage * 100) / 10000; 
        if (msg.value < totalPrice + fee) revert InsufficientFunds(msg.value);

        // Update the product stock level and state before sending ether
        product.stockLevel -= _quantity;
        emit TransactionCreated(transactions[transactionCount]);
        transactions[transactionCount] = Transaction({
            transactionId: transactionCount,
            buyer: msg.sender,
            quantity: _quantity,
            price: product.price,
            timestamp: block.timestamp
        });
        customerPurchases[transactionCount].push(msg.sender);

        // Send fees and payment
        uint256 finalPrice = msg.value - fee;

        _sendEther(payable(address(this)), fee);
        _sendEther(shopOwner, finalPrice);

        emit ProductPurchased(product);
        emit TransactionFulfilled(transactions[transactionCount]);
        transactionCount++;
    }

    /// @notice Updates the stock level of a product
    /// @param _sku The stock keeping unit of the product
    /// @param _quantity The new stock level of the product
    function updateProductStockLevel(
        string memory _sku,
        uint _quantity
    ) public onlyOwner nonZeroAddress(msg.sender) {
        Product storage product = products[_sku];
        if (product.name == "") revert ProductNotFound();
        product.stockLevel += _quantity;
        emit ProductUpdated(product);
    }

    ///@dev function to update description
    ///@param _sku The stock keeping unit of the product
    ///@param _description The new description of the product
    function updateProductDescription(
        string memory _sku,
        string memory _description
    ) public onlyOwner nonZeroAddress(msg.sender) {
        Product storage product = products[_sku];
        if (product.name == "") revert ProductNotFound();
        product.description = _description;
        emit ProductUpdated(product);
    }

    /// @notice Updates the name of a product
    /// @param _sku The stock keeping unit of the product
    /// @param _name The new name of the product
    function updateProductName(
        string memory _sku,
        bytes32 _name
    ) public onlyOwner nonZeroAddress(msg.sender) {
        Product storage product = products[_sku];
        if (product.name == "") revert ProductNotFound();
        product.name = _name;
        emit ProductUpdated(product);
    }

    /// @notice Updates the price of a product
    /// @param _sku The stock keeping unit of the product
    /// @param _price The new price of the product
    function updateProductPrice(
        string memory _sku,
        uint _price
    ) public onlyOwner nonZeroAddress(msg.sender) {
        Product storage product = products[_sku];
        if (product.name == "") revert ProductNotFound();
        product.price = _price;
        emit ProductUpdated(product);
    }

    /// @notice Retrieves product details by SKU
    /// @param _sku The stock keeping unit of the product
    /// @return The product details
    function getProducts(
        string memory _sku
    ) public view returns (Product memory) {
        return products[_sku];
    }

    /// @notice Retrieves transaction details by transaction ID
    /// @param _transactionId The ID of the transaction
    /// @return The transaction details
    function getTransaction(
        uint _transactionId
    ) public view returns (Transaction memory) {
        return transactions[_transactionId];
    }

    /// @notice Retrieves the total number of transactions
    /// @return The total number of transactions
    function getTransactionCount() public view returns (uint) {
        return transactionCount;
    }

    /// @notice Retrieves customer purchases by transaction ID
    /// @param _transactionId The ID of the transaction
    /// @return The addresses of the customers who made the purchase
    function getCustomersPurchases(
        uint _transactionId
    ) public view returns (address[] memory) {
        return customerPurchases[_transactionId];
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
    function withdraw() external onlyOwner nonZeroAddress(msg.sender){
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

    // Fallback functions
    receive() external payable {}
    fallback() external payable {}
}
