// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/FeeRewardsManager.sol";
import "forge-std/console.sol";

contract DisplayCollector is Script {
    function run() external {
        FeeRewardsManager feeRewardsManager = FeeRewardsManager(
            FeeRewardsManager(
                payable(address(vm.envAddress("FEE_REWARDS_MANAGER")))
            )
        );
        address addr = feeRewardsManager.predictFeeContractAddress(
            vm.envAddress("WITHDRAWAL_CREDENTIAL")
        );
        console.log(addr);
    }
}
