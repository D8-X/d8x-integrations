//ts-node
import { MarketData, AccountTrade, PerpetualDataHandler } from "@d8x/perpetuals-sdk";
import {ethers} from 'hardhat'

//ts-node
async function main() {
    // load configuration for testnet
    const config = PerpetualDataHandler.readSDKConfig("zkevmTestnet");
    // set your own rpc:
    // config.nodeURL="...";

    // MarketData (read only, no authentication needed)
    const mktData = new MarketData(config);

    // Create a proxy instance to access the blockchain
    await mktData.createProxyInstance();
    // now you can access all methods of the Market Data object
    // https://d8x.gitbook.io/d8x/node-sdk/getting-started

    // Approve perpetual proxy to spend tokens
    const traderFactory = await ethers.getContractAt
    const trader = traderFactory.
}
main();
