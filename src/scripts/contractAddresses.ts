//ts-node
import { MarketData, AccountTrade, PerpetualDataHandler } from "@d8x/perpetuals-sdk";

//ts-node
async function main() {
    // load configuration for testnet
    const config = PerpetualDataHandler.readSDKConfig("testnet");
    // set your own rpc:
    // config.nodeURL="...";

    // MarketData (read only, no authentication needed)
    let mktData = new MarketData(config);

    // Create a proxy instance to access the blockchain
    await mktData.createProxyInstance();
    // now you can access all methods of the Market Data object
    // https://d8x.gitbook.io/d8x/node-sdk/getting-started

    let info = await mktData.exchangeInfo();
    //console.log(info);
    console.log(`D8X Perpetual Proxy Address ${info.proxyAddr}`);
    for (let k = 0; k < info.pools.length; k++) {
        console.log(`Pool ${k + 1}: ${info.pools[k].poolSymbol}, margin token address: ${info.pools[k].marginTokenAddr}`);
        for (let j = 0; j < info.pools[k].perpetuals.length; j++) {
            let p = info.pools[k].perpetuals[j];
            let perpetualSymbol = `${p.baseCurrency + "-" + p.quoteCurrency + "-" + info.pools[k].poolSymbol}`;
            let perpInfo = mktData.getPerpetualStaticInfo(perpetualSymbol);
            console.log(`\tperpetual id ${p.id} : ${perpetualSymbol} with order book @ ${perpInfo.limitOrderBookAddr}`);
        }
    }
}
main();
