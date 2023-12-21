// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/FeeRewardsManager.sol";

contract ReentrantAttack {
    fallback() external payable {
        RewardsCollector(payable(msg.sender)).collectRewards();
    }
}

contract ChangeOwnerContract {
    fallback() external payable {
        FeeRewardsManager(payable(msg.sender)).transferOwnership(
            address(0x200)
        );
    }
}

contract WithdrawalContract {
    fallback() external payable {}
}

contract FeeRewardsTest is Test {
    FeeRewardsManager public feeRewardsManager;

    function setUp() public {
        feeRewardsManager = new FeeRewardsManager(2800);
    }

    function testHappyPath() public {
        address withdrawalCredential = address(100);
        vm.deal(address(0), 10 ether);
        address derivedAddr = feeRewardsManager.predictFeeContractAddress(
            withdrawalCredential
        );

        vm.deal(derivedAddr, 10 ether);

        address payable addr = feeRewardsManager.createFeeContract(
            withdrawalCredential
        );

        //derived address matches the function to get one.
        assertEq(derivedAddr, addr);

        // derived address has the parent's as owner
        assertEq(
            address(feeRewardsManager),
            RewardsCollector(payable(addr)).parentContract()
        );

        uint256 amountInContract = address(addr).balance;

        // We've got 10 ether in the contract.
        assertEq(amountInContract, 10 ether);

        RewardsCollector(payable(addr)).collectRewards();

        // User receives 72%.
        assertEq(withdrawalCredential.balance, 7.2 ether);

        // We receive 28%.
        assertEq(address(feeRewardsManager).balance, 2.8 ether);

        feeRewardsManager.getEth(address(101));

        // We've got the ether.
        assertEq(address(feeRewardsManager).balance, 0 ether);
        assertEq(address(101).balance, 2.8 ether);

        vm.deal(derivedAddr, 10 ether);
        RewardsCollector(payable(addr)).collectRewards();
        assertEq(addr.balance, 0 ether);
        assertEq(withdrawalCredential.balance, 7.2 ether + 7.2 ether);
        assertEq(address(101).balance, 2.8 ether);
    }

    function createWithdrawalSimulateRewards(
        address withdrawalCredential,
        uint reward
    ) public returns (RewardsCollector) {
        address payable addr = feeRewardsManager.createFeeContract(
            withdrawalCredential
        );
        addr.transfer(reward);
        return RewardsCollector(payable(addr));
    }

    function testGetMultipleRewards() public {
        address payable[] memory addrs = new address payable[](100);
        for (uint256 i = 0; i < 100; ++i) {
            addrs[i] = payable(
                address(
                    createWithdrawalSimulateRewards(
                        address(uint160(i + 100)),
                        10 ether
                    )
                )
            );
        }
        feeRewardsManager.batchCollectRewards(addrs);
        assertEq(address(feeRewardsManager).balance, 280 ether);

        for (uint256 i = 0; i < 100; ++i) {
            assertEq(address(uint160(i + 100)).balance, 7.2 ether);
        }
    }

    function testChangeDefaultFee() public {
        feeRewardsManager.changeDefaultFee(100);
        assertEq(feeRewardsManager.defaultFeeNumerator(), 100);

        address addr = address(
            createWithdrawalSimulateRewards(address(100), 10 ether)
        );
        RewardsCollector(payable(addr)).collectRewards();
        assertEq(address(100).balance, 9.9 ether);
        // We receive 1%.
        assertEq(address(feeRewardsManager).balance, 0.1 ether);
    }

    function testChangeFee() public {
        address addr = address(
            createWithdrawalSimulateRewards(address(100), 10 ether)
        );
        feeRewardsManager.changeFeeNumerator(payable(addr), 10000);
        RewardsCollector(payable(addr)).collectRewards();
        assertEq(address(100).balance, 0 ether);
        // We receive 100%.
        assertEq(address(feeRewardsManager).balance, 10 ether);
    }

    function testZeroRewards() public {
        address addr = address(
            createWithdrawalSimulateRewards(address(100), 0)
        );
        vm.expectRevert("Nothing to distribute");
        RewardsCollector(payable(addr)).collectRewards();
    }

    function testFuzzyHappyPathNoContracts(
        uint128 rewards,
        address owner
    ) public {
        // Some smart contracts will revert when called, avoid them.
        vm.assume(owner.code.length == 0);
        // Avoid some precompiles.
        vm.assume(owner > address(0x100));
        vm.assume(rewards > 10000);
        vm.assume(rewards < 1e30);
        vm.deal(address(this), rewards);
        RewardsCollector collector = createWithdrawalSimulateRewards(
            owner,
            rewards
        );
        uint256 chorusAmount = (address(collector).balance *
            uint256(collector.feeNumerator())) /
            CalculateAndSendRewards.FEE_DENOMINATOR;
        uint256 withdrawalCredentialsAmount = address(collector).balance -
            chorusAmount;
        uint256 chorusBalanceBefore = address(feeRewardsManager).balance;
        uint256 withdrawalBalanceBefore = owner.balance;
        collector.collectRewards();
        assertEq(
            address(owner).balance,
            withdrawalBalanceBefore + withdrawalCredentialsAmount
        );
        assertEq(
            address(feeRewardsManager).balance,
            chorusBalanceBefore + chorusAmount
        );
    }

    // Test calling `collectRewards` from a contract that calls `collectRewards`
    // again, this will revert as the Ether is divided just to Chorus and the
    // withdrawal credential.
    function testReentrantAttack() public {
        ReentrantAttack withdrawalCredentialContract = new ReentrantAttack();
        address addr = address(
            createWithdrawalSimulateRewards(
                address(withdrawalCredentialContract),
                10 ether
            )
        );
        vm.expectRevert("Failed to send Ether back to withdrawal credential");
        RewardsCollector(payable(addr)).collectRewards();
    }

    function testSendToContractWithdrawalCredential() public {
        ChangeOwnerContract withdrawalCredentialContract = new ChangeOwnerContract();
        address addr = address(
            createWithdrawalSimulateRewards(
                address(withdrawalCredentialContract),
                10 ether
            )
        );
        vm.expectRevert("Failed to send Ether back to withdrawal credential");
        RewardsCollector(payable(addr)).collectRewards();
    }

    function testChangeOwnership() public {
        feeRewardsManager.transferOwnership(address(0x105));
        assertEq(feeRewardsManager.pendingOwner(), address(0x105));
        vm.startPrank(address(0x105));
        feeRewardsManager.acceptOwnership();
        vm.stopPrank();
        assertEq(feeRewardsManager.owner(), address(0x105));
    }

    function testInvalidDefaultFeeNumerator() public {
        vm.expectRevert("Invalid fee numerator");
        feeRewardsManager = new FeeRewardsManager(10_001);
    }

    function testChangeToInvalidFeeNumerator() public {
        address addr = address(
            createWithdrawalSimulateRewards(address(100), 10 ether)
        );
        vm.expectRevert("Invalid fee numerator");
        feeRewardsManager.changeFeeNumerator(payable(addr), 10_001);
    }

    function testChangeFeeNumeratorAndWatchPredictedContract() public {
        address withdrawalCredential = address(100);
        vm.deal(address(0), 10 ether);
        address derivedAddr = feeRewardsManager.predictFeeContractAddress(
            withdrawalCredential
        );
        feeRewardsManager.changeDefaultFee(10_000);
        address derivedAddr2 = feeRewardsManager.predictFeeContractAddress(
            withdrawalCredential
        );
        assert(derivedAddr == derivedAddr2);
    }

    function testDerivedAddress() public {
        address withdrawalCredential = address(100);
        vm.deal(address(0), 10 ether);
        address derivedAddr = feeRewardsManager.predictFeeContractAddress(
            withdrawalCredential
        );

        vm.deal(derivedAddr, 10 ether);

        address payable addr = feeRewardsManager.createFeeContract(
            withdrawalCredential
        );

        //derived address matches the function to get one.
        assertEq(derivedAddr, addr);
    }
}
