// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title Trader/Broker facing order struct
 * @notice this order struct is sent to the limit order book and converted into an IPerpetualOrder
 */
interface IClientOrder {
    //     iPerpetualId          global id for perpetual
    //     traderAddr            address of trader
    //     brokerSignature       signature of broker (or 0)
    //     brokerFeeTbps         broker can set their own fee
    //     fAmount               amount in base currency to be traded
    //     fLimitPrice           limit price
    //     fTriggerPrice         trigger price. Non-zero for stop orders.
    //     iDeadline             deadline for price (seconds timestamp)
    //     traderMgnTokenAddr    address of the compatible margin token the user likes to use,
    //                           0 if same token as liquidity pool's margin token
    //     flags                 trade flags
    struct ClientOrder {
        uint32 flags;
        uint24 iPerpetualId;
        uint16 brokerFeeTbps;
        address traderAddr;
        address brokerAddr;
        address referrerAddr;
        bytes brokerSignature;
        int128 fAmount;
        int128 fLimitPrice;
        int128 fTriggerPrice;
        int128 fLeverage; // 0 if deposit and trade separate
        uint64 iDeadline;
        uint64 createdTimestamp;
        //uint64 submittedBlock <- will be set by LimitOrderBook
        bytes32 parentChildDigest1;
        bytes32 parentChildDigest2;
    }
}
