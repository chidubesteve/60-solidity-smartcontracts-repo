// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Insurance is Ownable {
    /// @title Insurance
    /// @author @chidubesteve(https://github.com/chidubesteve)
    /// @notice This is an insurance policy smart contract
    /// @dev Below is a robust example of a Solidity smart contract designed for the insurance industry. This smart contract includes basic functionalities, such as creating policies, paying premiums, filing claims, and settling claims
    // structs
    /// @dev This struct emulates the data model of a policy */
    struct Policy {
        uint256 policyId;
        uint256 startDate;
        uint256 endDate;
        uint256 premiumAmount;
        uint256 coverageAmount;
        uint256 deductible;
        bool isActive;
    }

    ///@dev This struct emulates the data model of a claim */
    struct Claim {
        uint256 policyId;
        uint256 claimId;
        uint256 claimDate;
        uint256 claimAmount;
        string description;
        bool isApproved;
    }

    /// @dev Relationships:
    /// Customer - Policy: One-to-Many (A customer can have multiple policies)
    /// Policy - Claim: One-to-Many (A policy can have multiple claims)
    /// Policy - Payment: One-to-Many (A policy can have multiple payments)

    // variables
    uint private policyCount;
    uint private claimCount;
    address[] private policyHolders; // insured addresses
    address payable private insurer;
    address private constant MY_ADDRESS =
        0xd3c4c9759054ae252DA85293ed54d3E57b7626ef;
    uint private constant DEDUCTIBLE = 0.01 ether;

    //mappings
    mapping(uint => Policy) private policies;
    mapping(uint => Claim) private claims;
    mapping(uint => mapping(address => bool)) private insuredAddresses;

    //errors
    error PolicyNotActive();
    error ClaimNotApproved();
    error ClaimAlreadyApproved();
    error ClaimNotPaid();
    error ExpiredPolicy(uint256 _endDate);
    error EndDateMustBeInFuture();
    error IncorrectPremiumAmount();

    //events
    event PolicyCreated(Policy);
    event ClaimCreated(Claim);
    event premiumPaid(
        address indexed _user,
        uint256 indexed _policyId,
        uint indexed _amount
    );
    // the ClaimApproved and ClaimRejected events can b eimproved to emit the address of the user, maybe the description for the reject, when the data is being fed from an application
    event ClaimApproved(uint256 indexed _policyId, Claim indexed _claim);
    event ClaimRejected(uint256 indexed _policyId, Claim indexed _claim);
    event ClaimPaid(
        uint256 _claimId,
        address indexed _user,
        uint256 indexed amount
    );
    event PolicyEdited(uint256 _policyId, Policy);

    //modifiers
    modifier onlyInsurer() {
        require(insurer == msg.sender, "Only the insurer can call this");
        _;
    }

    modifier onlyPolicyHolder(uint policyId) {
        updatePolicyStatus(policyId);
        require(
            insuredAddresses[policyId][msg.sender] == true,
            "Only the policy holder can call this"
        );
        if(policies[policyId].isActive != true) revert PolicyNotActive(); 
        _;
    }
    modifier nonZeroAddress(address _caller) {
        require(_caller != address(0), "Zero address not allowed");
        _;
    }
    // constructor
    constructor() Ownable(msg.sender) {
        insurer = payable(msg.sender);
        policyCount = 0;
        claimCount = 0;
    }

    //Functions
    /// @param  _premiumAmount the policyholder pays to the insurance company in exchange for coverage
    /// @param  _coverageAmount is the maximum amount the insurance company will pay for a covered loss.
    /// @param _endDate The end date of the policy
    /// @param  _deductible is the amount the policyholder must pay out-of-pocket before the insurance coverage kicks in
    /// @notice this functions assumes only one policy package that offers a coverage amount of 40% of premium and a low deductible of 0.001 ETH

    /// @dev This function creates a new policy
    function createPolicy(
        uint256 _endDate,
        uint256 _premiumAmount
    ) public nonZeroAddress(msg.sender) onlyInsurer returns (uint) {
        if (_endDate < block.timestamp) {
            revert EndDateMustBeInFuture();
        }
        require(_premiumAmount > 0, "Premium must be greater than zero");
        require(
            _premiumAmount > DEDUCTIBLE,
            "Premium must be greater than deductible"
        );

        policyCount += 1;
        policies[policyCount] = Policy({
            policyId: policyCount,
            startDate: block.timestamp,
            endDate: _endDate,
            premiumAmount: _premiumAmount,
            coverageAmount: (60 * _premiumAmount) / 100,
            deductible: DEDUCTIBLE,
            isActive: true
        });
        emit PolicyCreated(policies[policyCount]);
        return policyCount;
    }

    function payPremium(
        uint256 _policyId
    ) external payable nonZeroAddress(msg.sender) {
        updatePolicyStatus(_policyId);
        require(_policyId > 0, "Invalid policy id");
        Policy storage policy = policies[_policyId];

        if (policy.isActive != true) {
            revert PolicyNotActive();
        }
        if (block.timestamp > policy.endDate) {
            revert ExpiredPolicy(policy.endDate);
        }
        if (msg.value != policy.premiumAmount) {
            revert IncorrectPremiumAmount();
        }

        // add the address under this policy
        _addInsuredAddress(_policyId, msg.sender);
        emit premiumPaid(msg.sender, _policyId, msg.value);
    }

    /// @dev adds an address to a policy to become insured
    function _addInsuredAddress(uint256 _policyId, address _insured) internal {
        updatePolicyStatus(_policyId);
        insuredAddresses[_policyId][_insured] = true;
    }

    /// @dev this ffulnction is used to file a claim by an insured usser due to a loss or event
    /// @param  _policyId the id of the policy the user is claiming for
    /// @param  _claimAmount the amount of the claim - that is the amount the insured user is requesting that it be payed by the insruer
    /// @param  _description the description of the claim
    function fileClaim(
        uint _policyId,
        uint _claimAmount,
        string calldata _description
    )
        external
        nonZeroAddress(msg.sender)
        onlyPolicyHolder(_policyId)
        returns (uint)
    {
        require(_policyId > 0 && _policyId <= policyCount, "Invalid policy id");
        Policy storage policy = policies[_policyId];
        require(
            _claimAmount <= policy.coverageAmount,
            "Claim amount exceeds coverage amount"
        );
        require(_claimAmount > 0, "Claim amount must be greater than zero");
        // require(bytes(_description).length > 0, "Description can't be empty");
        claimCount += 1;
        claims[claimCount] = Claim({
            policyId: _policyId,
            claimId: claimCount,
            claimDate: block.timestamp,
            claimAmount: _claimAmount,
            description: _description,
            isApproved: false
        });
        emit ClaimCreated(claims[claimCount]);
        return claimCount;
    }

    function approveClaim(
        uint _claimId,
        address payable _payoutAddress
    )
        public
        nonZeroAddress(_payoutAddress)
        nonZeroAddress(msg.sender)
        onlyInsurer
    {
        require(_claimId > 0 && _claimId <= claimCount, "Invalid claim id");
        Claim storage claim = claims[_claimId];
        if (claim.isApproved == true) {
            revert ClaimAlreadyApproved();
        }
        claim.isApproved = true;
        emit ClaimApproved(claim.claimId, claim);
        // handle payout processing
        _sendEther(_payoutAddress, claim.claimAmount);
        emit ClaimPaid(claim.claimId, _payoutAddress, claim.claimAmount);
    }

    /// @dev This function is used to reject an insured user's claim, maybe due to inaccurate information, this will hav to be evaluaed maybe form the front end
    /// @param  _claimId the id of the claim
    function rejectClaim(
        uint _claimId
    ) public nonZeroAddress(msg.sender) onlyInsurer {
        require(_claimId > 0 && _claimId <= claimCount, "Invalid claim id");
        Claim storage claim = claims[_claimId];
        if (claim.isApproved == true) {
            revert ClaimAlreadyApproved();
        }
        if (claim.isApproved == false) {
            revert ClaimNotApproved();
        }
        claim.isApproved = false;
        emit ClaimRejected(claim.claimId, claim);
    }
    /// @dev This function is used to cancel a policy and can only be called by the insruer
    function cancelPolicy(uint256 _policyID) public onlyInsurer {
        require(_policyID > 0 && _policyID <= policyCount, "Invalid policy id");
        delete policies[_policyID];
    }

    /// @dev function to edit policy
    function editPolicy(
        uint256 _policyId,
        uint _premiumAmount,
        uint _startDate,
        uint _endDate
    ) public onlyInsurer {
        updatePolicyStatus(_policyId);
        require(_policyId > 0 && _policyId <= policyCount, "Invalid policy id");
        require(_premiumAmount > 0, "Premium must be greater than zero");
        require(
            _premiumAmount > DEDUCTIBLE,
            "Premium must be greater than deductible"
        );
        require(_startDate < _endDate, "Start date must be before end date");
        require(
            block.timestamp > _startDate,
            "Start date must be in the future"
        );
        Policy storage policy = policies[_policyId];
        if (policy.isActive != true) {
            revert PolicyNotActive();
        }
        policy.premiumAmount = _premiumAmount;
        policy.startDate = _startDate;
        policy.endDate = _endDate;
        emit PolicyEdited(_policyId, policy);
    }

    /// @dev function to send contract balance to my address
    function sendContractBalance() public nonZeroAddress(msg.sender) {
        _sendEther(payable(MY_ADDRESS), address(this).balance);
    }

    /// @dev this internal function will send ether to the inputed address
    /// @param  _to the address to send the ether to
    /// @param  _amount the amount of ether to send
    function _sendEther(address payable _to, uint _amount) internal {
        (bool sent, bytes memory data) = _to.call{value: _amount}("");
        require(sent, "Failed to send Ether");
        // console.log(data);
    }

    function updatePolicyStatus(uint256 _policyId) internal {
        Policy storage policy = policies[_policyId];
        if (block.timestamp >= policy.endDate && policy.isActive) {
            policy.isActive = false;
        }
    }

    function checkAndUpdatePolicyStatus(uint256 _policyId) public {
        updatePolicyStatus(_policyId);
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

    // Fallback functions
    receive() external payable {}

    fallback() external payable {}
}
