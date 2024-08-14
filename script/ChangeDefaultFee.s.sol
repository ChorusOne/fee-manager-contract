// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/FeeRewardsManager.sol";

contract ChangeFee is Script {
    function run() external {
        FeeRewardsManager feeRewardsManager = FeeRewardsManager(
            FeeRewardsManager(
                payable(address(vm.envAddress("FEE_REWARDS_MANAGER")))
            )
        );
        vm.startBroadcast();
        feeRewardsManager.changeDefaultFee(uint32(vm.envUint("NEW_FEE")));
        vm.stopBroadcast();
    }
}
