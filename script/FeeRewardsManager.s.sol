// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/FeeRewardsManager.sol";

contract Deployer is Script {
    function run() external {
        vm.startBroadcast();
        new FeeRewardsManager(uint32(vm.envUint("DEFAULT_FEE")));
        vm.stopBroadcast();
    }
}
