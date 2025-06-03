 - Recommended postOrder function below.
 - You can use this function to open the strategy and to close the strategy
 - use getMarginAccount (https://github.com/D8-X/d8x-integrations/blob/153a62dfa88551f7809c72beda3eb4a00eb6d102/contracts/OnChainTrader.sol#L243) or similar
  to set the position size within the contract
 - to open the strategy you can use the helper script `dirac.ts` 
 - to close the strategy, the trade amounts are just the negative of the current notional

 ```
 function postOrder(
        uint24 _iPerpetualId,
        int256 _fTradeAmountABDK,
        uint16 _leverageTDR,
        uint32 _flags
    ) external onlyRole(OPERATOR_ROLE) whenNotPaused nonReentrant onlyTradeCycle(TradeCycleStatus.OPEN) {
        address orderBookAddr = orderBookOfPerpetual[_iPerpetualId];
        require(orderBookAddr != address(0), "order book unknown");
        if (_flags == 0) {
            _flags = 0x40000000; //market order
        }
        IClientOrder.ClientOrder[] memory order = new IClientOrder.ClientOrder[](1);
        order[0].flags = _flags;
        order[0].iPerpetualId = _iPerpetualId;
        order[0].traderAddr = address(this);
        order[0].fAmount = _fTradeAmountABDK;
        order[0].fLimitPrice = _fTradeAmountABDK > 0 ? MAX_64x64 : int128(0);
        order[0].leverageTDR = _leverageTDR; // 0 if deposit and trade separate
        order[0].iDeadline = uint32(block.timestamp + 86400 * 3);
        order[0].executionTimestamp = uint32(block.timestamp);
        // specify callback target seems not to be necessary
        // order[0].callbackTarget = address(this);

        // submit order
        bytes[] memory sig = new bytes[](1);
        try OrderBookContractInterface(orderBookAddr).postOrders(order, sig) {
            emit PerpetualOrderSubmitSuccess(_amountDec18, _leverageTDR);
        } catch Error(string memory reason) {
            emit PerpetualOrderSubmitFailed(reason);
        }
    }
```

