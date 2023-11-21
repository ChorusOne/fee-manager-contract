// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardsCollector is Ownable {
    event CollectedReward(
        address withdrawalCredential,
        uint256 withdrawalFee,
        address owner,
        uint256 ownerFee
    );

    // 1 - fee % will go to the user in this address.
    address public withdrawalCredential;

    // Nominator of the fee.
    uint32 public feeNominator;

    // Fee denominator, if `feeNominator = 500`,
    // the tax is 500/10000 = 5/100 = 5%.
    uint32 public constant FEE_DENOMINATOR = 10000;

    // Allow receiving MEV and other rewards.
    receive() external payable {}

    function collectRewards() public payable {
        uint256 ownerAmount = (address(this).balance * feeNominator) /
            FEE_DENOMINATOR;
        uint256 returnedAmount = address(this).balance - ownerAmount;
        require(
            ownerAmount != 0 || returnedAmount != 0,
            "Nothing to distribute"
        );
        address owner = owner();
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

    constructor(address _withdrawalCredential, uint32 _feeNominator) {
        withdrawalCredential = _withdrawalCredential;
        feeNominator = _feeNominator;
    }

    function changeFee(uint32 _newFee) public onlyOwner {
        feeNominator = _newFee;
    }
}

contract FeeRewardsManager is Ownable {
    uint32 public defaultFeeNominator;

    constructor(uint32 _defaultFeeNominator) {
        defaultFeeNominator = _defaultFeeNominator;
    }

    event ContractDeployed(address contractAddress, uint32 feeNominator);

    function changeDefaultFee(uint32 _newFeeNominator) public onlyOwner {
        defaultFeeNominator = _newFeeNominator;
    }

    function createFeeContract(
        address _withdrawalCredential
    ) public returns (address payable) {
        bytes32 withdrawalCredentialBytes = bytes32(
            uint256(uint160(_withdrawalCredential)) << 96
        );
        address addr = address(
            // Uses CREATE2 opcode.
            new RewardsCollector{salt: withdrawalCredentialBytes}(
                _withdrawalCredential,
                defaultFeeNominator
            )
        );
        emit ContractDeployed(addr, defaultFeeNominator);
        return payable(addr);
    }

    function predictFeeContractAddress(
        address _withdrawalCredential
    ) public view returns (address) {
        bytes memory bytecode = type(RewardsCollector).creationCode;
        bytecode = abi.encodePacked(
            bytecode,
            abi.encode(_withdrawalCredential, defaultFeeNominator)
        );
        bytes32 withdrawalCredentialBytes = bytes32(
            uint256(uint160(_withdrawalCredential)) << 96
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

    function changeFee(
        address payable _feeContract,
        uint32 _newFee
    ) public onlyOwner {
        RewardsCollector(_feeContract).changeFee(_newFee);
    }

    function batchCollectRewards(
        address payable[] calldata feeAddresses
    ) public {
        for (uint32 i = 0; i < feeAddresses.length; ++i) {
            RewardsCollector(feeAddresses[i]).collectRewards();
        }
    }

    receive() external payable {}

    function getEth(address addr) external onlyOwner {
        payable(addr).transfer(address(this).balance);
    }
}
