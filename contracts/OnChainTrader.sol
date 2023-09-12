// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./IClientOrder.sol";
import "./ILiquidityPoolData.sol";

/**
 * @title Example contract to interact with D8X perpetuals on-chain
 * @notice
 * - This contract acts as a trader. The contract is ownable;
 *   Trade executions are permissioned. The margin tokens are required
 *   to be owned by the contract.
 * - D8X Perpetuals use ABDK 128x128 number format. This contract has an interface that uses
 *   a signed decimal-18 convention (decimal number 1 maps to decimal-18 number 1e18).
 * - Ensure the perpetuals-contract is allowed to spend this contracts margin tokens (use approveAmount)
 * - Send orders to order book via postOrder
 * - Check positions using function getMarginAccount
 */


interface OrderBookContractInterface {
    function postOrders(IClientOrder.ClientOrder[] calldata _orders, bytes[] calldata _signatures)
        external;
}

interface PerpetualsContractInterface {
    
    function getMarginAccount(uint24 _perpetualId, address _traderAddress)
        external
        view
        returns (MarginAccount memory);

    function getMaxSignedOpenTradeSizeForPos(
        uint24 _perpetualId,
        int128 _fCurrentTraderPos,
        bool _isBuy
    ) external view returns (int128);

    function getOrderBookAddress(uint24 _perpetualId) external view returns (address);
    function getLiquidityPool(uint8 _poolId)
        external
        view
        returns (ILiquidityPoolData.LiquidityPoolData memory);
}

/**
 * @notice  D8X Perpetual Data structure to store user margin information.
 */
struct MarginAccount {
    int128 fLockedInValueQC; // unrealized value locked-in when trade occurs in
    int128 fCashCC; // cash in collateral currency (base, quote, or quanto)
    int128 fPositionBC; // position in base currency (e.g., 1 BTC for BTCUSD)
    int128 fUnitAccumulatedFundingStart; // accumulated funding rate
    uint64 iLastOpenTimestamp; // timestamp in seconds when the position was last opened/increased
    uint16 feeTbps; // exchange fee in tenth of a basis point
    uint16 brokerFeeTbps; // broker fee in tenth of a basis point
    bytes16 positionId; // unique id for the position (for given trader, and perpetual). Current position, zero otherwise.
}

/**
 * @notice  Data structure to return simplified and relevant margin information.
 */
struct D18MarginAccount {
    int256 lockedInValueQCD18; // unrealized value locked-in when trade occurs: notional amount * price in decimal 18 format
    int256 cashCCD18; // cash in collateral currency (base, quote, or quanto) in decimal 18 format
    int256 positionSizeBCD18; // position in base currency (e.g., 1 BTC for BTCUSD) in decimal 18 format
    bytes16 positionId; // unique id for the position (for given trader, and perpetual). Current position, zero otherwise.
}

