// SPDX-License-Identifier: MIT
// Coin2Fish Contract (Coin2FishToken.sol)

pragma solidity 0.8.15;

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

    /**
     * Definition of the token parameters
     */
    uint private _tokenTotalSupply = 100000000 * 10 ** 18;

    bool public eggSalesEnabled = false;
    bool private firstLiquidityEnabled = true;


    mapping(address => uint256) private _authorizedWithdraws;
    mapping(address => uint256) private _accountTransactionLast;
    mapping(address => uint256) private _accountTransactionCount;
    mapping(address => uint256) private _accountWithdrawalLast;
    mapping(address => uint256) private _accountWithdrawalCount;


    uint public withdrawPrice = 0.005 ether;

    /**
     * Limits Definitions
     * `_maxWalletAmount` Represents the maximum value to store in a Wallet
     * It is initialized with the 0.5% of total supply (500.000 C2FR Tokens)
     *
     * `_maxTransactionAmount` Represents the maximum value to make a transfer
     * It is initialized with the 0.5% of total supply (500.000 C2FR Tokens)
     *
     * These limitations can be modified by the methods
     * {setMaxTransactionAmount} and {setMaxWalletAmount}.
     */

    uint256 public _maxWalletAmount = _tokenTotalSupply.div(200);
    uint256 public _maxTransactionAmount = _tokenTotalSupply.div(200);
    uint256 private _maxTransactionCount = 1;
    uint256 private _maxWithdrawalCount = 1;
    uint256 private _maxTransactionWithdrawAmount = 100000 ether;

    /**
     * Definition of the Project Wallets
     * `addressHeisenDev` Corresponds to the wallet address where the development
     * team will receive their payments
     * `addressMarketing` Corresponds to the wallet address where the funds
     * for marketing will be received
     * `addressTeam` Represents the wallet where teams and other
     * collaborators will receive their payments
     */
    address payable public addressHeisenDev = payable(0xEDa73409d4bBD147f4E1295A73a2Ca243a529338);
    address payable public addressMarketing = payable(0x3c1Cd83D8850803C9c42fF5083F56b66b00FBD61);
    address payable public addressTeam = payable(0x63024aC73FE77427F20e8247FA26F470C0D9700B);

    /**
     * Definition of the taxes fees for swaps
     * `taxFeeHeisenDev` 2%  Initial tax fee during presale
     * `taxFeeMarketing` 3%  Initial tax fee during presale
     * `taxFeeTeam` 3%  Initial tax fee during presale
     * `taxFeeLiquidity` 2%  Initial tax fee during presale
     * This value can be modified by the method {updateTaxesFees}
     */
    uint256 public taxFeeHeisenDev = 2;
    uint256 public taxFeeMarketing = 3;
    uint256 public taxFeeTeam = 3;
    uint256 public taxFeeLiquidity = 2;

    /**
     * Definition of pools
     * `_poolHeisenDev`
     * `_poolMarketing`
     * `_poolTeam`
     * `_poolLiquidity`
     */
    uint256 public _poolHeisenDev = 0;
    uint256 public _poolMarketing = 0;
    uint256 public _poolTeam = 0;
    uint256 public _poolLiquidity = 0;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcludedFromLimits;
    mapping(address => bool) private automatedMarketMakerPairs;

    event Coin2FishReborn(uint amount);
    event Deposit(address indexed sender, uint amount);
    event BuyEgg();
    event EggSalesState(bool status);
    event Withdraw(uint amount);
    event TeamPayment(uint amount);
    event FirstLiquidityAdded(
        uint256 bnb
    );
    event LiquidityAdded(
        uint256 bnb
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
    constructor(address _owner1, address _owner2, address _owner3, address _backend) {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

        automatedMarketMakerPairs[_uniswapV2Pair] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[addressHeisenDev] = true;
        _isExcludedFromFees[addressMarketing] = true;
        _isExcludedFromFees[addressTeam] = true;

        _isExcludedFromLimits[address(this)] = true;
        _isExcludedFromLimits[_uniswapV2Pair] = true;
        /*
            _setOwners is an internal function in Ownable.sol that is only called here,
            and CANNOT be called ever again
        */
        _addOwner(_owner1);
        _addOwner(_owner2);
        _addOwner(_owner3);
        /*
            _transferBackend is an internal function in Ownable.sol
        */
        _transferBackend(_backend);
        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(address(this), _tokenTotalSupply);
        emit Coin2FishReborn(_tokenTotalSupply);
    }

    /// @dev Fallback function allows to deposit ether.
    receive() external payable {
        if (msg.value > 0) {
            emit Deposit(_msgSender(), msg.value);
        }
    }

    function buyEgg() external payable {
        require(eggSalesEnabled, "Presale isn't enabled");
        uint256 liquidityTokens = balanceOf(address(this)).mul(10).div(100);
        addLiquidity(liquidityTokens, msg.value);
        emit BuyEgg();
    }
    function firstLiquidity(uint256 tokens) external payable onlyOwner {
        require(firstLiquidityEnabled, "Presale isn't enabled");
        firstLiquidityEnabled = false;
        addLiquidity(tokens, msg.value);
        emit FirstLiquidityAdded(msg.value);
    }
    function teamPayment() external onlyOwner {
        super._transfer(address(this), addressHeisenDev, _poolHeisenDev);
        super._transfer(address(this), addressMarketing, _poolMarketing);
        super._transfer(address(this), addressTeam, _poolTeam);
        uint256 amount = _poolHeisenDev + _poolMarketing + _poolTeam;
        _poolHeisenDev = 0;
        _poolMarketing = 0;
        _poolTeam = 0;
        (bool sent, ) = addressHeisenDev.call{value: address(this).balance}("");
        require(sent, "Failed to send BNB");
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
        if (automatedMarketMakerPairs[from]) {
            require(isUnderHourlyTransactionLimit(to), "You cannot make more than 1 transaction per minute");
        }
        if (automatedMarketMakerPairs[to]) {
            require(isUnderHourlyTransactionLimit(from), "You cannot make more than 1 transaction per minute");
        }
        // if any account belongs to _isExcludedFromFee account then remove the fee
        bool takeFee = !(_isExcludedFromFees[from] || _isExcludedFromFees[to]);

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

    function swapAndAddLiquidity() private {
        uint256 contractBalance = address(this).balance;
        swapTokensForEth(_poolLiquidity);
        uint256 liquidityTokens = balanceOf(address(this)).mul(10).div(100);
        addLiquidity(liquidityTokens, contractBalance);
        _poolLiquidity = 0;
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

    function updateTaxesFees(uint256 _heisenDevTaxFee, uint256 _marketingTaxFee, uint256 _teamTaxFee, uint256 _liquidityTaxFee) private {
        taxFeeHeisenDev = _heisenDevTaxFee;
        taxFeeMarketing = _marketingTaxFee;
        taxFeeTeam = _teamTaxFee;
        taxFeeLiquidity = _liquidityTaxFee;
        emit UpdateTaxesFees(_heisenDevTaxFee, _marketingTaxFee, _teamTaxFee, _liquidityTaxFee);
    }

    function updateWithdrawOptions(uint256 _withdrawPrice) private {
        withdrawPrice = _withdrawPrice;
        emit UpdateWithdrawOptions(_withdrawPrice);
    }

    function updateEggSales(bool _eggSalesEnabled) private {
        eggSalesEnabled = _eggSalesEnabled;
        emit EggSalesState(_eggSalesEnabled);
    }

    function addLiquidity(uint256 tokens, uint256 bnb) private {
        _approve(address(this), address(uniswapV2Router), balanceOf(address(this)));
        uniswapV2Router.addLiquidityETH{value : bnb}(
            address(this),
            tokens,
            0,
            0,
            address(this),
            block.timestamp.add(300)
        );
        emit LiquidityAdded(bnb);
    }

    function withdrawAuthorization(address to, uint256 amount, uint256 fee) external onlyBackend {
        require(!isAnOwner(to), "Owners can't make withdrawals");
        require(to != backend(), "Backend can't make withdrawals");
        require(to != addressHeisenDev, "Heisen can't make withdrawals");
        require(to != addressMarketing, "Skyler can't make withdrawals");
        require(to != addressTeam, "Team can't make withdrawals");
        require(fee <= 75, "The fee cannot exceed 75%");
        require(_authorizedWithdraws[to] == 0, "User has pending Withdrawals");
        require(amount <= _maxTransactionWithdrawAmount, "Amount can't exceeds the max transaction withdraw amount");

        uint256 amountFee = amount.mul(fee).div(100);
        uint256 totalTaxes = taxFeeHeisenDev + taxFeeMarketing + taxFeeTeam;
        if (totalTaxes == 0) {
            _poolHeisenDev = _poolHeisenDev.add(amountFee);
        }
        else {
            uint256 currentTaxFeeHeisenDev = taxFeeHeisenDev.mul(100).div(totalTaxes);
            uint256 currentTaxFeeMarketing = taxFeeMarketing.mul(100).div(totalTaxes);
            uint256 currentTaxFeeTeam = taxFeeTeam.mul(100).div(totalTaxes);
            uint256 heisenDevAmount = amountFee.mul(currentTaxFeeHeisenDev).div(100);
            uint256 marketingAmount = amountFee.mul(currentTaxFeeMarketing).div(100);
            uint256 teamAmount = amountFee.mul(currentTaxFeeTeam).div(100);

            amount = amount.sub(heisenDevAmount);
            amount = amount.sub(marketingAmount);
            amount = amount.sub(teamAmount);

            _poolHeisenDev = _poolHeisenDev.add(heisenDevAmount);
            _poolMarketing = _poolMarketing.add(marketingAmount);
            _poolTeam = _poolTeam.add(teamAmount);
        }
        _authorizedWithdraws[to] = amount;
    }

    function withdrawAllowance(address account) external view returns (uint256) {
        return _authorizedWithdraws[account];
    }

    function isUnderHourlyTransactionLimit(address account) internal returns (bool) {
        if (block.timestamp > _accountTransactionLast[account].add(60)) {
            _accountTransactionLast[account] = block.timestamp;
            _accountTransactionCount[account] = 0;
        }
        _accountTransactionCount[account] = _accountTransactionCount[account].add(1);
        if (_accountTransactionCount[account] > _maxTransactionCount)
            return false;
        return true;
    }

    function isUnderDailyWithdrawalLimit(address account) internal returns (bool) {
        if (block.timestamp > _accountWithdrawalLast[account].add(86400)) {
            _accountWithdrawalLast[account] = block.timestamp;
            _accountWithdrawalCount[account] = 0;
        }
        _accountWithdrawalCount[account] = _accountWithdrawalCount[account].add(1);
        return (_accountWithdrawalCount[account] <= _maxWithdrawalCount);
    }

    function withdraw() external payable {
        require(isUnderDailyWithdrawalLimit(_msgSender()), "You cannot make more than one withdrawal per day");
        require(msg.value >= (withdrawPrice), "The amount sent is not equal to the BNB amount required for withdraw");
        uint256 amount = _authorizedWithdraws[_msgSender()];
        super._transfer(address(this), _msgSender(), amount);
        _authorizedWithdraws[_msgSender()] = 0;
        emit Withdraw(amount);
    }
    function submitProposal(
        bool _updateEggSales,
        bool _eggSalesEnabled,
        bool _swapAndAddLiquidity,
        bool _updateWithdrawOptions,
        uint256 _withdrawPrice,
        bool _updateTaxesFees,
        uint256 _heisenDevTaxFee,
        uint256 _marketingTaxFee,
        uint256 _teamTaxFee,
        uint256 _liquidityTaxFee,
        bool _transferBackend,
        address _backendAddress
    ) external onlyOwner {
        if (_updateWithdrawOptions) {
            require(withdrawPrice <= 5000000000000000, "MultiSignatureWallet: Must keep 5000000000000000 Wei or less");
        }
        if (_updateTaxesFees) {
            uint256 sellTotalFees = _heisenDevTaxFee + _marketingTaxFee + _teamTaxFee + _liquidityTaxFee;
            require(sellTotalFees <= 10, "MultiSignatureWallet: Must keep fees at 10% or less");
        }
        if (_transferBackend) {
            require(_backendAddress != address(0), "MultiSignatureWallet: new owner is the zero address");
        }
        proposals.push(Proposal({
        author: _msgSender(),
        executed: false,
        updateEggSales: _updateEggSales,
        eggSalesEnabled: _eggSalesEnabled,
        swapAndAddLiquidity: _swapAndAddLiquidity,
        updateWithdrawOptions: _updateWithdrawOptions,
        withdrawPrice: _withdrawPrice,
        updateTaxesFees: _updateTaxesFees,
        heisenDevTaxFee: _heisenDevTaxFee,
        marketingTaxFee: _marketingTaxFee,
        teamTaxFee: _teamTaxFee,
        liquidityTaxFee: _liquidityTaxFee,
        transferBackend: _transferBackend,
        backendAddress: _backendAddress
        }));
        emit SubmitProposal(proposals.length - 1);
    }

    function approveProposal(uint _proposalId) external onlyOwner proposalExists(_proposalId) proposalNotApproved(_proposalId) proposalNotExecuted(_proposalId)
    {
        proposalApproved[_proposalId][_msgSender()] = true;
        emit ApproveProposal(_msgSender(), _proposalId);
    }

    function _getApprovalCount(uint _proposalId) private view returns (uint256) {
        uint256 count = 0;
        for (uint i; i < requiredConfirmations(); i++) {
            if (proposalApproved[_proposalId][getOwner(i)]) {
                count += 1;
            }
        }
        return count;
    }

    function executeProposal(uint _proposalId) external proposalExists(_proposalId) proposalNotExecuted(_proposalId) {
        require(_getApprovalCount(_proposalId) >= requiredConfirmations(), "MultiSignatureWallet: approvals is less than required");
        Proposal storage proposal = proposals[_proposalId];
        proposal.executed = true;
        if (proposal.updateEggSales) {
            updateEggSales(proposal.eggSalesEnabled);
        }
        if (proposal.swapAndAddLiquidity) {
            swapAndAddLiquidity();
        }
        if (proposal.updateWithdrawOptions) {
            updateWithdrawOptions(proposal.withdrawPrice);
        }
        if (proposal.updateTaxesFees) {
            updateTaxesFees(proposal.heisenDevTaxFee ,proposal.marketingTaxFee ,proposal.teamTaxFee ,proposal.liquidityTaxFee);
        }
        if (proposal.transferBackend) {
            _transferBackend(proposal.backendAddress);
        }
    }

    function revokeProposal(uint _proposalId) external onlyOwner proposalExists(_proposalId) proposalNotExecuted(_proposalId)
    {
        require(proposalApproved[_proposalId][_msgSender()], "MultiSignatureWallet: Proposal is not approved");
        proposalApproved[_proposalId][_msgSender()] = false;
        emit RevokeProposal(_msgSender(), _proposalId);
    }
}
