// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/FeeRewardsManager.sol";

contract FeeRewardsTest is Test {
    FeeRewardsManager public feeRewardsManager;

    function setUp() public {
        feeRewardsManager = new FeeRewardsManager();
    }

    function testHappyPath() public {
        address withdrawalCredential = address(100);
        vm.deal(address(0), 10 ether);
        address derivedAddr = feeRewardsManager.predictFeeContractAddress(
            withdrawalCredential
        );

        vm.deal(derivedAddr, 10 ether);

        address addr = feeRewardsManager.createFeeContract(
            withdrawalCredential
        );

        //derived address matches the function to get one.
        assertEq(derivedAddr, addr);

        // derived address has the parent's as owner
        assertEq(address(feeRewardsManager), RewardsCollector(addr).owner());

        uint256 amountInContract = address(addr).balance;

        // We've got 10 ether in the contract.
        assertEq(amountInContract, 10 ether);

        RewardsCollector(addr).collectRewards();

        // User receives 70%.
        assertEq(withdrawalCredential.balance, 7.2 ether);

        // We receive 30%.
        assertEq(address(feeRewardsManager).balance, 2.8 ether);

        feeRewardsManager.getEth(address(101));

        // We've got the ether.
        assertEq(address(feeRewardsManager).balance, 0 ether);
        assertEq(address(101).balance, 2.8 ether);
    }

    function createWithdrawalSimulateRewards(
        address withdrawalCredential
    ) public returns (address) {
        address addr = feeRewardsManager.createFeeContract(
            withdrawalCredential
        );
        vm.deal(addr, 10 ether);
        return addr;
    }

    function testGetMultipleRewards() public {
        address[] memory addrs = new address[](100);
        for (uint256 i = 0; i < 100; ++i) {
            addrs[i] = createWithdrawalSimulateRewards(
                address(uint160(i + 100))
            );
        }
        feeRewardsManager.collectRewards(addrs);
        assertEq(address(feeRewardsManager).balance, 280 ether);
    }

    function testChangeDefaultFee() public {
        feeRewardsManager.changeDefaultFee(100);
        assertEq(feeRewardsManager.defaultFeeNominator(), 100);

        address addr = createWithdrawalSimulateRewards(address(100));
        RewardsCollector(addr).collectRewards();
        assertEq(address(100).balance, 9.9 ether);
        // We receive 30%.
        assertEq(address(feeRewardsManager).balance, 0.1 ether);
    }

    function testChangeFee() public {
        address addr = createWithdrawalSimulateRewards(address(100));
        feeRewardsManager.changeFee(addr, 10000);
        RewardsCollector(addr).collectRewards();
        assertEq(address(100).balance, 0 ether);
        // We receive 30%.
        assertEq(address(feeRewardsManager).balance, 10 ether);
    }
}
