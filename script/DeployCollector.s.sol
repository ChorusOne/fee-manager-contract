// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/FeeRewardsManager.sol";

contract DeployCollector is Script {
    function run() external {
        vm.startBroadcast();
        FeeRewardsManager feeRewardsManager = FeeRewardsManager(
            FeeRewardsManager(
                payable(address(vm.envAddress("FEE_REWARDS_MANAGER")))
            )
        );
        feeRewardsManager.createFeeContract(
            vm.envAddress("WITHDRAWAL_CREDENTIAL")
        );
        vm.stopBroadcast();
    }
}
