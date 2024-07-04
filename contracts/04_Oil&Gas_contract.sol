// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Oil_Gas{
 address private owner;

 struct OilWell{
    string name;
    uint256 production;
    address operator;
    string typeOf;
 }
    mapping(string => OilWell) private wells;

    event OilWellCreated(string indexed _wellname, address indexed _operator);
    event ProductionChanged(string indexed _wellname, uint256 indexed _production);


    constructor() {
        owner = msg.sender;
    }

    function createOilWell(string memory _wellName, string memory _type) public {
        wells[_wellName] = OilWell({
            name: _wellName,
            production: 0,
            operator: msg.sender,
            typeOf: _type
        });
        emit OilWellCreated(_wellName, msg.sender);
    }

    function changeOperator(string memory _wellName, address _newOperator) public {
        require(msg.sender == owner, "Must be the owner of the contract");
        wells[_wellName].operator = _newOperator;
    }

    function updateProduction(string memory _wellName, uint256 _production) public {
        require(msg.sender == wells[_wellName].operator, "only the operator can call this");
        wells[_wellName].production = _production;
        emit ProductionChanged(_wellName, _production);
    }

    function updateType(string memory _wellName, string memory _type) public {
        require(msg.sender == wells[_wellName].operator, "only the operator can call this");
        wells[_wellName].typeOf = _type;
    }

    function checkWell(string memory _wellName) public view returns(string memory,  uint256, address, string memory) {
        return (wells[_wellName].name, wells[_wellName].production, wells[_wellName].operator, wells[_wellName].typeOf);
    }

    function getOwner() public view returns (address) {
        return owner;
    }


}