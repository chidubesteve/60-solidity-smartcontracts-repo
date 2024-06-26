// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

contract Automobile {
    // Variables
    address private seller;
    address private owner;
    address private buyer;
    string private vehicleVIN;
    string[] private vehicleVINs;
    mapping(string => bool) private validVins; // mapping to check for valid vin
    uint256 private price;
    bool private isSold;
    uint256 private feePercentage = 15; // 15% fee percentage

    //Events
    event Purchased(address _buyer, uint256 _price, string _vehicleVIN);
    event vinAdded(string _vehicleVIN);

    //Constructor to inistilaise the contract with sellers address and price of the vehicle
    constructor() {
        seller = msg.sender;
        owner = msg.sender;
    }

    // Modifiers
    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this function");
        _;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    // Functions

    // function to add new vin
    function addVIN(string memory _vin) public onlySeller {
        require(!validVins[_vin], "VIN already exists");
        validVins[_vin] = true;
        vehicleVINs.push(_vin);
        emit vinAdded(_vin);
    }

    // function to list vehicle for sale
    function listVehicle(string memory _vin, uint256 _price) public onlySeller {
        require(validVins[_vin] == true, "Invalid VIN");
        require(_price > 0, "Price must be greater than zero");
        vehicleVIN = _vin;
        price = _price;
        isSold = false;
    }

    // function to prchase vehicle
    function purchaseVehicle(string memory _vin) public payable {
        require(msg.value >= price, "Insufficient amount");
        require(!isSold, "Vehicle is already sold.");
        require(validVins[_vin] == true, "Invalid VIN");

        uint256 fee = (msg.value * feePercentage) / 100;
        require(msg.value >= fee + price, "Insufficient amount including fee");

        // transfer fee to owner
        payable(owner).transfer(fee);

        // transfer remaining amount to seller
        uint256 finalPrice = msg.value - fee;
        payable(seller).transfer(finalPrice);

        buyer = msg.sender;
        vehicleVIN = _vin;
        isSold = true;
        payable(seller).transfer(msg.value);
        // remove vin from valid vins
        validVins[_vin] = false;
        // remove vin from array of vins
        for (uint i = 0; i < vehicleVINs.length - 1; i++) {
            if (
                keccak256(abi.encodePacked(vehicleVINs[i])) ==
                keccak256(abi.encodePacked(_vin))
            ) {
                vehicleVINs[i] = vehicleVINs[vehicleVINs.length - 1];
                vehicleVINs.pop();
                break;
            }
        }

        emit Purchased(buyer, price, vehicleVIN);
    }

    // function to update car details
    function updateDetails(
        string memory _vin,
        uint256 _price
    ) public onlySeller {
        require(_price > 0, "Price must be greater than zero");
        vehicleVIN = _vin;
        price = _price;
    }
    // function to get car details
    function getVehicleDetails()
        public
        view
        returns (address, address, string memory, uint256, bool)
    {
        return (seller, buyer, vehicleVIN, price, isSold);
    }

    //getter functions
    function getVins() public view returns (string[] memory) {
        return vehicleVINs;
    }

    function getBuyer() public view returns (address) {
        return buyer;
    }

    function getIsSold() public view returns (bool) {
        return isSold;
    }

    function getPrice() public view returns (uint256) {
        return price;
    }

    function getVin() public view returns (string memory) {
        return vehicleVIN;
    }

    function getSeller() public view returns (address) {
        return seller;
    }
    function getSellerBalance() public view returns (uint) {
        return address(seller).balance;
    }

    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }

    function getFeePercentage() public onlyOwner view returns (uint256) {
        return feePercentage;
    }

    function setFeePercentage(uint256 _feePercentage) public onlyOwner {
        feePercentage = _feePercentage;
    }
}
