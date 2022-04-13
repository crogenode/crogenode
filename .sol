/**
 *Submitted for verification at cronoscan.com on 2022-04-13
*/

// Dr. Croge Nodes

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }
}

/**
 * BEP20 standard interface.
 */
interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


/**
 * Allows for contract ownership along with multi-address authorization
 */
abstract contract Auth {
    address internal owner;
    mapping (address => bool) internal authorizations;

    constructor(address _owner) {
        owner = _owner;
        authorizations[_owner] = true;
    }

    /**
     * Function modifier to require caller to be contract owner
     */
    modifier onlyOwner() {
        require(isOwner(msg.sender), "!OWNER"); _;
    }

    /**
     * Function modifier to require caller to be authorized
     */
    modifier authorized() {
        require(isAuthorized(msg.sender), "!AUTHORIZED"); _;
    }

    /**
     * Authorize address. Owner only
     */
    function authorize(address adr) public onlyOwner {
        authorizations[adr] = true;
    }

    /**
     * Remove address' authorization. Owner only
     */
    function unauthorize(address adr) public onlyOwner {
        authorizations[adr] = false;
    }

    /**
     * Check if address is owner
     */
    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }

    /**
     * Return address' authorization status
     */
    function isAuthorized(address adr) public view returns (bool) {
        return authorizations[adr];
    }

    /**
     * Transfer ownership to new address. Caller must be owner. Leaves old owner authorized
     */
    function transferOwnership(address payable adr) public onlyOwner {
        owner = adr;
        authorizations[adr] = true;
        emit OwnershipTransferred(adr);
    }

    event OwnershipTransferred(address owner);
}

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract Nodes is Auth{

    struct NodeInfo{
        uint256 buildDate;
        uint256 count;
        uint256 lastClaimed;
        uint256 claimedPerNode;
        bool active;
    }
    struct NodeContainer{
        NodeInfo[] nodes;
        uint256 claimed;
    }

    struct Earnings{
        uint256 lastClaimed;
        uint256 claimed;
    }

    mapping (address => NodeContainer) public userNodes;
    mapping (address => Earnings) public userEarnings;

    uint256 private decimals;
    bool public buyNodesActive;
    bool public rewardsActive;
    uint256 public pricePerNode;
    uint256 public maxNodes;
    uint256 public allNodes;
    uint256 private earningNode;
    uint256 public eNSetDate;
    uint256 private rewardsHalvingDays;
    uint256 private divider24hToSeconds;
    uint256 private maxReturnNode;

    event SetEarnings(uint256 amount);
    event SetPricePerNode(uint256 amount);
    event ClaimTokens(address user, uint256 amount);
    event BuyNodes(address user, uint256 amount);

    constructor (uint256 _decimals) Auth(msg.sender){
        decimals = _decimals;
        pricePerNode = 100 * (10 ** decimals); // 100
        maxNodes = 100;
        allNodes = 0;
        earningNode = 41 * (10 ** (decimals - 1));        
        eNSetDate = block.timestamp;
        rewardsHalvingDays = 10368000; // 120 days -> 120 x 86400 seconds
        divider24hToSeconds = 24 * 60 * 60;
        maxReturnNode = 700 * (10 ** decimals);
        buyNodesActive = true;
        rewardsActive = true;
    }

    function getEarningNode(uint256 _timestamp) public view returns (uint256) {
        uint256 result = earningNode;
        uint256 timeNow = _timestamp;
        uint256 timediff = timeNow - eNSetDate;
        timediff = timediff - (timediff % rewardsHalvingDays);
        timediff = timediff / rewardsHalvingDays;
        for(uint256 i = 0; i < timediff; i++){
            result = result * 825 / 1000;
        }
        return result;
    }

    function getUserNodeInfo(address userAddress, uint256 id) external view returns(uint256, uint256, uint256, uint256, bool) {
        NodeContainer memory _userNodes = userNodes[userAddress];
        NodeInfo[] memory nodes = _userNodes.nodes;
        require(id < nodes.length, "dev: index exceeds size!");
        return (nodes[id].buildDate, nodes[id].count, nodes[id].lastClaimed, nodes[id].claimedPerNode, nodes[id].active);
    }

    function getUserNodes(address userAddress) public view returns (uint256) {
        uint256 result = 0;
        NodeContainer memory _userNodes = userNodes[userAddress];
        NodeInfo[] memory nodes = _userNodes.nodes;
        for(uint256 i = 0; i < nodes.length; i++){
            if(nodes[i].active) {
                result += nodes[i].count;
            }
        }
        return result;
    } 

    function getUserClaimInfo(address userAddress) external view returns (uint256, uint256) {
        return (userEarnings[userAddress].lastClaimed, userEarnings[userAddress].claimed);
    }

    function getClaimableTokens(address user) public view returns (uint256) {
        uint256 result = 0;
        if(rewardsActive) {
            NodeContainer memory _userNodes = userNodes[user];
            NodeInfo[] memory nodes = _userNodes.nodes;
            uint256 earnings24hToSeconds;
            uint256 secondsPassed;
            uint256 claimedPerNode;
            uint256 newClaimedPerNode;
            for(uint256 i = 0; i < nodes.length; i++){
                if(nodes[i].active) {
                    claimedPerNode = nodes[i].claimedPerNode;
                    earnings24hToSeconds = getEarningNode(block.timestamp);
                    earnings24hToSeconds /= divider24hToSeconds; // earnings per second
                    secondsPassed = block.timestamp - nodes[i].lastClaimed;
                    earnings24hToSeconds *= secondsPassed;
                    newClaimedPerNode = claimedPerNode + earnings24hToSeconds;
                    if((newClaimedPerNode) > maxReturnNode){
                        earnings24hToSeconds = maxReturnNode - claimedPerNode;
                    }
                    result += (earnings24hToSeconds * nodes[i].count);
                }
            }
        }
        return result;
    }

    function claimTokens(address user) public onlyOwner returns (uint256) {
        uint256 result = 0;
        if(rewardsActive) {
            NodeContainer storage _userNodes = userNodes[user];
            NodeInfo[] storage nodes = _userNodes.nodes;
            uint256 earnings24hToSeconds;
            uint256 secondsPassed;
            uint256 claimedPerNode;
            uint256 newClaimedPerNode;
            for(uint256 i = 0; i < nodes.length; i++){
                if(nodes[i].active) {
                    claimedPerNode = nodes[i].claimedPerNode;
                    earnings24hToSeconds = getEarningNode(block.timestamp);
                    earnings24hToSeconds /= divider24hToSeconds; // earnings per second
                    secondsPassed = block.timestamp - nodes[i].lastClaimed;
                    earnings24hToSeconds *= secondsPassed;
                    nodes[i].lastClaimed = block.timestamp;
                    newClaimedPerNode = claimedPerNode + earnings24hToSeconds;
                    if((newClaimedPerNode) > maxReturnNode){
                        nodes[i].active = false;
                        earnings24hToSeconds = maxReturnNode - claimedPerNode;
                        nodes[i].claimedPerNode = maxReturnNode;
                    } else if ((newClaimedPerNode) == maxReturnNode){
                        nodes[i].active = false;
                        nodes[i].claimedPerNode = maxReturnNode;
                    } else {
                        nodes[i].claimedPerNode = newClaimedPerNode;
                    }
                    userNodes[user].nodes[i] = nodes[i];
                    result += (earnings24hToSeconds * nodes[i].count);
                }
            }
            Earnings memory cacheUser = userEarnings[user];
            cacheUser.lastClaimed = block.timestamp;
            cacheUser.claimed += result;
            userEarnings[user] = cacheUser;
            emit ClaimTokens(user, result);
        }
        return result;
    }
    
    function setNodeRewardsActive(bool _buyNodesActive, bool _rewardsActive) external onlyOwner {
        buyNodesActive = _buyNodesActive;
        rewardsActive = _rewardsActive;
    }

    function setEarnings(uint256 _earningNode) external onlyOwner {
        require(_earningNode >= 1 && _earningNode <= 41, "dev: you cannot set that value for standard nodes!");
        earningNode = _earningNode * (10 ** (decimals - 1));
        eNSetDate = block.timestamp;
        emit SetEarnings(_earningNode);
    }

    function buyNodes(address user, uint256 amount)  external onlyOwner {    
        require(buyNodesActive, "dev: buying nodes is not activated!");    
        require(amount <= maxNodes, "dev: you cannot exceed the limit!");   
        require(amount > 0, "dev: you need to enter at least 1!");
        require((getUserNodes(user) + amount) <= maxNodes, "dev: you cannot exceed the nodes limit!");
        if(userEarnings[user].lastClaimed < 1) {
            userEarnings[user].lastClaimed = block.timestamp;
        }
        NodeInfo memory newNode = NodeInfo(
            block.timestamp,
            amount,
            block.timestamp,
            0,
            true
        );
        userNodes[user].nodes.push(newNode);
        allNodes += amount;
        emit BuyNodes(user, amount);
    }
}

