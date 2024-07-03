// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Governance is Ownable {
    // structs
    struct Citizen {
        string name;
        uint32 age;
        uint32 id;
        bool isRegistered;
        bool isAlive;
    }

    struct Official {
        string name;
        uint32 id;
        uint32 age;
        string position;
        bool isRegistered;
        bool isAlive;
    }

    struct Law {
        uint32 id;
        string description;
        uint date;
        uint votesFor;
        uint votesAgainst;
        bool enacted;
        bool edited;
        uint lastEdited;
    }

    // variables
    uint32 public lawCount = 0;
    address private constant MY_ADDRESS = 0xd3c4c9759054ae252DA85293ed54d3E57b7626ef;
    address[] private citizensAddresses;
    address[] private officialsAddresses;

    // mappings
    mapping(address => Citizen) private citizens;
    mapping(address => Official) private officials;
    mapping(uint32 => Law) private laws;

    // Events
    event CitizenRegistered(address indexed _address, Citizen);
    event OfficialRegistered(address indexed _address, Official);
    event LawProposed(uint32 indexed _lawId, Law);
    event LawEnacted(uint32 indexed _lawId, Law);
    event Voted(uint32 indexed _lawId, address indexed _voter, bool _vote);
    event LawEdited(uint32 indexed _lawId, Law);
    event LawDeleted(uint32 indexed _lawId, Law);

    // modifiers
    modifier onlyCitizen() {
        require(citizens[msg.sender].isRegistered, "Only citizen can call this");
        _;
    }

    modifier onlyOfficial() {
        require(officials[msg.sender].isRegistered, "Only official can call this");
        _;
    }

    modifier validLawId(uint32 _lawId) {
        require(_lawId < lawCount, "Invalid Law Id");
        _;
    }

    modifier nonZeroAddress() {
        require(msg.sender != address(0), "Zero address not allowed");
        _;
    }

    // constructor
    constructor() payable Ownable(msg.sender) {}

    // Functions
    function registerAsCitizen(string memory _name, uint32 _age) public nonZeroAddress {
        require(!citizens[msg.sender].isRegistered, "Citizen already registered");
        require(!officials[msg.sender].isRegistered, "Official already registered");
        uint32 id = uint32(uint256(keccak256(abi.encodePacked(msg.sender))));
        citizens[msg.sender] = Citizen({
            name: _name,
            age: _age,
            id: id,
            isRegistered: true,
            isAlive: true
        });
        citizensAddresses.push(msg.sender);
        emit CitizenRegistered(msg.sender, citizens[msg.sender]);
    }

    function registerAsOfficial(string memory _name, uint32 _age, string memory _position) public nonZeroAddress {
        require(!officials[msg.sender].isRegistered, "Official already registered");
        require(!citizens[msg.sender].isRegistered, "Citizen already registered");
        uint32 id = uint32(uint256(keccak256(abi.encodePacked(msg.sender))));
        officials[msg.sender] = Official({
            name: _name,
            id: id,
            age: _age,
            position: _position,
            isRegistered: true,
            isAlive: true
        });
        officialsAddresses.push(msg.sender);
        emit OfficialRegistered(msg.sender, officials[msg.sender]);
    }

    function proposeLaw(string memory _description) public onlyOfficial nonZeroAddress {
        require(bytes(_description).length > 0, "Description can't be empty");
        laws[lawCount] = Law({
            id: lawCount,
            description: _description,
            date: block.timestamp,
            votesFor: 0,
            votesAgainst: 0,
            enacted: false,
            edited: false,
            lastEdited: block.timestamp
        });
        emit LawProposed(lawCount, laws[lawCount]);
        lawCount++;
    }

    function voteOnLaw(uint32 _lawId, bool _vote) public onlyCitizen nonZeroAddress validLawId(_lawId) {
        if (_vote) {
            laws[_lawId].votesFor++;
        } else {
            laws[_lawId].votesAgainst++;
        }
        emit Voted(_lawId, msg.sender, _vote);
    }

    function enactLaw(uint32 _lawId) public onlyOfficial validLawId(_lawId) {
        require(!laws[_lawId].enacted, "Law already enacted");
        require(laws[_lawId].votesFor > laws[_lawId].votesAgainst, "Law hasn't passed");
        laws[_lawId].enacted = true;
        emit LawEnacted(_lawId, laws[_lawId]);
    }

    function editLaw(uint32 _lawId, string memory _description) public onlyOfficial validLawId(_lawId) {
        require(bytes(_description).length != 0, "Description can't be empty");
        laws[_lawId].description = _description;
        laws[_lawId].lastEdited = block.timestamp;
        laws[_lawId].edited = true;
        emit LawEdited(_lawId, laws[_lawId]);
    }

    function deleteLaw(uint32 _lawId) public onlyOfficial nonZeroAddress validLawId(_lawId) {
        Law storage law = laws[_lawId];
        require(bytes(law.description).length > 0, "Law not proposed");
        require(!law.enacted, "Law already enacted");
        require(law.votesFor > 0 || law.votesAgainst > 0, "Law not voted on");

        if (law.votesAgainst > law.votesFor) {
            emit LawDeleted(_lawId, law);
            delete laws[_lawId];
        }
    }

    function transferOwnership(address _newOwner) public override onlyOwner nonZeroAddress {
        _transferOwnership(_newOwner);
    }

    function renounceOwnership() public override onlyOwner nonZeroAddress {
        _transferOwnership(MY_ADDRESS);
    }

    // Getter Functions
    function getCitizens() public view returns (Citizen[] memory) {
        Citizen[] memory _citizens = new Citizen[](citizensAddresses.length);
        for (uint32 i = 0; i < citizensAddresses.length; i++) {
            _citizens[i] = citizens[citizensAddresses[i]];
        }
        return _citizens;
    }

    function getOfficials() public view returns (Official[] memory) {
        Official[] memory _officials = new Official[](officialsAddresses.length);
        for (uint32 i = 0; i < officialsAddresses.length; i++) {
            _officials[i] = officials[officialsAddresses[i]];
        }
        return _officials;
    }

    function getIndividualCitizen(address _citizen) public view returns (Citizen memory) {
        return citizens[_citizen];
    }

    function getIndividualOfficial(address _official) public view returns (Official memory) {
        return officials[_official];
    }

    function getCitizenCount() public view returns (uint256) {
        return citizensAddresses.length;
    }

    function getOfficialCount() public view returns (uint256) {
        return officialsAddresses.length;
    }

    function getLaw(uint32 _lawId) public view validLawId(_lawId) returns (Law memory) {
        return laws[_lawId];
    }

    function getAllLaws() public view returns (Law[] memory) {
        Law[] memory _laws = new Law[](lawCount);
        for (uint32 i = 0; i < lawCount; i++) {
            _laws[i] = laws[i];
        }
        return _laws;
    }

    //** @notice this function is to withdrw any funds that may be in the contract */
    function withdrawFunds() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(MY_ADDRESS).transfer(balance);
    }

    // Fallback functions
    receive() external payable {}

    fallback() external payable {}
}
