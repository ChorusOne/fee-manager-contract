// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

// We use a library for the `calculateRewards` function because the less code in
// `RewardsCollector` the less expensive it is to deploy the collector contract.
// We can call the library instead of deploying the library's code again and
// again.
library CalculateAndSendRewards {
    // Fee denominator, if `feeNominator = 500`,
    // the tax is 500/10000 = 5/100 = 5%.
    uint32 public constant FEE_DENOMINATOR = 10_000;
    event CollectedReward(
        address withdrawalCredential,
        uint256 withdrawnAmount,
        address owner,
        uint256 ownerFee
    );

    function calculateAndSendRewards(
        uint32 feeNominator,
        address owner,
        address withdrawalCredential
    ) public {
        uint256 ownerAmount = (address(this).balance * feeNominator) /
            FEE_DENOMINATOR;
        uint256 returnedAmount = address(this).balance - ownerAmount;
        require(
            ownerAmount != 0 || returnedAmount != 0,
            "Nothing to distribute"
        );
        emit CollectedReward(
            withdrawalCredential,
            returnedAmount,
            owner,
            ownerAmount
        );
        // This can be used to call this contract again (reentrancy)
        // but since all funds from this contract are used for the owner
        payable(owner).transfer(ownerAmount);
        (bool sent, ) = payable(withdrawalCredential).call{
            value: returnedAmount
        }("");
        require(sent, "Failed to send Ether back to withdrawal credential");
    }
}

contract RewardsCollector {
    // 1 - fee % will go to the user in this address.
    address public immutable withdrawalCredential;

    // Fee's numerator.
    uint32 public feeNumerator;

    // This is the contract that created the `RewardsCollector`.
    // Do not use owner here because this contract is going to be
    // created multiple times for each `withdrawal credential` and
    // we don't need any function for the ownership except when changing
    // the fee.
    address public immutable parentContract;

    // Allow receiving MEV and other rewards.
    receive() external payable {}

    function collectRewards() public payable {
        CalculateAndSendRewards.calculateAndSendRewards(
            feeNumerator,
            parentContract,
            withdrawalCredential
        );
    }

    constructor(address _withdrawalCredential, uint32 _feeNumerator) {
        withdrawalCredential = _withdrawalCredential;
        feeNumerator = _feeNumerator;
        parentContract = msg.sender;
    }

    function changeFeeNumerator(uint32 _newFeeNumerator) public {
        require(
            msg.sender == parentContract,
            "ChangeFee not called from parent contract"
        );
        require(_newFeeNumerator <= 10_000, "Invalid fee numerator");
        feeNumerator = _newFeeNumerator;
    }
}

contract FeeRewardsManager is Ownable {
    uint32 public defaultFeeNumerator;

    constructor(uint32 _defaultFeeNumerator) {
        require(_defaultFeeNumerator <= 10_000, "Invalid fee numerator");
        defaultFeeNumerator = _defaultFeeNumerator;
    }

    event ContractDeployed(address contractAddress, uint32 feeNumerator);

    function changeDefaultFee(uint32 _newFeeNumerator) public onlyOwner {
        require(_newFeeNumerator <= 10_000, "Invalid fee numerator");
        defaultFeeNumerator = _newFeeNumerator;
    }

    function createFeeContract(
        address _withdrawalCredential
    ) public returns (address payable) {
        bytes32 withdrawalCredentialBytes = bytes32(
            uint256(uint160(_withdrawalCredential))
        );
        address addr = address(
            // Uses CREATE2 opcode.
            new RewardsCollector{salt: withdrawalCredentialBytes}(
                _withdrawalCredential,
                defaultFeeNumerator
            )
        );
        emit ContractDeployed(addr, defaultFeeNumerator);
        return payable(addr);
    }

    // Predicts the address of a new contract that will be a `fee_recipient` of
    // an Ethereum validator.
    // Given the `_withdrawalCredential` we can instantiate a contract that will
    // be deployed at a deterministic address, calculated given the
    // `_withdrawalCredential`, the current contract address and the current
    // contract's bytecode.
    function predictFeeContractAddress(
        address _withdrawalCredential
    ) public view returns (address) {
        bytes memory bytecode = type(RewardsCollector).creationCode;
        bytecode = abi.encodePacked(
            bytecode,
            abi.encode(_withdrawalCredential, defaultFeeNumerator)
        );
        bytes32 withdrawalCredentialBytes = bytes32(
            uint256(uint160(_withdrawalCredential))
        );
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                withdrawalCredentialBytes,
                keccak256(bytecode)
            )
        );
        return address(uint160(uint(hash)));
    }

    function changeFeeNumerator(
        address payable _feeContract,
        uint32 _newFee
    ) public onlyOwner {
        RewardsCollector(_feeContract).changeFeeNumerator(_newFee);
    }

    function batchCollectRewards(
        address payable[] calldata feeAddresses
    ) public {
        for (uint32 i = 0; i < feeAddresses.length; ++i) {
            RewardsCollector(feeAddresses[i]).collectRewards();
        }
    }

    receive() external payable {}

    // Withdraws Eth from the manager contract.
    function getEth(address addr) external onlyOwner {
        payable(addr).transfer(address(this).balance);
    }
}
