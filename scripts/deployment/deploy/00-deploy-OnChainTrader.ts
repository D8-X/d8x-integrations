import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { PerpetualDataHandler, MarketData, NodeSDKConfig } from "@d8x/perpetuals-sdk";

const deployOnChainTrader: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: { deploy, get, log },
        getNamedAccounts,
        ethers,
    } = hre;
    const { deployer } = await getNamedAccounts();

    const chainId = hre.network.config.chainId;
    const config = PerpetualDataHandler.readSDKConfig(chainId!);
    const perpetualManagerProxyAddr = config.proxyAddr;
    let perpetualIds = await collectAllPerpetualIds(config);
    // deploy
    const traderCtrctDepl = await deploy("OnChainTrader", {
        from: deployer,
        args: [perpetualManagerProxyAddr],
        log: true,
    });
    let traderCtrct = await ethers.getContractAt("OnChainTrader", (await get("OnChainTrader")).address);
    console.log(`verify:\nnpx hardhat verify "${traderCtrctDepl.address}" "${perpetualManagerProxyAddr}" --network ${hre.network.name}`);

    // initialize
    for (let k = 0; k < perpetualIds.length; k++) {
        let id = perpetualIds[k];
        console.log(`/nAdding perpetual ${id}...`);
        let tx = await traderCtrct.addPerpetual(id);
        console.log(tx.hash);
        console.log("done.");
    }
};

deployOnChainTrader.tags = ["OnChainTrader"];
export default deployOnChainTrader;

async function collectAllPerpetualIds(config: NodeSDKConfig): Promise<Array<number>> {
    let allPerpetualIds = new Array<number>();
    let mktData = new MarketData(config);
    await mktData.createProxyInstance();
    let info = await mktData.exchangeInfo();
    for (let k = 0; k < info.pools.length; k++) {
        console.log(`Pool ${k + 1}: ${info.pools[k].poolSymbol}, margin token address: ${info.pools[k].marginTokenAddr}`);
        for (let j = 0; j < info.pools[k].perpetuals.length; j++) {
            let p = info.pools[k].perpetuals[j];
            const perpId = Number(p.id);
            let perpetualSymbol = `${p.baseCurrency + "-" + p.quoteCurrency + "-" + info.pools[k].poolSymbol}`;
            let perpInfo = mktData.getPerpetualStaticInfo(perpetualSymbol);
            console.log(`\tperpetual id ${p.id} : ${perpetualSymbol} with order book @ ${perpInfo.limitOrderBookAddr}`);
            allPerpetualIds.push(perpId);
        }
    }
    return allPerpetualIds;
}
