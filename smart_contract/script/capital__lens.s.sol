// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {CapitalDeployer} from "../src/capital__lens.sol";

contract CapitalDeployerScript is Script {
    function setUp() public {}

    function run() public returns (CapitalDeployer) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        CapitalDeployer deployer = new CapitalDeployer();

        vm.stopBroadcast();

        return deployer;
    }
}