contract DRCROGE is IBEP20, Auth {
    using SafeMath for uint256;

    address constant WCRO = 0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23;
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address constant ZERO = 0x0000000000000000000000000000000000000000;

    Nodes private nodes;

    string constant _name = "Dr. Croge Nodes";
    string constant _symbol = "CROA";
    uint8 constant _decimals = 9;

    uint256 _totalSupply = 8000000 * (10 ** _decimals);
    uint256 public _maxTxAmount = (_totalSupply * 1) / 100;  //1% max tx
    uint256 public _maxWalletSize = (_totalSupply * 1) / 100;  //1% max wallet

    mapping (address => uint256) _balances;
    mapping (address => mapping (address => uint256)) _allowances;

    mapping (address => bool) isFeeExempt;
    mapping (address => bool) isTxLimitExempt;

    uint256 devFee;
    uint256 liquidityFee;
    uint256 marketingFee;
    uint256 burnFee;
    uint256 totalFees;

    // sell fees
    uint256 sellDevFee = 0;
    uint256 sellLiquidityFee = 3;
    uint256 sellMarketingFee = 15;
    uint256 sellBurnFee = 5;
    uint256 sellTotalFees = sellDevFee + sellLiquidityFee + sellMarketingFee + sellBurnFee;
    
    // buy fees
    uint256 buyDevFee = 0;
    uint256 buyLiquidityFee = 0;
    uint256 buyMarketingFee = 0;
    uint256 buyTotalFees = buyDevFee + buyLiquidityFee + buyMarketingFee ;

    // node fees
    uint256 rewardsDistribution = 70;
    uint256 treasuryFee = 20;
    uint256 reservoirFee = 5;
    
    
    address private marketingFeeReceiver = 0xDe6c311E6bCDb17D4B7309e393726F0Be8029598;
    address private teamFeeReceiver = 0x309487A468B4498FCa3f24f000a98b70d6d0B4D4;
    address private treasuryWallet = 0x87235613De8e2F3a2162B103406dfB9Af909f230;
    address private reservoirWallet = 0x509ba42Bafa1324c59Aa5066E9F70c31Ff93C8e3;
    address private rewardsWallet = 0xCB1b43966B9E8aF1cEfBf0FdA700207B0a0b5629;

    IDEXRouter public router;
    address public pair;

    uint256 public launchedAt;

    bool public swapEnabled = true;
    uint256 public swapThreshold = _totalSupply / 1000; // 0.1%
    bool inSwap;
    modifier swapping() { inSwap = true; _; inSwap = false; }

    event NodeFeesUpdated(uint256 indexed newRewardsDistribution, uint256 indexed newTreasuryFee, uint256 indexed newReservoirFee);
    event ClaimRewards(uint256 amount, address receiver);
    event Burn(uint256 amount, address receiver);
    event Swap(uint256 tokensSwapped, address receiver);

    constructor () Auth(msg.sender) {
        router = IDEXRouter(0x145677FC4d9b8F19B5D56d1820c48e0443049a30);
        pair = IDEXFactory(router.factory()).createPair(WCRO, address(this));
        _allowances[address(this)][address(router)] = type(uint256).max;

        nodes = new Nodes(_decimals);

        address _owner = owner;
        isFeeExempt[_owner] = true;
        isTxLimitExempt[_owner] = true;

        _balances[_owner] = _totalSupply;
        emit Transfer(ZERO, _owner, _totalSupply);
    }

    receive() external payable { }

    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function decimals() external pure override returns (uint8) { return _decimals; }
    function symbol() external pure override returns (string memory) { return _symbol; }
    function name() external pure override returns (string memory) { return _name; }
    function getOwner() external view override returns (address) { return owner; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if(_allowances[sender][msg.sender] != type(uint256).max){
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount, "Insufficient Allowance");
        }
        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        if(inSwap){ return _basicTransfer(sender, recipient, amount); }        
        checkTxLimit(sender, amount);      
        if (recipient != pair && recipient != DEAD) {
            require(isTxLimitExempt[recipient] || _balances[recipient] + amount <= _maxWalletSize, "Transfer amount exceeds the bag size.");
        }        
        if (recipient == pair) {setSell();}
        else if (sender == pair) {setBuy();} 
        else {setFree();}

        if(shouldSwapBack(recipient)){ swapBack(); }

        _balances[sender] = _balances[sender] - amount;

        uint256 amountReceived = amount;
        if(!shouldTakeFee(sender)){
          amountReceived = amount;
        } else if(!shouldTakeFee(recipient)){
          amountReceived = amount;
        } else {
          amountReceived = takeFee(recipient, amount);
        }        

        _balances[recipient] = _balances[recipient] + amountReceived;
        emit Transfer(sender, recipient, amountReceived);
        return true;
    }
    
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function checkTxLimit(address sender, uint256 amount) internal view {
        require(amount <= _maxTxAmount || isTxLimitExempt[sender], "TX Limit Exceeded");
    }
    
    function shouldTakeFee(address sender) internal view returns (bool) {
        return !isFeeExempt[sender];
    }
    
    function takeFee(address sender, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = amount * (totalFees) / (100);
        uint256 burnAmount = 0;
        if (burnFee > 0) {
          feeAmount = amount * (totalFees - burnFee) / (100);
          burnAmount = amount * (burnFee) / (100);
          _balances[DEAD] = _balances[DEAD] + (burnAmount);
          emit Transfer(sender, DEAD, burnAmount);
        }
        _balances[address(this)] = _balances[address(this)] + (feeAmount);
        emit Transfer(sender, address(this), feeAmount);
        return amount - feeAmount - burnAmount;
    }

    function setBuy() private {
        devFee = buyDevFee;
        liquidityFee = buyLiquidityFee;
        marketingFee = buyMarketingFee;
        burnFee = 0;
        totalFees = devFee + liquidityFee + marketingFee;
    }

    function setSell() private {
        devFee = sellDevFee;
        liquidityFee = sellLiquidityFee;
        marketingFee = sellMarketingFee;
        burnFee = sellBurnFee;
        totalFees = devFee + liquidityFee + marketingFee + burnFee;
    }
    
    function setFree() private {
        devFee = 0;
        liquidityFee = 0;
        marketingFee = 0;
        burnFee = 0;
        totalFees = 0;
    }

    function shouldSwapBack(address recipient) internal view returns (bool) {
        return msg.sender != pair
        && !inSwap
        && swapEnabled
        && _balances[address(this)] >= swapThreshold
        && recipient == pair;
    }
    
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {   
        approve(address(router), tokenAmount);
        router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            marketingFeeReceiver,
            block.timestamp
        );
    }

    function swapTokensForBNBToReceiver(uint256 tokenAmount, address receiver) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WCRO;
        approve(address(router), tokenAmount);
        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(receiver),
            block.timestamp
        );
    }

    function swapBack() internal swapping {
        uint256 contractBalance = balanceOf(address(this));
        
        // Halve the amount of liquidity tokens
        uint256 tokensForLiquidity = contractBalance * liquidityFee / totalFees / 2;
        uint256 amountToSwapForBNB = contractBalance - tokensForLiquidity;

        swapTokensForBNB(amountToSwapForBNB); 
        
        uint256 bnbBalance = address(this).balance;
        uint256 totalBNBFee = totalFees - (liquidityFee / (2));        
        uint256 bnbForMarketing = bnbBalance * marketingFee / (totalBNBFee);
        uint256 bnbForDev = bnbBalance * devFee / (totalBNBFee);
        uint256 bnbForLiquidity = bnbBalance - bnbForMarketing - bnbForDev;
        
        bool success;
        if(bnbForMarketing > 0) {
            (success,) = address(marketingFeeReceiver).call{value: bnbForMarketing}("");
            require(success, "dev: transfer to marketing failed!");
        }
        if(bnbForDev > 0) {
            (success,) = address(teamFeeReceiver).call{value: bnbForDev}("");
            require(success, "dev: transfer to dev and team failed!");
        }
        
        addLiquidity(tokensForLiquidity, bnbForLiquidity);
        emit AutoLiquify(tokensForLiquidity, bnbForLiquidity);
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WCRO;
        approve(address(router), tokenAmount);
        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function buyTokens(uint256 amount, address to) internal swapping {
        address[] memory path = new address[](2);
        path[0] = WCRO;
        path[1] = address(this);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0,
            path,
            to,
            block.timestamp
        );
    }

    function launched() internal view returns (bool) {
        return launchedAt != 0;
    }

    function launch() internal {
        launchedAt = block.number;
    }

    function setTxLimit(uint256 amount) external authorized {
        require(amount >= _totalSupply / 1000);
        _maxTxAmount = amount;
    }

   function setMaxWallet(uint256 amount) external onlyOwner() {
        require(amount >= _totalSupply / 1000 );
        _maxWalletSize = amount;
    }    

    function setIsFeeExempt(address holder, bool exempt) external authorized {
        isFeeExempt[holder] = exempt;
    }

    function setIsTxLimitExempt(address holder, bool exempt) external authorized {
        isTxLimitExempt[holder] = exempt;
    }
    
    function updateBuyFees(uint256 _marketingFee, uint256 _devFee, uint256 _liquidityFee) external onlyOwner {
        buyMarketingFee = _marketingFee;
        buyDevFee = _devFee;
        buyLiquidityFee = _liquidityFee;
        buyTotalFees = buyDevFee + buyLiquidityFee + buyMarketingFee;
        require(buyTotalFees <= 30, "Must keep fees at 30% or less");
    }

    // Only owner can change fees. Max possibles fees 25%.
    function updateSellFees(uint256 _marketingFee, uint256 _sellDevFee, uint256 _liquidityFee, uint256 _sellBurnFee) external onlyOwner {
        sellMarketingFee = _marketingFee;
        sellDevFee = _sellDevFee;
        sellLiquidityFee = _liquidityFee;
        sellBurnFee = _sellBurnFee;
        sellTotalFees = sellDevFee + sellLiquidityFee + sellMarketingFee + sellBurnFee;
        require(sellTotalFees <= 30, "Must keep fees at 30% or less");
    }

    function setTxFeeReceiver(address _marketingFeeReceiver, address _teamFeeReceiver) external authorized {
        marketingFeeReceiver = _marketingFeeReceiver;
        teamFeeReceiver = _teamFeeReceiver;
    }
    function setNodesFeeReceiver(address _treasuryWallet, address _reservoirWallet, address _rewardsWallet) external authorized {
        treasuryWallet = _treasuryWallet;
        reservoirWallet = _reservoirWallet;
        rewardsWallet = _rewardsWallet;
    }

    function setSwapBackSettings(bool _enabled, uint256 _amount) external authorized {
        swapEnabled = _enabled;
        swapThreshold = _amount;
    }

    function manualSend() external authorized {
        uint256 contractETHBalance = address(this).balance;
        payable(marketingFeeReceiver).transfer(contractETHBalance);
    }

    function transferForeignToken(address _token) public authorized {
        require(_token != address(this), "Can't let you take all native token");
        uint256 _contractBalance = IBEP20(_token).balanceOf(address(this));
        payable(marketingFeeReceiver).transfer(_contractBalance);
    }
        
    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
    }

    function getLiquidityBacking(uint256 accuracy) public view returns (uint256) {
        return accuracy.mul(balanceOf(pair).mul(2)).div(getCirculatingSupply());
    }

    function isOverLiquified(uint256 target, uint256 accuracy) public view returns (bool) {
        return getLiquidityBacking(accuracy) > target;
    }

    // Only owner can change fees. Max possibles fees 30%.
    function updateNodesFees(uint256 _rewardsDistribution, uint256 _treasuryFee, uint256 _reservoirFee) external onlyOwner {
        require((_rewardsDistribution + _treasuryFee + _reservoirFee) < 100, "dev: the sum must be less than 100!");
        require(_rewardsDistribution >= 70, "dev: you must keep rewards at least 70%!");
        require(treasuryFee > 0, "dev: you must enter a positive value");
        require(reservoirFee > 0, "dev: you must enter a positive value");
        rewardsDistribution = _rewardsDistribution;
        treasuryFee = _treasuryFee;
        reservoirFee = _reservoirFee;
        emit NodeFeesUpdated(_rewardsDistribution, _treasuryFee, _reservoirFee);
    }

    function setEarnings(uint256 _earningNode) external onlyOwner returns (bool){
        nodes.setEarnings(_earningNode);
        return true;
    }

    function getEarningNode(uint256 _date) public view returns (uint256 Node) {
        return (nodes.getEarningNode(_date));
    }

    function getEarningNodeNow() public view returns (uint256 Node) {
        return (nodes.getEarningNode(block.timestamp));
    }

    function getENSetDate() public view returns (uint256 Node) {
        return (nodes.eNSetDate());
    }

    function getNodeRewardsActive() public view returns (bool buyNodesActive, bool rewardsActive) {
        return (nodes.buyNodesActive(), nodes.rewardsActive());
    }

    function setNodeRewardsActive(bool _buyNodesActive, bool _rewardsActive) external onlyOwner returns (bool){
        nodes.setNodeRewardsActive(_buyNodesActive, _rewardsActive);
        return true;
    }

    function transferAndSwap(address sender, uint256 amount) internal{
        _allowances[sender][address(this)] = amount;
        inSwap = true;
        _basicTransfer(sender, address(this), amount);
        swapTokensForBNBToReceiver(amount, sender);
        inSwap = false;
        emit Swap(amount, sender);   
    } 

    function buyNodes(uint256 amount) public returns (bool){
        uint256 costs = nodes.pricePerNode() * amount;
        require(_balances[msg.sender] >= costs, "dev: you don't have enough tokens for the needed nodes!");
        uint256 rewards = costs / 100 * rewardsDistribution;
        uint256 treasury = costs / 100 * treasuryFee;
        uint256 reservoir = costs / 100 * reservoirFee;
        uint256 burn = costs - rewards - treasury - reservoir;
        uint256 balanceTreasury = _balances[treasuryWallet];
        if(balanceTreasury > swapThreshold) {
            transferAndSwap(treasuryWallet, balanceTreasury);
        }
        uint256 balanceReservoir = _balances[reservoirWallet];
        if(balanceReservoir > swapThreshold) {
            transferAndSwap(reservoirWallet, balanceReservoir);
        }
        _balances[msg.sender] -= costs;
        _balances[rewardsWallet] += rewards;
        _balances[treasuryWallet] += treasury;
        _balances[reservoirWallet] += reservoir;
        _balances[DEAD] += burn;
        emit Transfer(msg.sender, address(rewardsWallet), rewards);
        emit Transfer(msg.sender, address(treasuryWallet), treasury);
        emit Transfer(msg.sender, address(reservoirWallet), reservoir);
        emit Transfer(msg.sender, address(DEAD), burn);
        nodes.buyNodes(msg.sender, amount);
        return true;
    }

    function getUserNodes(address user) public view returns (uint256 Count){
        return nodes.getUserNodes(user);
    }

    function getUserNodeInfo(address user, uint256 id) external view returns(uint256 buildDate, uint256 count, uint256 lastClaimed, uint256 claimedPerNode, bool active){
        return (nodes.getUserNodeInfo(user, id));
    }

    function getAllNodes() external view returns (uint256) {
        return nodes.allNodes();
    }

    function getPricePerNode() external view returns (uint256) {
        return nodes.pricePerNode();
    }

    function getClaimableTokens(address user) external view returns (uint256) {
        return nodes.getClaimableTokens(user);
    }

    function getUserClaimInfo(address user) external view returns (uint256 lastClaimed, uint256 claimedCrao) {
        return nodes.getUserClaimInfo(user);
    }

    function claimTokens() public returns (bool) {
        uint256 burnAmount = 0;
        bool burn = false;
        (uint256 lastClaimed, ) =  nodes.getUserClaimInfo(msg.sender);
        if(lastClaimed < 1) {
            return false;
        } else if ((lastClaimed + 7 days) > block.timestamp) {
            burn = true;
        }
        uint256 claimableTokens = nodes.getClaimableTokens(msg.sender);
        if(burn) {
            burnAmount = claimableTokens / 10;
            claimableTokens -= burnAmount;
        }
        
        if(claimableTokens > 0){
            uint256 cT = nodes.claimTokens(msg.sender);
            require((claimableTokens + burnAmount) == cT, "dev: the amount claimable tokens is not equal!");
            if (burn) {
                if(balanceOf(rewardsWallet) >= burnAmount) {
                    _allowances[rewardsWallet][DEAD] = burnAmount;
                    inSwap = true;
                    _basicTransfer(rewardsWallet, DEAD, burnAmount);
                    inSwap = false;
                } else {
                    _totalSupply = _totalSupply + burnAmount;
                    _balances[DEAD] = _balances[DEAD] + burnAmount;
                    emit Transfer(ZERO, DEAD, burnAmount);
                }
                emit Burn(burnAmount, DEAD);
            }
            if(balanceOf(rewardsWallet) >= claimableTokens) {
                _allowances[rewardsWallet][msg.sender] = claimableTokens;
                inSwap = true;
                _basicTransfer(rewardsWallet, msg.sender, claimableTokens);
                inSwap = false;
            } else {
                _totalSupply = _totalSupply + claimableTokens;
                _balances[msg.sender] = _balances[msg.sender] + claimableTokens;
                emit Transfer(ZERO, msg.sender, claimableTokens);
            }
            emit ClaimRewards(claimableTokens, msg.sender);
        }
        return true;
    }  
    event AutoLiquify(uint256 amountToken, uint256 amountBNB);
}
