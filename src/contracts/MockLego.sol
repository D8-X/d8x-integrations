// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IClientOrder.sol";

interface OrderBookContractInterface {
    function postOrder(IClientOrder.ClientOrder calldata _order, bytes calldata _signature)
        external;
}

/**
 * @title Example contract to interact with D8X perpetuals on-chain
 * @notice
 * - D8X Perpetuals use ABDK 128x128 number format. This contract has an interface that uses
 *   a signed decimal-18 convention (decimal number 1 maps to decimal-18 number 1e18).
 * - Ensure the perpetuals-contract is allowed to spend this contracts margin tokens (use approveAmount)
 * - Send orders to order book via postOrder
 * - Check positions using function getMarginAccount
 */
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
    int256 lockedInValueQCD18; // unrealized value locked-in when trade occurs in
    int256 cashCCD18; // cash in collateral currency (base, quote, or quanto)
    int256 positionSizeBCD18; // position in base currency (e.g., 1 BTC for BTCUSD)
    bytes16 positionId; // unique id for the position (for given trader, and perpetual). Current position, zero otherwise.
}

/**
 * @title This contract is an example on how to trade from another contract
 * @notice
 * Available order flags:
 *  uint32 internal constant MASK_CLOSE_ONLY = 0x80000000;
 *  uint32 internal constant MASK_MARKET_ORDER = 0x40000000;
 *  uint32 internal constant MASK_STOP_ORDER = 0x20000000;
 *  uint32 internal constant MASK_FILL_OR_KILL = 0x10000000;
 *  uint32 internal constant MASK_KEEP_POS_LEVERAGE = 0x08000000;
 *  uint32 internal constant MASK_LIMIT_ORDER = 0x04000000;
 */
contract MockLego {
    event PerpOrderSubmitFailed(string reason);
    event PerpOrderSubmitSuccess(int256 amountDec18, uint16 leverageTDR);
    address public immutable orderBookAddr;
    address public immutable perpetualProxy;
    address public immutable mgnTokenAddr;
    uint24 public immutable iPerpetualId;
    int256 private constant DECIMALS = 10**18;
    int128 private constant ONE_64x64 = 0x010000000000000000;
    int128 private constant MIN_64x64 = -0x80000000000000000000000000000000;
    int128 private constant MAX_64x64 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    int128 private constant TEN_64x64 = 0xa0000000000000000;

    constructor(
        address _d8xOrderBookAddr,
        address _perpetualProxy,
        address _mgnTokenAddr,
        uint24 _iPerpetualId
    ) {
        orderBookAddr = _d8xOrderBookAddr;
        iPerpetualId = _iPerpetualId;
        perpetualProxy = _perpetualProxy;
        mgnTokenAddr = _mgnTokenAddr;
    }

    /**
     * Approve the margin-token to be spent by perpetuals contract.
     * Required to trade.
     * @param _amount spend amount
     */
    function approveAmount(uint256 _amount) external {
        IERC20(mgnTokenAddr).approve(perpetualProxy, _amount);
    }

    /**
     * Post an order to the order book. Order will be executed by
     * external "keepers".
     * @param _amountDec18 signed amount to be traded
     * @param _leverageTDR leverage two-digit-integer), e.g. 210 for 2.1x leverage
     * @return true if posting order succeeded
     */
    function postOrder(int256 _amountDec18, uint16 _leverageTDR) external returns (bool) {
        int128 fTradeAmount = _fromDec18(_amountDec18);
        IClientOrder.ClientOrder memory order;
        order.flags = 0x40000000;
        order.iPerpetualId = iPerpetualId;
        order.traderAddr = address(this);
        order.fAmount = fTradeAmount;
        order.fLimitPrice = fTradeAmount > 0 ? MAX_64x64 : int128(0);
        order.leverageTDR = _leverageTDR; // 0 if deposit and trade separate
        order.iDeadline = uint32(block.timestamp + 86400 * 3);
        order.executionTimestamp = uint32(block.timestamp);
        // fields not required:
        //      uint16 brokerFeeTbps;
        //      address brokerAddr;
        //      address referrerAddr;
        //      bytes brokerSignature;
        //      int128 fTriggerPrice;
        //      bytes32 parentChildDigest1;
        //      bytes32 parentChildDigest2;

        // submit order
        try OrderBookContractInterface(orderBookAddr).postOrder(order, bytes("")) {
            emit PerpOrderSubmitSuccess(_amountDec18, _leverageTDR);
            return true;
        } catch Error(string memory reason) {
            emit PerpOrderSubmitFailed(reason);
            return false;
        }
    }

    /**
     * Return margin account information in decimal 18 format
     */
    function getMarginAccount() external view returns (D18MarginAccount memory) {
        MarginAccount memory acc = PerpetualsContractInterface(perpetualProxy).getMarginAccount(
            iPerpetualId,
            address(this)
        );
        D18MarginAccount memory accD18;
        accD18.lockedInValueQCD18 = toDec18(acc.fLockedInValueQC); // unrealized value locked-in when trade occurs: price * position size
        accD18.cashCCD18 = toDec18(acc.fCashCC); // cash in collateral currency (base, quote, or quanto)
        accD18.positionSizeBCD18 = toDec18(acc.fPositionBC); // position in base currency (e.g., 1 BTC for BTCUSD)
        accD18.positionId = acc.positionId; // unique id for the position (for given trader, and perpetual).
        return accD18;
    }

    /**
     * Get maximal trade amount for the contract accounting for its current position
     * @param isBuy true if we go long, false if we go short
     * @return signed maximal trade size (negative if resulting position is short, positive otherwise)
     */
    function getMaxTradeAmount(bool isBuy) external view returns (int256) {
        MarginAccount memory acc = PerpetualsContractInterface(perpetualProxy).getMarginAccount(
            iPerpetualId,
            address(this)
        );
        int128 fSize = PerpetualsContractInterface(perpetualProxy).getMaxSignedOpenTradeSizeForPos(
            iPerpetualId,
            acc.fPositionBC,
            isBuy
        );

        if ((isBuy && fSize < 0) || (!isBuy && fSize > 0)) {
            // obsolete with deployment past April 23
            fSize = 0;
        }

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
}
