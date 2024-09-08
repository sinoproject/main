// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19.0;

import {Math} from "@openzeppelin/contracts@4.7.3/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable@4.7.3/proxy/utils/Initializable.sol";

import {ICasino} from "./ICasino.sol";
import {ICasinoRandomizerProxy} from "./ICasinoRandomizerProxy.sol";
import {ICasinoToken} from "./ICasinoToken.sol";

error ErrBetAmountHigherThanSenderBalance();
error ErrBetIdAlreadyExists();
error ErrBettingNotEnabled();
error ErrCallerMustBeRandomizerProxyContract();
error ErrInvalidBetAmount();
error ErrInvalidDecimalStyleOddsX100();
error ErrInvalidRandomNumber();
error ErrRandomizerCallbackFeeNotSent();
error ErrReentrantCall();
error ErrWouldExceedMaxPayout();

contract Casino is ICasino, Initializable, Ownable {

    ICasinoToken public casinoToken;
    ICasinoRandomizerProxy public casinoRandomizerProxy;

    uint256 constant public houseEdgePcX100 = 2 * 100; // 2%
    uint256 constant public minDecimalOddsX100 = 110; // 1.10 decimal odds
    uint256 constant public maxDecimalOddsX100 = 100 * 100; // 100.00 decimal odds (higher value creates problems with random number calc)
    uint256 constant public minBetAmount = 1 * 10**9; // 1 gwei
    uint256 constant public jackpotRandomNumberThreshold = 100; // 1% chance of winning the jackpot: 100 / 10000 (highest random number)

    bool public isBettingEnabled = true;
    uint256 public maxPayout = 100000 * 10**18; // initial value: 100,000 tokens
    uint256 public randomizerCallbackFee = 0;
    uint256 public jackpotFund = 0;
    uint8 private reentrancyLock = 1;

    struct Bet {
        uint256 id;
        address bettor;
        uint256 amount;
        uint256 decimalStyleOddsX100;
        address agent;
    }

    mapping(uint256 => Bet) public bets;

    // Events
    event BetPlaced(
        uint256 indexed id,
        address indexed bettor,
        uint256 amount,
        uint256 decimalStyleOddsX100,
        address indexed agent,
        uint256 reqRandomizerCallbackFee,
        uint256 updatedBettorTokenBalance,
        uint256 updatedBettorEthBalance
    );

    event BetSettled(
        uint256 indexed id,
        address indexed bettor,
        uint256 amount,
        uint256 decimalStyleOddsX100,
        address indexed agent,
        bool isWon,
        uint256 actualProbabilityPcX100,
        uint256 randomNumber,
        uint256 mintToBettor,
        uint256 mintToJackpotFund,
        uint256 mintToAgent,
        uint256 updatedBettorTokenBalance,
        uint256 updatedJackpotFund,
        uint256 jackpotAmountWon
    );

    event BetVoid(
        uint256 indexed id,
        address indexed bettor,
        uint256 amount,
        address indexed agent,
        uint256 updatedBettorTokenBalance
    );

    event JackpotWon(
        address indexed bettor,
        uint256 amount,
        uint256 relatedBetId
    );

    event SettingsChanged(
        bool isBettingEnabled,
        uint256 houseEdgePcX100,
        uint256 minDecimalOddsX100,
        uint256 maxDecimalOddsX100,
        uint256 minBetAmount,
        uint256 maxPayout,
        uint256 randomizerCallbackFee,
        uint256 jackpotRandomNumberThreshold
    );

    // Modifiers
    modifier reentrancyGuard() {
        if(reentrancyLock != 1) {
            revert ErrReentrantCall();
        }
        reentrancyLock = 2;
        _;
        reentrancyLock = 1;
    }

    // Functions
    function initialize(address casinoTokenAddress) public payable initializer onlyOwner {
        casinoToken = ICasinoToken(casinoTokenAddress);
    }

    function setRandomizerProxyAddress(address value) public onlyOwner {
        casinoRandomizerProxy = ICasinoRandomizerProxy(value);
        updateRandomizerCallbackFee();
    }

    function setIsBettingEnabled(bool value) public onlyOwner {
        isBettingEnabled = value;
        emitSettingsChanged();
    }

    function updateRandomizerCallbackFee() public {
        uint256 prev = randomizerCallbackFee;
        randomizerCallbackFee = casinoRandomizerProxy.estimateCallbackFee();
        if (randomizerCallbackFee != prev) {
            emitSettingsChanged();
        }
    }

    function setMaxPayout(uint256 value) public onlyOwner {
        uint256 onePercentOfTokenSupply = casinoToken.totalSupply() / 100;
        require(value > 0 && value <= onePercentOfTokenSupply);
        maxPayout = value;
        emitSettingsChanged();
    }

    function getBetById(uint256 id) public view returns(Bet memory) {
        return bets[id];
    }

    // Please note that returns(uint256) makes it easy for unit tests to obtain the betId
    function placeBet(uint256 betAmount, uint256 decimalStyleOddsX100, address agent) public payable reentrancyGuard returns(uint256) {

        if (isBettingEnabled != true) {
            revert ErrBettingNotEnabled();
        }
        if (decimalStyleOddsX100 < minDecimalOddsX100 || decimalStyleOddsX100 > maxDecimalOddsX100) {
            revert ErrInvalidDecimalStyleOddsX100();
        }
        if (betAmount < minBetAmount) {
            revert ErrInvalidBetAmount();
        }
        uint256 payoutIfWin = (betAmount * decimalStyleOddsX100) / 100;
        if (payoutIfWin > maxPayout) {
            revert ErrWouldExceedMaxPayout();
        }

        // Require ETH fee to cover bet settling transaction costs
        if (msg.value < randomizerCallbackFee) {
            revert ErrRandomizerCallbackFeeNotSent();
        }

        // Transfer betAmount from bettor to current contract
        if (casinoToken.balanceOf(msg.sender) < betAmount) {
            revert ErrBetAmountHigherThanSenderBalance();
        }
        casinoToken.transferOnBehalf(msg.sender, address(this), betAmount);

        // Ask randomiser to generate random number, send msg.value to cover callback costs
        uint256 betId = casinoRandomizerProxy.makeRequest{ value: msg.value }();
        if (bets[betId].id > 0) {
            revert ErrBetIdAlreadyExists();
        }

        // Save bet
        Bet memory bet = Bet(
            betId,
            msg.sender,
            betAmount,
            decimalStyleOddsX100,
            agent
        );
        bets[betId] = bet;

        // Burn the betAmount from token supply
        casinoToken.burn(address(this), betAmount);
        emitBetPlaced(bet, randomizerCallbackFee);

        return betId;
    }

    function settleBet(uint256 betId, uint256 randomNumber) external {

        if (msg.sender != address(casinoRandomizerProxy)) {
            revert ErrCallerMustBeRandomizerProxyContract();
        }
        if (bets[betId].id == 0) {
            return;
        }
        if (randomNumber < 1 || randomNumber > 10000) {
            revert ErrInvalidRandomNumber();
        }

        Bet memory bet = bets[betId];
        uint256 actualProbabilityPcX100 = calculateActualProbabilityPcX100(bet.decimalStyleOddsX100);
        bool isBetWon = (randomNumber <= actualProbabilityPcX100);

        // Bet has lost
        if (!isBetWon) {
            emitBetSettled(
                bet,
                isBetWon,
                actualProbabilityPcX100,
                randomNumber,
                0,
                0,
                0,
                0
            );
            delete bets[betId];
            return;
        }

        // Bet has won, so mint tokens: to pay bettor, to jackpot fund, to agent
        uint256 decimalStyleTrueOddsX10000 = (10000*10000) / actualProbabilityPcX100; // e.g 15076 (1.5076)
        uint256 mintHypotheticalBasedOnTrueOdds = (bet.amount * decimalStyleTrueOddsX10000) / 10000; // e.g. 1507 if bet.amount=1000
        uint256 mintToBettor = (bet.amount * bet.decimalStyleOddsX100) / 100; // e.g. 1500
        uint256 houseEdgeAmount = mintHypotheticalBasedOnTrueOdds - mintToBettor;
        uint256 mintToJackpotFund = houseEdgeAmount / 4; // ~25% of house edge... e.g. floor(7/4) --> 1
        casinoToken.mint(bet.bettor, mintToBettor);
        casinoToken.mint(address(this), mintToJackpotFund);
        jackpotFund += mintToJackpotFund;

        uint256 mintToAgent = 0;
        if (bet.agent != address(0)) {
            mintToAgent = houseEdgeAmount / 4; // ~25% of house edge... e.g. floor(7/4) --> 1
            casinoToken.mint(bet.agent, mintToAgent);
        }

        // If randomNumber not higher than threshold then bettor has also won the jackpot
        uint256 jackpotAmountWon = 0;
        if (randomNumber <= jackpotRandomNumberThreshold) {
            jackpotAmountWon = jackpotFund;
            jackpotFund = 0;
            casinoToken.transfer(bet.bettor, jackpotAmountWon);
            emitJackpotWon(
                bet,
                jackpotAmountWon
            );
        }

        emitBetSettled(
            bet,
            isBetWon,
            actualProbabilityPcX100,
            randomNumber,
            mintToBettor,
            mintToJackpotFund,
            mintToAgent,
            jackpotAmountWon
        );
        delete bets[betId];
    }

    function voidBet(uint256 betId) public onlyOwner {

        Bet memory bet = bets[betId];
        if (bets[betId].id == 0) {
            return;
        }

        // Delete bet and refund amount to bettor
        address bettor = bet.bettor;
        uint256 amount = bet.amount;
        delete bets[betId];
        casinoToken.mint(bettor, amount);
        emitBetVoid(bet);
    }

    function calculateActualProbabilityPcX100(uint256 decimalStyleOddsX100) public pure returns(uint256) {
        // Actual probability: bettor odds' implied probability MINUS the house edge
        uint256 oddsProbabilityPcX100 = Math.mulDiv(100, 10000, decimalStyleOddsX100); // e.g. 6666 (means 66.66%) if decimal odds = 1.50
        uint256 houseEdgePcpointsX100 = oddsProbabilityPcX100 * houseEdgePcX100 / (100*100); // e.g. 133 (means 1.33 percentage points)
        uint256 actualProbabilityPcX100 = oddsProbabilityPcX100 - houseEdgePcpointsX100; // e.g. 6533 (means 65.33%)
        return actualProbabilityPcX100;
    }

    function emitBetPlaced(Bet memory bet, uint256 reqRandomizerCallbackFee) internal {
        uint256 updatedBettorTokenBalance = casinoToken.balanceOf(bet.bettor);
        uint256 updatedBettorEthBalance = address(bet.bettor).balance;
        emit BetPlaced(
            bet.id,
            bet.bettor,
            bet.amount,
            bet.decimalStyleOddsX100,
            bet.agent,
            reqRandomizerCallbackFee,
            updatedBettorTokenBalance,
            updatedBettorEthBalance
        );
    }

    function emitBetSettled(
        Bet memory bet,
        bool isBetWon,
        uint256 actualProbabilityPcX100,
        uint256 randomNumber,
        uint256 mintToBettor,
        uint256 mintToJackpotFund,
        uint256 mintToAgent,
        uint256 jackpotAmountWon
    ) internal {
        uint256 updatedBettorTokenBalance = casinoToken.balanceOf(bet.bettor);
        emit BetSettled(
            bet.id,
            bet.bettor,
            bet.amount,
            bet.decimalStyleOddsX100,
            bet.agent,
            isBetWon,
            actualProbabilityPcX100,
            randomNumber,
            mintToBettor,
            mintToJackpotFund,
            mintToAgent,
            updatedBettorTokenBalance,
            jackpotFund,
            jackpotAmountWon
        );
    }

    function emitBetVoid(Bet memory bet) internal {
        uint256 updatedBettorTokenBalance = casinoToken.balanceOf(bet.bettor);
        emit BetVoid(
            bet.id,
            bet.bettor,
            bet.amount,
            bet.agent,
            updatedBettorTokenBalance
        );
    }

    function emitJackpotWon(Bet memory bet, uint256 amount) internal {
        emit JackpotWon(
            bet.bettor,
            amount,
            bet.id
        );
    }

    function emitSettingsChanged() internal {
        emit SettingsChanged(
            isBettingEnabled,
            houseEdgePcX100,
            minDecimalOddsX100,
            maxDecimalOddsX100,
            minBetAmount,
            maxPayout,
            randomizerCallbackFee,
            jackpotRandomNumberThreshold
        );
    }
}
