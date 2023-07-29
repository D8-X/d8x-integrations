// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ILiquidityPoolData {

    struct LiquidityPoolData {
            bool isRunning; // state
            uint8 iPerpetualCount; // state
            uint8 id; // parameter: index, starts from 1
            int32 fCeilPnLShare; // parameter: cap on the share of PnL allocated to liquidity providers
            uint8 marginTokenDecimals; // parameter: decimals of margin token, inferred from token contract
            uint16 iTargetPoolSizeUpdateTime; //parameter: timestamp in seconds. How often we update the pool's target size
            address marginTokenAddress; //parameter: address of the margin token
            // -----
            uint64 prevAnchor; // state: keep track of timestamp since last withdrawal was initiated
            int128 fRedemptionRate; // state: used for settlement in case of AMM default
            address shareTokenAddress; // parameter
            // -----
            int128 fPnLparticipantsCashCC; // state: addLiquidity/withdrawLiquidity + profit/loss - rebalance
            int128 fTargetAMMFundSize; // state: target liquidity for all perpetuals in pool (sum)
            // -----
            int128 fDefaultFundCashCC; // state: profit/loss
            int128 fTargetDFSize; // state: target default fund size for all perpetuals in pool
            // -----
            int128 fBrokerCollateralLotSize; // param:how much collateral do brokers deposit when providing "1 lot" (not trading lot)
            uint128 prevTokenAmount; // state
            // -----
            uint128 nextTokenAmount; // state
            uint128 totalSupplyShareToken; // state
            // -----
            int128 fBrokerFundCashCC; // state: amount of cash in broker fund
    }

}