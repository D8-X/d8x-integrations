// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title Trader/Broker facing order struct
 * @notice this order struct is sent to the limit order book and converted into an IPerpetualOrder
 */
interface IClientOrder {
    struct ClientOrder {
        uint24 iPerpetualId; // unique id of the perpetual
        int128 fLimitPrice; // order will not execute if realized price is above (buy) or below (sell) this price
        uint16 leverageTDR; // leverage, set to 0 if deposit margin and trade separate; format: two-digit integer (e.g., 12.34 -> 1234)
        uint32 executionTimestamp; // the order will not be executed before this timestamp, allows TWAP orders
        uint32 flags; // Order-flags are specified in OrderFlags.sol
        uint32 iDeadline; // order will not be executed after this deadline
        address brokerAddr; // can be empty, address of the broker
        int128 fTriggerPrice; // trigger price for stop-orders|0. Order can be executed if the mark price is below this price (sell order) or above (buy)
        int128 fAmount; // signed amount of base-currency. Will be rounded to lot size
        bytes32 parentChildDigest1; // see notice in LimitOrderBook.sol
        address traderAddr; // address of the trader
        bytes32 parentChildDigest2; // see notice in LimitOrderBook.sol
        uint16 brokerFeeTbps; // broker fee in tenth of a basis point
        bytes brokerSignature; // signature, can be empty if no brokerAddr provided
        //address executorAddr; <- will be set by LimitOrderBook
        //uint64 submittedBlock <- will be set by LimitOrderBook
    }
}
