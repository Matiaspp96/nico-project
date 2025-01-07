// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {CapitalDeployer} from "../src/capital.sol";

contract CapitalDeployerScript is Script {
    function run() external returns (CapitalDeployer) {
        vm.startBroadcast();

        CapitalDeployer deployer = new CapitalDeployer();

        vm.stopBroadcast();

        return deployer;
    }
}