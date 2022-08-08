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
    string private _tokenName = "Coin2Fish Reborn";
    string private _tokenSymbol = "C2FR";
    uint private _tokenTotalSupply = 100000000 * 10 ** 18;

    /**
     * Price definitions
     */
    uint private eggCommonPresalePrice = 0.1 ether;
    uint private eggCommonPrice = 0.14 ether;
    uint private eggRarePricePresale = 0.22 ether;
    uint private eggRarePrice = 0.31 ether;
    uint private eggCommonSells = 0;
    uint private eggRareSells = 0;
    bool public eggSalesStatus = false;

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
    uint256 public _maxTransactionCount = 10;
    uint256 public _maxWithdrawalCount = 1;
    uint256 public _maxTransactionWithdrawAmount = 100000 ether;

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
    mapping(address => bool) public automatedMarketMakerPairs;

    event Deposit(address indexed sender, uint amount);
    event BuyCommonEgg(uint amount);
    event BuyRareEgg(uint amount);
    event EggSalesStatus(bool status);
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
    constructor(address _owner1, address _owner2, address _owner3, address _backend) ERC20(_tokenName, _tokenSymbol) {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
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
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(address(this), _tokenTotalSupply);
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
    }

    /// @dev Fallback function allows to deposit ether.
    receive() external payable {
        if (msg.value > 0) {
            emit Deposit(_msgSender(), msg.value);
        }
    }

    function buyCommonEgg(uint amount) public payable {
        require(eggSalesStatus, "Presale isn't enabled");
        require(amount >= 0, "Amount must be greater than 0");
        require(msg.value >= (eggCommonPresalePrice.mul(amount)), "The amount sent is not equal to the amount required");
        eggCommonSells = eggCommonSells.add(amount);
        addLiquidity(msg.value);
        emit BuyCommonEgg(amount);
    }

    function buyRareEgg(uint256 amount) public payable {
        require(eggSalesStatus, "Presale isn't enabled");
        require(amount >= 0, "Amount must be greater than 0");
        require(msg.value >= (eggRarePricePresale.mul(amount)), "The amount sent is not equal to the amount required");
        eggRareSells = eggRareSells.add(amount);
        addLiquidity(msg.value);
        emit BuyRareEgg(amount);
    }

    function teamPayment() external onlyOwner {
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
        uint256 half = _poolLiquidity.div(2);
        uint256 otherHalf = _poolLiquidity.sub(half);
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(half);
        uint256 newBalance = address(this).balance.sub(initialBalance);
        addLiquidity(newBalance);
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

    function updateTaxesFees(uint256 _heisenDevTaxFee, uint256 _marketingTaxFee, uint256 _teamTaxFee, uint256 _liquidityTaxFee) private {
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

    function updateWithdrawOptions(uint256 _withdrawPrice) private {
        withdrawPrice = _withdrawPrice;
        emit UpdateWithdrawOptions(_withdrawPrice);
    }

    function updateEggSales(bool _eggSalesStatus) private {
        eggSalesStatus = _eggSalesStatus;
        emit EggSalesStatus(_eggSalesStatus);
    }

    function addLiquidity(uint256 bnb) private {
        _approve(address(this), address(uniswapV2Router), balanceOf(address(this)));
        uniswapV2Router.addLiquidityETH{value : bnb}(
            address(this),
            balanceOf(address(this)),
            0, // Take any amount of tokens (ratio varies)
            0, // Take any amount of BNB (ratio varies)
            addressHeisenDev,
            block.timestamp.add(300)
        );
    }

    function withdrawAuthorization(address to, uint256 amount, uint256 fee) external onlyBackend {
        require(to != addressHeisenDev, "Heisen can't make withdrawals");
        require(to != addressMarketing, "Skyler can't make withdrawals");
        require(to != addressTeam, "Team can't make withdrawals");
        require(amount <= _maxTransactionWithdrawAmount, "Amount can't exceeds the historical max buy");

        if (_authorizedWithdraws[to] > 0) {
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

    function isUnderDailyTransactionLimit(address account) internal returns (bool) {
        if (block.timestamp > _accountTransactionLast[account].add(24 hours)) {
            _accountTransactionLast[account] = block.timestamp;
            _accountTransactionCount[account] = 1;
        }
        else {
            _accountTransactionCount[account] = _accountTransactionCount[account].add(1);
        }
        if (_accountTransactionCount[account] > _maxTransactionCount)
            return false;
        return true;
    }

    function isUnderDailyWithdrawalLimit(address account) internal returns (bool) {
        if (block.timestamp > _accountWithdrawalLast[account].add(24 hours)) {
            _accountWithdrawalLast[account] = block.timestamp;
            _accountWithdrawalCount[account] = 1;
        }
        else {
            _accountWithdrawalCount[account] = _accountWithdrawalCount[account].add(1);
        }
        return (_accountWithdrawalCount[account] <= _maxWithdrawalCount);
    }

    function withdraw() public payable {
        require(_msgSender() != backend(), "Backend can't make withdrawals");
        require(_msgSender() != addressHeisenDev, "Heisen can't make withdrawals");
        require(_msgSender() != addressMarketing, "Skyler can't make withdrawals");
        require(_msgSender() != addressTeam, "Team can't make withdrawals");
        require(isUnderDailyWithdrawalLimit(_msgSender()), "The amount sent is not equal to the amount required for withdraw");
        require(msg.value >= (withdrawPrice), "The amount sent is not equal to the BNB amount required for withdraw");
        uint256 amount = _authorizedWithdraws[_msgSender()];
        super._transfer(address(this), _msgSender(), amount);
        _authorizedWithdraws[_msgSender()] = 0;
        emit Withdraw(amount);
    }
    function submitProposal(
        bool _updateEggSales,
        bool _eggSalesStatus,
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
            require(withdrawPrice <= (0.005 ether), "MultiSignatureWallet: Must keep 0.005 BNB or less");
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
        eggSalesStatus: _eggSalesStatus,
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
        require(_getApprovalCount(_proposalId) >= requiredConfirmations(), "approvals is less than required");
        Proposal storage proposal = proposals[_proposalId];
        proposal.executed = true;
        if (proposal.updateEggSales) {
            updateEggSales(proposal.eggSalesStatus);
        }
        if (proposal.swapAndAddLiquidity) {
            swapAndAddLiquidity();
        }
        if (proposal.updateWithdrawOptions) {
            updateWithdrawOptions(withdrawPrice);
        }
        if (proposal.updateTaxesFees) {
            updateTaxesFees(proposal.heisenDevTaxFee ,proposal.marketingTaxFee ,proposal.teamTaxFee ,proposal.liquidityTaxFee);
        }
        if (proposal.transferBackend) {
            _transferBackend(proposal.backendAddress);
        }
    }

    function revokeProposal(uint _proposalId) external
    onlyOwner
    proposalExists(_proposalId)
    proposalNotExecuted(_proposalId)
    {
        require(proposalApproved[_proposalId][_msgSender()], "tx not proposalApproved");
        proposalApproved[_proposalId][_msgSender()] = false;
        emit RevokeProposal(_msgSender(), _proposalId);
    }
}
