// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// Import OpenZeppelin contracts for ERC20 token functionality and access control
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Custom ERC20 token contract with initial supply minting
contract CustomERC20 is ERC20 {
    string public imageURL;

    constructor(string memory name, string memory symbol, uint256 initialSupply, string memory _imageURL) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply * 10 ** decimals());
        imageURL = _imageURL;
    }
}

// Main contract for token deployment and liquidity management
contract CapitalDeployer is Ownable {

    address[] public allTokenAddresses;


    // Struct to store token deployment information
    struct TokenInfo {
        address creator;
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        string imageURL;
    }

    // Storage mappings
    mapping(address => TokenInfo) public tokens;
    mapping(address => bool) public agents;

    // Events for important contract actions
    event TokenDeployed(address indexed tokenAddress, string name, string symbol, address indexed creator);
    event AgentAdded(address indexed agent);
    event AgentRemoved(address indexed agent);

    // Initialize contract with core dependencies
    constructor() Ownable(msg.sender) {}

    // Modifier to restrict functions to authorized agents
    modifier onlyAgent() {
        require(agents[msg.sender], "You are not an Agent");
        _;
    }

    // Add a new authorized agent
    function addAgent(address agent) external onlyOwner {
        agents[agent] = true;
        emit AgentAdded(agent);
    }

    // Remove an authorized agent
    function removeAgent(address agent) external onlyOwner {
        agents[agent] = false;
        emit AgentRemoved(agent);
    }

    function deployFunds(string calldata name, string calldata symbol, string calldata imageURL) external returns(address) {
        require(bytes(name).length > 0, "Token name cannot be empty");
        require(bytes(symbol).length > 0, "Token symbol cannot be empty");
        require(bytes(imageURL).length > 0, "Image URL cannot be empty");

        // Deploy the new ERC20 token
        CustomERC20 token = new CustomERC20(name, symbol, 1_000_000_000, imageURL);
        address tokenAddress = address(token);
        
        // Check if the tokenAddress is valid
        require(tokenAddress != address(0), "Token deployment failed, address is null");

        // Store token information
        tokens[tokenAddress] = TokenInfo({
            creator: msg.sender,
            name: name,
            symbol: symbol,
            decimals: token.decimals(),
            totalSupply: token.totalSupply(),
            imageURL: imageURL
        });

        allTokenAddresses.push(tokenAddress);

        emit TokenDeployed(tokenAddress, name, symbol, msg.sender);

        return tokenAddress;
    }

    // Withdraw tokens from the contract (only agents)
    function withdraw(address token, uint256 amount) external onlyAgent {
        uint256 contractBalance = IERC20(token).balanceOf(address(this));
        require(amount <= contractBalance, "Insufficient contract balance");
        IERC20(token).transfer(msg.sender, amount);
    }

    // Get token balance of the contract
    function balance(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getAllTokenAddresses() external view returns (address[] memory) {
        return allTokenAddresses;
    }

    function getTokenDetails(address tokenAddress) external view returns (
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 totalSupply,
        string memory imageURL
    ) {
        TokenInfo memory info = tokens[tokenAddress];
        require(info.creator != address(0), "Token not found");
        return (
            info.name,
            info.symbol,
            info.decimals,
            info.totalSupply,
            info.imageURL
        );
    }

}