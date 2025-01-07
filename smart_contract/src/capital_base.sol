// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// Import OpenZeppelin contracts for ERC20 token functionality and access control
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Contract deployed on Base Mainnet
 * @notice You can view the deployed contract at:
 * https://basescan.org/address/0xa660002086c4d720bE4F1Af27Fc423431b1cf46b#code
*/

// Interface for Uniswap V3 Factory contract to create and manage liquidity pools
interface IUniswapV3Factory {
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

// Interface for Uniswap V3 Pool contract to initialize pools
interface IUniswapV3Pool {
    function initialize(uint160 sqrtPriceX96) external;
}

// Interface for Uniswap V3 Position Manager to handle liquidity positions
interface INonfungiblePositionManager {
    // Parameters for minting new liquidity positions
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params) external returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    // Parameters for collecting fees from positions
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(CollectParams calldata params) external returns (uint256 amount0, uint256 amount1);
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);
}

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
    // Core contract interfaces
    IUniswapV3Factory public immutable uniswapFactory;
    INonfungiblePositionManager public immutable positionManager;
    ISwapRouter02 private immutable router;

    // Contract addresses for Base network
    address public constant UNISWAP_V3_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address public constant NONFUNGIBLE_POSITION_MANAGER = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address public immutable WETH = 0x4200000000000000000000000000000000000006;
    address private constant SWAP_ROUTER_ADDRESS = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address public fee_address = 0xf2bE870e0512f3C79613271de77383e8371dEb75;
    address[] public allTokenAddresses;


    // Struct to store token deployment information
    struct TokenInfo {
        address creator;
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        string imageURL;
        address addressTreasury;
    }

    // Storage mappings
    mapping(address => TokenInfo) public tokens;
    mapping(address => bool) public agents;

    // Events for important contract actions
    event TokenDeployed(address indexed tokenAddress, string name, string symbol, address indexed creator);
    event FeesCollected(address indexed tokenAddress, address indexed creator, uint256 amount0, uint256 amount1);
    event AgentAdded(address indexed agent);
    event AgentRemoved(address indexed agent);
    event TokensSwapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    // Initialize contract with core dependencies
    constructor() Ownable(msg.sender) {
        uniswapFactory = IUniswapV3Factory(UNISWAP_V3_FACTORY);
        positionManager = INonfungiblePositionManager(NONFUNGIBLE_POSITION_MANAGER);
        router = ISwapRouter02(SWAP_ROUTER_ADDRESS);
    }

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

    function deployFunds(string calldata name, string calldata symbol, uint256 requiredWETH, string calldata imageURL, address address_treasury) external returns(address) {

        // Transferir 1 WETH desde el msg.sender al contrato
        require(IERC20(WETH).transferFrom(msg.sender, address(this), requiredWETH), "WETH transfer failed");

        // Dividir el WETH recibido
        uint256 treasureWETH = requiredWETH / 2;

        // Transferir la mitad al address_treasury
        require(IERC20(WETH).transfer(address_treasury, treasureWETH), "WETH transfer to treasury failed");

        // Deploy del nuevo token ERC20
        ERC20 token = new CustomERC20(name, symbol, 1_000_000_000, imageURL);
        address tokenAddress = address(token);

        // Guardar información del token
        tokens[tokenAddress] = TokenInfo({
            creator: msg.sender,
            name: name,
            symbol: symbol,
            decimals: token.decimals(),
            totalSupply: token.totalSupply(),
            imageURL: imageURL,
            addressTreasury: address_treasury
        });

        allTokenAddresses.push(tokenAddress);

        emit TokenDeployed(tokenAddress, name, symbol, msg.sender);

        // Create and initialize Uniswap V3 pool
        createPool(tokenAddress, WETH, 10000);

        getPoolAddress(tokenAddress, WETH, 10000);

        // Mint de tokens
        uint256 totalMinted = 1_000_000_000 * 10 ** 18;
        uint256 toSender = (totalMinted * 90) / 100; // 90%
        uint256 toLiquidity = totalMinted - toSender; // 10%

        // Transferir el 90% al msg.sender
        token.transfer(msg.sender, toSender);

        uint256 liquidityWETH = requiredWETH - treasureWETH;
        uint256 sqrtvalue = toLiquidity / liquidityWETH;
        uint160 sqrtPriceX96 = uint160(sqrt(sqrtvalue) * (2**96));

        initializePool(tokenAddress, WETH, 10000, sqrtPriceX96);

        // Añadir liquidez con el otro 50% de WETH y 10% de tokens
        addFullRangeLiquidity(WETH, tokenAddress, 10000, liquidityWETH, toLiquidity, msg.sender);

        return tokenAddress;
    }

    // Create a new Uniswap V3 pool
    function createPool(address token0, address token1, uint24 fee) public {
        address pool = uniswapFactory.getPool(token0, token1, fee);
        require(pool == address(0), "Pool already exists");

        pool = uniswapFactory.createPool(token0, token1, fee);
    }

    // Initialize a Uniswap V3 pool with initial price
    function initializePool(address token0, address token1, uint24 fee, uint160 sqrtPriceX96) public {
        address pool = uniswapFactory.getPool(token0, token1, fee);
        require(pool != address(0), "Pool does not exist");

        IUniswapV3Pool(pool).initialize(sqrtPriceX96);
    }

    // Add full range liquidity to a pool
    function addFullRangeLiquidity(address token0, address token1, uint24 fee, uint256 amount0Desired, uint256 amount1Desired, address recipient) internal {
        int24 tickLower = -887200;
        int24 tickUpper = 887200;

        // Approve token transfers
        IERC20(token0).approve(NONFUNGIBLE_POSITION_MANAGER, amount0Desired);
        IERC20(token1).approve(NONFUNGIBLE_POSITION_MANAGER, amount1Desired);

        // Create mint parameters
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: 0,
            amount1Min: 0,
            recipient: recipient,
            deadline: block.timestamp + 1 hours
        });

        positionManager.mint(params);
    }

    // Calculate square root using Newton's method
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
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
        string memory imageURL,
        address addressTreasury
    ) {
        TokenInfo memory info = tokens[tokenAddress];
        require(info.creator != address(0), "Token not found");
        return (
            info.name,
            info.symbol,
            info.decimals,
            info.totalSupply,
            info.imageURL,
            info.addressTreasury
        );
    }

    function getPoolAddress(address token0, address token1, uint24 fee) public view returns (address) {
        address pool = uniswapFactory.getPool(token0, token1, fee);
        require(pool != address(0), "Pool does not exist");
        return pool;
    }

    function swapTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public returns (uint256 amountOut) {
        uint256 treasureAmount = (amountIn * 38) / 1000; 
        uint256 remainingAmount = amountIn - treasureAmount;

        // Transfer `tokenIn` from the sender to this contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Send 3.8% to the treasure address
        IERC20(tokenIn).transfer(fee_address, treasureAmount);

        // Approve `tokenIn` for the swap using the remaining amount
        IERC20(tokenIn).approve(SWAP_ROUTER_ADDRESS, remainingAmount);

        // Prepare swap parameters
        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: 10000,
            recipient: msg.sender,
            amountIn: remainingAmount,
            amountOutMinimum: 0, // No minimum output amount set (caution: this can lead to high slippage)
            sqrtPriceLimitX96: 0 // No price limit set
        });

        // Execute the swap
        amountOut = router.exactInputSingle(params);

        emit TokensSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

}