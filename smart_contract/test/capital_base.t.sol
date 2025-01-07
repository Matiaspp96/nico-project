// test/capital_base.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/capital_base.sol";

/**
 * @dev Contract deployed on Base Mainnet
 * @notice You can view the deployed contract at:
 * https://basescan.org/address/0xa660002086c4d720bE4F1Af27Fc423431b1cf46b#code
*/

contract CapitalDeployerTest is Test {
    CapitalDeployer capitalDeployer;
    address owner;
    address agent;

    function setUp() public {
        owner = address(this);
        agent = address(0x123);
        capitalDeployer = new CapitalDeployer();
        capitalDeployer.addAgent(agent);
    }

    function testAddAgent() public {
        // Verifica que el agente fue agregado correctamente
        assertTrue(capitalDeployer.agents(agent), "Agent should be added");
    }

    function testRemoveAgent() public {
        capitalDeployer.removeAgent(agent);
        // Verifica que el agente fue removido correctamente
        assertFalse(capitalDeployer.agents(agent), "Agent should be removed");
    }

    function testDeployFunds() public {
        // Simula la transferencia de WETH al contrato
        uint256 requiredWETH = 1 ether; // Cambia esto según sea necesario
        vm.deal(owner, requiredWETH); // Proporciona WETH al propietario

        // Llama a la función deployFunds
        address tokenAddress = capitalDeployer.deployFunds("TestToken", "TT", requiredWETH, "http://example.com/image.png", owner);

        // Verifica que el token fue creado
        (string memory name, string memory symbol, uint8 decimals, uint256 totalSupply, string memory imageURL, address addressTreasury) = capitalDeployer.getTokenDetails(tokenAddress);
        assertEq(name, "TestToken", "Token name should match");
        assertEq(symbol, "TT", "Token symbol should match");
        assertEq(totalSupply, 1_000_000_000 * 10 ** 18, "Total supply should match");
    }

    function testWithdraw() public {
        // Simula la transferencia de WETH al contrato
        uint256 requiredWETH = 1 ether; // Cambia esto según sea necesario
        vm.deal(owner, requiredWETH); // Proporciona WETH al propietario
        capitalDeployer.deployFunds("TestToken", "TT", requiredWETH, "http://example.com/image.png", owner);

        // Llama a la función withdraw
        uint256 amountToWithdraw = 1 ether; // Cambia esto según sea necesario
        capitalDeployer.withdraw(address(0), amountToWithdraw); // Cambia la dirección del token según sea necesario
    }
}
