### CapitalDeployer Contract Suite

---

#### **General Description**

This repository contains the `CapitalDeployer` and `CustomERC20` contracts, designed for the creation, management, and deployment of custom ERC20 tokens. The contracts are geared towards facilitating the creation of tokens with associated images, managing treasuries, handling authorized agents, and performing liquidity-related operations. 

The main contract is deployed on multiple networks, including Base Mainnet and Lens Sepolia. 

- **[Base Mainnet Deployment](https://basescan.org/address/0xa660002086c4d720bE4F1Af27Fc423431b1cf46b#code)**  
- **[Lens Sepolia Deployment](https://block-explorer.testnet.lens.dev/address/0x873d5852894f68D6343d0E673EaE6486E317D246#write)**  

---

#### **Technologies Used**

- **Solidity (`^0.8.25`)**: For the implementation of the contracts.
- **OpenZeppelin**: Provides standard functionalities for ERC20 and access control.
- **Uniswap**: For liquidity management and swaps.
- **Foundry**: For unit tests.
- **Lens Sepolia and Base Mainnet**: Blockchain networks used for deployment.

---

#### **Main Contract Structure**

##### **CustomERC20**
- A custom ERC20 token contract that allows creating tokens with a defined initial supply and associating them with an image (URL).

##### **CapitalDeployer**
- The main contract that manages the creation of ERC20 tokens and their integration with treasuries.
- Includes functionalities for:
  - Creating and registering tokens.
  - Handling authorized agents.
  - Withdrawing funds from the contract.
  - Querying details of registered tokens.

---

#### **Functionality of `deployFunds`**

The `deployFunds` function is the core of the contract. It is used to deploy a new ERC20 token with an associated image and register the token information in the main contract.

##### **Parameters**
- `name` (string): Name of the token.
- `symbol` (string): Symbol of the token.
- `imageURL` (string): URL of the associated image.

##### **Process**
1. Validates that the input parameters are not empty.
2. Deploys a new `CustomERC20` contract with the provided name, symbol, and URL.
3. Registers the token information, including its creator, decimals, total supply, and image URL.
4. Emits a `TokenDeployed` event.

##### **Results**
- A custom ERC20 token is deployed with the specified parameters.
- The contract stores token information, accessible through its address.

---

#### **Important Events**

- **`TokenDeployed`**: Emits information about a newly created token.
- **`AgentAdded` and `AgentRemoved`**: Indicate changes in the list of authorized agents.

---

#### **Key Functions**

- **Agent Management**
  - `addAgent`: Adds a new authorized agent.
  - `removeAgent`: Removes an authorized agent.
  - `onlyAgent` (modifier): Restricts specific functions to authorized agents.

- **Token Management**
  - `deployFunds`: Deploys a new ERC20 token and registers its data.
  - `getTokenDetails`: Returns details of a registered token.
  - `getAllTokenAddresses`: Lists all addresses of registered tokens.

- **Funds Management**
  - `withdraw`: Allows agents to withdraw funds from the contract.
  - `balance`: Queries the contract balance for a specific token.

---