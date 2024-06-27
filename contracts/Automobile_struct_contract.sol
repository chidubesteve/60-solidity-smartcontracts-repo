// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

contract Automobile {
    struct Vehicle {
        string vin;
        address buyer;
        address seller;
        uint256 price;
        bool isSold;
    }

    address private seller;
    uint256 private feePercentage = 10; // Updated fee percentage
    string[] private vehicleVINs; // List of all valid Vins
    mapping(string => Vehicle) private vehicleDetails; // Mapping from VIN to Vehicle

    event Purchased(address indexed buyer, uint256 price, string vehicleVIN);
    event VehicleListed(string vehicleVIN, uint256 price);

    constructor() {
        seller = msg.sender;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this function");
        _;
    }

    // Add new vehicle VIN
    function addVIN(string memory _vin) public onlySeller {
        require(
            bytes(vehicleDetails[_vin].vin).length == 0,
            "VIN already exists"
        );
        vehicleVINs.push(_vin);
        vehicleDetails[_vin].vin = _vin; // Add entries directly to vehicleDetails
        emit VehicleListed(_vin, 0); // Signal that a VIN was added
    }

    // List vehicle for sale
    function listVehicle(string memory _vin, uint256 _price) public onlySeller {
        require(
            bytes(vehicleDetails[_vin].vin).length != 0,
            "VIN not registered"
        );
        require(_price > 0, "Price must be greater than zero");

        Vehicle storage vehicle = vehicleDetails[_vin];
        require(!vehicle.isSold, "Vehicle already sold");

        vehicle.seller = msg.sender;
        vehicle.price = _price;
        vehicle.isSold = false;
        emit VehicleListed(_vin, _price);
    }

    // Purchase vehicle
    function purchaseVehicle(string memory _vin) public payable {
        Vehicle storage vehicle = vehicleDetails[_vin];
        require(bytes(vehicle.vin).length != 0, "Invalid VIN");
        require(!vehicle.isSold, "Vehicle is already sold.");
        require(msg.value >= vehicle.price, "Insufficient amount");

        uint256 fee = (msg.value * feePercentage) / 100;
        require(
            msg.value >= (fee + vehicle.price),
            "Insufficient amount including fee"
        );

        payable(seller).transfer(fee);
        payable(vehicle.seller).transfer(msg.value - fee);

        vehicle.buyer = msg.sender;
        vehicle.isSold = true;

        emit Purchased(vehicle.buyer, vehicle.price, _vin);
    }

    // Get vehicle details
    function getVehicleDetails(
        string memory _vin
    ) public view returns (Vehicle memory) {
        require(bytes(vehicleDetails[_vin].vin).length != 0, "Invalid VIN");
        return vehicleDetails[_vin];
    }

    // Get list of VINs
    function getVins() public view returns (string[] memory) {
        return vehicleVINs;
    }

    // Fee management
    function getFeePercentage() public view returns (uint256) {
        return feePercentage;
    }

    function setFeePercentage(uint256 _feePercentage) public onlySeller {
        feePercentage = _feePercentage;
    }
}
// cheaper in gas 1800577 gas