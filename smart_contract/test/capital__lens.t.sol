// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {CapitalDeployer, CustomERC20} from "../src/capital__lens.sol";

contract CapitalDeployerTest is Test {
    CapitalDeployer public deployer;
    address public owner;
    address public agent;
    address public user;

    function setUp() public {
        owner = makeAddr("owner");
        agent = makeAddr("agent");
        user = makeAddr("user");
        
        vm.startPrank(owner);
        deployer = new CapitalDeployer();
        vm.stopPrank();
    }

    function test_DeployFunds() public {
        vm.startPrank(user);
        
        string memory name = "Test Token";
        string memory symbol = "TEST";
        string memory imageURL = "https://example.com/image.png";
        
        address tokenAddress = deployer.deployFunds(name, symbol, imageURL);
        
        // Verificar que el token fue desplegado correctamente
        assertTrue(tokenAddress != address(0), "Token address should not be zero");
        
        // Verificar los detalles del token
        (
            string memory returnedName,
            string memory returnedSymbol,
            uint8 decimals,
            uint256 totalSupply,
            string memory returnedImageURL
        ) = deployer.getTokenDetails(tokenAddress);
        
        assertEq(returnedName, name, "Token name mismatch");
        assertEq(returnedSymbol, symbol, "Token symbol mismatch");
        assertEq(decimals, 18, "Decimals should be 18");
        assertEq(totalSupply, 1_000_000_000 * 10**18, "Total supply mismatch");
        assertEq(returnedImageURL, imageURL, "Image URL mismatch");
        
        vm.stopPrank();
    }

    function test_AddAndRemoveAgent() public {
        vm.startPrank(owner);
        
        // Añadir agente
        deployer.addAgent(agent);
        assertTrue(deployer.agents(agent), "Agent should be added");
        
        // Remover agente
        deployer.removeAgent(agent);
        assertFalse(deployer.agents(agent), "Agent should be removed");
        
        vm.stopPrank();
    }

    function test_OnlyOwnerCanAddAgent() public {
        vm.startPrank(user);
        
        vm.expectRevert("Ownable: caller is not the owner");
        deployer.addAgent(agent);
        
        vm.stopPrank();
    }

    function test_WithdrawAsAgent() public {
        // Preparar el token y los fondos
        vm.startPrank(owner);
        deployer.addAgent(agent);
        vm.stopPrank();

        vm.startPrank(user);
        string memory name = "Test Token";
        string memory symbol = "TEST";
        string memory imageURL = "https://example.com/image.png";
        address tokenAddress = deployer.deployFunds(name, symbol, imageURL);
        CustomERC20 token = CustomERC20(tokenAddress);
        
        // Transferir algunos tokens al contrato
        uint256 amount = 1000 * 10**18;
        token.transfer(address(deployer), amount);
        vm.stopPrank();

        // Probar withdraw como agente
        vm.startPrank(agent);
        deployer.withdraw(tokenAddress, amount);
        assertEq(token.balanceOf(agent), amount, "Agent should receive tokens");
        vm.stopPrank();
    }

    function test_GetAllTokenAddresses() public {
        vm.startPrank(user);
        
        // Desplegar múltiples tokens
        address token1 = deployer.deployFunds("Token1", "TK1", "url1");
        address token2 = deployer.deployFunds("Token2", "TK2", "url2");
        
        address[] memory tokens = deployer.getAllTokenAddresses();
        
        assertEq(tokens.length, 2, "Should have deployed 2 tokens");
        assertEq(tokens[0], token1, "First token address mismatch");
        assertEq(tokens[1], token2, "Second token address mismatch");
        
        vm.stopPrank();
    }

    function testFail_DeployWithEmptyParams() public {
        vm.startPrank(user);
        deployer.deployFunds("", "", "");
        vm.stopPrank();
    }

    function testFail_WithdrawAsNonAgent() public {
        vm.startPrank(user);
        string memory name = "Test Token";
        string memory symbol = "TEST";
        string memory imageURL = "https://example.com/image.png";
        address tokenAddress = deployer.deployFunds(name, symbol, imageURL);
        
        deployer.withdraw(tokenAddress, 100);
        vm.stopPrank();
    }
}
