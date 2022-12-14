pragma solidity >= "0.8.0";

import {Old} from "./Old.sol";
import {Strategies} from "./Strategies.sol";
import {IMockStake} from "./mock/IMockStake.sol";
import {MockLido} from "./mock/MockLido.sol";
import {MockRocketpool} from "./mock/MockRocketpool.sol";
import {MockUniSwapV2} from "./mock/MockUniSwapV2.sol";
import {IStarknetCore} from "./IStarknetCore.sol";

enum ChickenState {
    Egg,
    In,
    Out
}

contract Treasury {
    uint256 public lockedBucket;
    uint256 public recurrentAmount;
    uint256 public reserveBucket;
    uint256 public FundVirtualOldBalance;
    uint256 public StrategistVirtualOldBalance;
    uint256 public StrategistReserveClaim;
    ChickenState public StrategistChickenState;
    uint256 public chosenStrategy;
    mapping(uint256 => uint256) public strategyPledge;
    bool public StrategyPledgeLocked;
    uint256 public lockPeriod;
    uint256 public endPeriod;
    Old public old;
    Strategies public strategies;
    IMockStake[] public assets;
    IStarknetCore public starknetCore;

    event SubmitedStrategy(uint256 id, address strategist);

    uint256 constant MESSAGE_DEPOSIT = 0;
    uint256 constant MESSAGE_SET_STRATEGY = 1;
    uint256 constant MESSAGE_START = 2;

    constructor() {
        MockLido mockLido = new MockLido();
        MockRocketpool mockRocketpool = new MockRocketpool();
        MockUniSwapV2 mockUniSwapV2 = new MockUniSwapV2();
        IMockStake[] memory _assets = new IMockStake[](3);
        _assets[0]=IMockStake(address(mockLido));
        _assets[1]=IMockStake(address(mockRocketpool));
        _assets[2]=IMockStake(address(mockUniSwapV2));
        old = new Old();
        strategies = new Strategies();
        assets = _assets;
        starknetCore = IStarknetCore(0xa4eD3aD27c294565cB0DCc993BDdCC75432D498c);

        StrategyPledgeLocked = true;
        lockPeriod = 1669779861;
        endPeriod = 2298253461;
    }

    function createStrategy(Strategies.Strategy memory strategy) public payable returns (uint256) {
        require(msg.value > (0.02 ether));
        uint256 id = strategies.mint(msg.sender, strategy);
        strategyPledge[id] = msg.value;
        emit SubmitedStrategy(id, msg.sender);
        return id;
    }

    function depositFundsFromL2(uint256 l2ContractAddress, uint256 amount) public returns (bool) {
        uint256[] memory payload = new uint256[](2);
        payload[0] = MESSAGE_DEPOSIT;
        payload[1] = amount;

        starknetCore.consumeMessageFromL2(l2ContractAddress, payload);

        lockedBucket += amount;
        recurrentAmount = amount;

        // update FundVirtualOldBalance += amount
        FundVirtualOldBalance += amount;

        return true;
    }

    function setStrategyFromL2(uint256 l2ContractAddress, uint256 strategyId) public {
        uint256[] memory payload = new uint256[](2);
        payload[0] = MESSAGE_SET_STRATEGY;
        payload[1] = strategyId;

        starknetCore.consumeMessageFromL2(l2ContractAddress, payload);

        chosenStrategy = strategyId;
        reserveBucket = strategyPledge[chosenStrategy];
        StrategistReserveClaim = strategyPledge[chosenStrategy];
        StrategistVirtualOldBalance += strategyPledge[chosenStrategy];
        strategyPledge[chosenStrategy] = 0;
        StrategyPledgeLocked = false;
    }

    function applyStrategyFromL2(uint256 l2ContractAddress) public {
        uint256[] memory payload = new uint256[](1);
        payload[0] = MESSAGE_START;

        starknetCore.consumeMessageFromL2(l2ContractAddress, payload);

        //currentInvestment = lockedBucket;
        uint256 currentInvestment = lockedBucket;
        //get erc721 strategy array
        uint256[3] memory strategy;

        strategy = strategies.getStrategy(chosenStrategy);

        uint256 i = 0;
        uint256 assets_length = assets.length;
        // stake() foreach asset
        for (; i < assets_length; ++i) {
            assets[i].stake{value: (currentInvestment * strategy[i]) / 100}();
        }
    }

    function rebalance(uint256[3] memory sell, uint256[3] memory buy, uint256 yieldAmount) public {
        //sell for first array amounts

        uint256 i = 0;
        uint256 assets_length = assets.length;
        for (; i < assets_length; ++i) {
            assets[i].unstake(sell[i]);
        }
        //buy for secund array amounts  + erc721 strategy array with recurrentAmount

        i = 0;
        for (; i < assets_length; ++i) {
            assets[i].stake{value: buy[i]}();
        }
        //transfer yieldAmount to reserve

        reserveBucket += yieldAmount;
        // update FundVirtualOldBalance += 0.8 * yieldAmount
        FundVirtualOldBalance += (80 * yieldAmount) / 100;
        // update StrategistVirtualOldBalance += 0.2 * yieldAmount
        StrategistVirtualOldBalance += (20 * yieldAmount) / 100;
    }

    function chickenIn() public {
        require(block.timestamp > lockPeriod);
        require(msg.sender == strategies.ownerOf(chosenStrategy));
        require(StrategistChickenState == ChickenState.Egg);

        StrategistChickenState = ChickenState.In;

        StrategistReserveClaim = 0;

        uint256 balance = StrategistVirtualOldBalance;

        old.mint(msg.sender, balance);

        StrategistVirtualOldBalance = 0;
    }

    function chickenOut() public {
        require(block.timestamp > lockPeriod);
        require(msg.sender == strategies.ownerOf(chosenStrategy));
        require(StrategistChickenState == ChickenState.Egg);

        StrategistChickenState = ChickenState.Out;
        payable(msg.sender).transfer(StrategistReserveClaim);

        StrategistReserveClaim = 0;
        StrategistVirtualOldBalance = 0;
    }

    function claimOld(uint256 amount) public {
        uint256 virtualOld = FundVirtualOldBalance + StrategistVirtualOldBalance;
        uint256 oldCurrentSupply = old.totalSupply();

        uint256 etherToTransfer = (reserveBucket / virtualOld + oldCurrentSupply) * amount;

        reserveBucket -= etherToTransfer;

        old.transfer(address(this), amount);
        payable(msg.sender).transfer(etherToTransfer);
    }

    function retire() public {
        require(block.timestamp > endPeriod);
        //vende assets todos
        uint256 totalSaleETHAmount = 100; //sell();

        payable(strategies.ownerOf(chosenStrategy)).transfer(StrategistReserveClaim);

        totalSaleETHAmount -= StrategistReserveClaim;

        StrategistReserveClaim = 0;

        totalSaleETHAmount -= lockedBucket;

        reserveBucket += totalSaleETHAmount;

        // update FundVirtualOldBalance += 0.8 * totalSaleETHAmount
        FundVirtualOldBalance += (80 * totalSaleETHAmount) / 100;
        // update StrategistVirtualOldBalance += 0.2 * totalSaleETHAmount
        StrategistVirtualOldBalance += (20 * totalSaleETHAmount) / 100;

        uint256 virtualOld = FundVirtualOldBalance + StrategistVirtualOldBalance;
        uint256 oldSupply = old.totalSupply();

        uint256 etherToTransferFund = (reserveBucket / virtualOld + oldSupply) * FundVirtualOldBalance;
        uint256 etherToTransferStrategist = (reserveBucket / virtualOld + oldSupply) * StrategistVirtualOldBalance;

        reserveBucket -= etherToTransferFund;
        reserveBucket -= etherToTransferStrategist;

        //bridge para l2 etherToTransferFund
        payable(strategies.ownerOf(chosenStrategy)).transfer(etherToTransferStrategist);

        FundVirtualOldBalance = 0;
        StrategistVirtualOldBalance = 0;
    }

    function unpledge(uint256 id) public {
        require(StrategyPledgeLocked == false);
        require(msg.sender == strategies.ownerOf(id));
        strategies.burn(id);
        uint256 amount = strategyPledge[chosenStrategy];
        payable(msg.sender).transfer(amount);
        strategyPledge[chosenStrategy] = 0;
    }
}
