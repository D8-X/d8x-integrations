//ts-node
import { MarketData, AccountTrade, PerpetualDataHandler, sleepForSec } from "@d8x/perpetuals-sdk";
import { ethers } from "hardhat";
import { Contract, providers, Wallet } from "ethers";
import { parseEther, parseUnits } from "@ethersproject/units";

const erc20Transfer = [
    {
        constant: false,
        inputs: [
            {
                name: "_to",
                type: "address",
            },
            {
                name: "_value",
                type: "uint256",
            },
        ],
        name: "transfer",
        outputs: [
            {
                name: "",
                type: "bool",
            },
        ],
        payable: false,
        stateMutability: "nonpayable",
        type: "function",
    },
];

const TRADER_CONTRACT = "0x2BF2418cEEd5EF63DaA3b3EaF8Fe69A28271951A";
const PK: string = <string>process.env.PK;

//ts-node
async function main() {
    // load configuration
    const config = PerpetualDataHandler.readSDKConfig("bera");
    const provider = new providers.JsonRpcProvider(config.nodeURL); // or set your own RPC
    const signer = new Wallet(PK, provider);

    // Connect with trader contract
    const trader = await ethers.getContractAt("OnChainTrader", TRADER_CONTRACT, signer);

    // Berachain perpetuals use a composite token, allowing us to spend either HONEY or NECT
    // we'll use HONEY: https://berascan.com/address/0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce

    const amountHoney = parseUnits("1", 18); // HONEY has 18 decimals
    const perpetualId = 100_000;
    const honeyAddress = "0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce";

    // approve
    // const txApprove = await trader.approveCompositeToken(amountHoney, perpetualId, honeyAddress);
    // console.log("approve tx:", txApprove.hash);
    // await txApprove.wait();

    // fund trader
    const honey = new Contract(honeyAddress, erc20Transfer, signer);
    const txFund = await honey.transfer(trader.address, amountHoney);
    console.log("fund tx:", txFund.hash);
    await txFund.wait();

    // trade
    const amountTrade = parseUnits("-1.1", 18); // short 1.1 units
    const leverageTDR = 500; // 5.00x
    const txTrade = await trader.postOrder(perpetualId, amountTrade, leverageTDR, 0);
    console.log("trade tx:", txTrade.hash);
    await txTrade.wait();

    await sleepForSec(30);

    // check position:
    const account = await trader.getMarginAccount(perpetualId);
    console.log({ account });

    /**
     * apprive tx 0x...
     * fund tx: 0x...
     * trade tx: 0x...
        {
            account: [
                BigNumber { value: "-3608160996000000215" },
                BigNumber { value: "722257990107093650" },
                BigNumber { value: "-1100000000000000065" },
                lockedInValueQCD18: BigNumber { value: "-3608160996000000215" },
                cashCCD18: BigNumber { value: "722257990107093650" },
                positionSizeBCD18: BigNumber { value: "-1100000000000000065" }
            ]
        }
     */
}
main();