contract OnChainTrader is Ownable, ID8XExecutionCallbackReceiver {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event PerpetualOrderSubmitFailed(string reason);
    event PerpetualOrderSubmitSuccess(int256 amountDec18, uint16 leverageTDR);
    event PerpetualAdded(uint24 perpetualId, address lobAddr, address mgnTknAddrOfPool);
    event MarginTokenSent(uint24 perpetualId, address to, uint256 amountDecN);
    event CallbackReceived(bytes32 orderDigest, bool isExecuted);

    address public immutable perpetualProxy;
    int256 private constant DECIMALS = 10**18;
    int128 private constant ONE_64x64 = 2**64;
    int128 private constant MIN_64x64 = -0x80000000000000000000000000000000;
    int128 private constant MAX_64x64 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    int128 private constant TEN_64x64 = 0xa0000000000000000;

    mapping (uint24 => address) public orderBookOfPerpetual;//limit order book addr
    
    // each perpetual is in a pool. Perpetuals in a pool share the margin token
    mapping (uint8 => address) public mgnTknAddrOfPool;

    constructor(
        address _perpetualProxy
    ) Ownable() {
        perpetualProxy = _perpetualProxy;
    }

    /**
     * Anyone add a perpetual. Needs to be set once per perpetual.
     * The function sets the order book address for an existing
     * perpetual-id and ensures the margin token address is stored. 
     * @param _iPerpetualId id of the perpetual to be traded
     */
    function addPerpetual(uint24 _iPerpetualId) external {
        // set order book address
        address lobAddr = PerpetualsContractInterface(perpetualProxy).getOrderBookAddress(_iPerpetualId);
        orderBookOfPerpetual[_iPerpetualId] = lobAddr;
        // register margin token
        uint8 poolId = uint8(_iPerpetualId/100_000);
        if(mgnTknAddrOfPool[poolId] == address(0)) {
            // set margin token address for pool
            ILiquidityPoolData.LiquidityPoolData memory lp = 
                PerpetualsContractInterface(perpetualProxy).getLiquidityPool(poolId);
            mgnTknAddrOfPool[poolId] = lp.marginTokenAddress;
        }
        emit PerpetualAdded(_iPerpetualId, lobAddr, mgnTknAddrOfPool[poolId]);
    }

    /**
     * Approve the margin-token to be spent by perpetuals contract.
     * Required to trade.
     * @param _amount spend amount
     */
    function approveAmountForPerpetualMgnTkn(uint256 _amount, uint24 _iPerpetualId) external {
        uint8 poolId = uint8(_iPerpetualId/100_000);
        address mgnTkn = mgnTknAddrOfPool[poolId];
        require(mgnTkn!=address(0), "set ob addrs");
        IERC20(mgnTkn).approve(perpetualProxy, _amount);
    }

    /**
     * Post an order to the order book. Order will be executed by
     * external "executors".
     * * Available order flags:
     *  uint32 internal constant MASK_CLOSE_ONLY = 0x80000000;
     *  uint32 internal constant MASK_MARKET_ORDER = 0x40000000;
     *  uint32 internal constant MASK_STOP_ORDER = 0x20000000;
     *  uint32 internal constant MASK_FILL_OR_KILL = 0x10000000;
     *  uint32 internal constant MASK_KEEP_POS_LEVERAGE = 0x08000000;
     *  uint32 internal constant MASK_LIMIT_ORDER = 0x04000000;
     * @param _iPerpetualId perpetual id for which we execute
     * @param _amountDec18 signed amount to be traded in base currency
     * @param _leverageTDR leverage two-digit-integer), e.g. 210 for 2.1x leverage
     * @param _flags order-flags, can be left 0 for a market order
     * @return true if posting order succeeded
     */
    function postOrder(uint24 _iPerpetualId, int256 _amountDec18, uint16 _leverageTDR, uint32 _flags) onlyOwner external returns (bool) {
         address orderBookAddr = orderBookOfPerpetual[_iPerpetualId];
         require(orderBookAddr!=address(0), "order book unknown");
        int128 fTradeAmount = _fromDec18(_amountDec18);
        if (_flags==0) {
             _flags = 0x40000000;//market order
        }
        IClientOrder.ClientOrder[] memory order = new IClientOrder.ClientOrder[](1);
        order[0].flags = _flags;
        order[0].iPerpetualId = _iPerpetualId;
        order[0].traderAddr = address(this);
        order[0].fAmount = fTradeAmount;
        order[0].fLimitPrice = fTradeAmount > 0 ? MAX_64x64 : int128(0);
        order[0].leverageTDR = _leverageTDR; // 0 if deposit and trade separate
        order[0].iDeadline = uint32(block.timestamp + 86400 * 3);
        order[0].executionTimestamp = uint32(block.timestamp);
        // specify callback target
        order[0].callbackTarget = address(this);
        // submit order
        bytes[] memory sig = new bytes[](1);
        try OrderBookContractInterface(orderBookAddr).postOrders(order, sig) {
            emit PerpetualOrderSubmitSuccess(_amountDec18, _leverageTDR);
            return true;
        } catch Error(string memory reason) {
            emit PerpetualOrderSubmitFailed(reason);
            return false;
        }
    }

    function transferMarginCollateralTo(uint24 _iPerpetualId) onlyOwner external {
        uint8 poolId = uint8(_iPerpetualId/100_000);
        address mgnTknAddr = mgnTknAddrOfPool[poolId];
        IERC20Upgradeable marginToken = IERC20Upgradeable(mgnTknAddr);
        uint256 balance = marginToken.balanceOf(address(this));
        // transfer the margin token to the user
        marginToken.safeTransfer(msg.sender, balance);
        emit MarginTokenSent(_iPerpetualId, msg.sender, balance);
    }

    /**
     * Return margin account information in decimal 18 format
     * @param _iPerpetualId id of perpetual 
     */
    function getMarginAccount(uint24 _iPerpetualId) external view returns (D18MarginAccount memory) {
        MarginAccount memory acc = PerpetualsContractInterface(perpetualProxy).getMarginAccount(
            _iPerpetualId,
            address(this)
        );
        D18MarginAccount memory accD18;
        accD18.lockedInValueQCD18 = toDec18(acc.fLockedInValueQC); // unrealized value locked-in when trade occmurs: price * position size
        accD18.cashCCD18 = toDec18(acc.fCashCC); // cash in collateral currency (base, quote, or quanto)
        accD18.positionSizeBCD18 = toDec18(acc.fPositionBC); // position in base currency (e.g., 1 BTC for BTCUSD)
        accD18.positionId = acc.positionId; // unique id for the position (for given trader, and perpetual).
        return accD18;
    }

    /**
     * Get maximal trade amount for the contract accounting for its current position
     * @param _iPerpetualId id of perpetual
     * @param isBuy true if we go long, false if we go short
     * @return signed maximal trade size (negative if resulting position is short, positive otherwise)
     */
    function getMaxTradeAmount(uint24 _iPerpetualId, bool isBuy) external view returns (int256) {
        MarginAccount memory acc = PerpetualsContractInterface(perpetualProxy).getMarginAccount(
            _iPerpetualId,
            address(this)
        );
        int128 fSize = PerpetualsContractInterface(perpetualProxy).getMaxSignedOpenTradeSizeForPos(
            _iPerpetualId,
            acc.fPositionBC,
            isBuy
        );

        return toDec18(fSize);
    }

    /**
     * Convert signed decimal-18 number to ABDK-128x128 format
     * @param x number decimal-18
     * @return ABDK-128x128 number
     */
    function _fromDec18(int256 x) internal pure returns (int128) {
        int256 result = (x * ONE_64x64) / DECIMALS;
        require(x >= MIN_64x64 && x <= MAX_64x64, "result out of range");
        return int128(result);
    }

    /**
     * Convert ABDK-128x128 format to signed decimal-18 number
     * @param x number in ABDK-128x128 format
     * @return decimal 18 (signed)
     */
    function toDec18(int128 x) internal pure returns (int256) {
        return (int256(x) * DECIMALS) / ONE_64x64;
    }

    /**
     * Convert signed 256-bit integer number into signed 64.64-bit fixed point
     * number.  Revert on overflow.
     *
     * @param x signed 256-bit integer number
     * @return signed 64.64-bit fixed point number
     */
    function _fromInt(int256 x) internal pure returns (int128) {
        require(x >= -0x8000000000000000 && x <= 0x7FFFFFFFFFFFFFFF, "ABDK.fromInt");
        return int128(x << 64);
    }

    /**
     * Callback function that will be called once the order is executed or cancelled
     * @param orderDigest unique identifier for the order
     * @param isExecuted true if order was succesfully executed
     */
    function d8xExecutionCallback(bytes32 orderDigest, bool isExecuted) external {
        // msg.sender is the order-book contract, so we can upgrade the corresponding
        // margin account
        emit CallbackReceived(orderDigest, isExecuted);
    }
}
