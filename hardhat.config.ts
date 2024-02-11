// @ts-nocheck
require("dotenv").config();
import { task } from "hardhat/config";
import { ethers } from "ethers";
import { SigningKey } from "@ethersproject/signing-key";
import "hardhat-abi-exporter";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-deploy";
//import "@typechain/hardhat";

import "@nomiclabs/hardhat-waffle";
import { HardhatUserConfig } from "hardhat/types";
import { error } from "console";
//require("hardhat-log-remover");

const path = require("path");
const ZERO_PK = "0x0000000000000000000000000000000000000000000000000000000000000000";
let pk: string | SigningKey = <string>process.env.PK;
let etherscanapikey: string = <string>process.env.APIKEY;
let RPC: string = <string>process.env.RPC;
let wallet;
try {
    wallet = new ethers.Wallet(pk);
} catch (e) {
    pk = ZERO_PK;
}
if (pk != ZERO_PK && etherscanapikey == "") {
    error("define api key for polygonscan: export APIKEY=...");
}

task("accounts", "Prints the list of accounts", async (args, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

task("runDeployStep", "Run a deploy step")
    .addPositionalParam("stepName", "Step name")
    .addPositionalParam("paramFile", "File containing the params for the current step")
    .setAction(async (args, hre) => {
        try {
            // the "signer" is defined via [pk],
            // see network settings below
            // await hre.ethers.getSigners();
            const scriptName = args.stepName;
            const { main } = require(`./scripts/deployment/generic/${scriptName}`);
            await main(args.paramFile);
        } catch (error) {
            console.error(`Error in deploy step.`, error);
        }
    });

task("setPerpetualParam", "Set a perpetual parameter")
    .addPositionalParam("perpId", "Perpetual ID")
    .addPositionalParam("paramName", "The name of the parameter to change")
    .addPositionalParam("paramValue", "The new value of the parameter")
    .setAction(async (args, hre) => {
        try {
            const accounts = await hre.ethers.getSigners();
            const { main } = require(`./scripts/deployment/generic/setPerpetualParam`);
            await main(accounts, args.perpId, args.paramName, args.paramValue);
        } catch (error) {
            console.error(`Error running setPerpetualParam.`, error);
        }
    });

task("encode", "Encode calldata")
    .addPositionalParam("sig", "Signature of contract to deploy")
    .addOptionalPositionalParam("args", "Args of function call, seprated by common ','")
    .setAction(async (args, hre) => {
        if (typeof args.args != "undefined") {
            args.args = args.args.split(",");
        }
        args.sig = args.sig.replace("function ", "");
        var iface = new hre.ethers.utils.Interface(["function " + args.sig]);
        var selector = args.sig.slice(0, args.sig.indexOf("("));
        // console.log(args.sig, args.args, selector)
        var calldata = iface.encodeFunctionData(selector, args.args);
        console.log("encoded calldata", calldata);
    });

task("send", "Call contract function")
    .addPositionalParam("address", "Address of contract")
    .addPositionalParam("sig", "Signature of contract")
    .addOptionalPositionalParam("args", "Args of function call, seprated by common ','")
    .setAction(async (args, hre) => {
        if (typeof args.args != "undefined") {
            args.args = args.args.split("|");
        }
        args.sig = args.sig.replace("function ", "");
        var iface = new hre.ethers.utils.Interface(["function " + args.sig]);
        var selector = args.sig.slice(0, args.sig.indexOf("("));
        // console.log(args.sig, args.args, selector)
        var calldata = iface.encodeFunctionData(selector, args.args);
        // console.log("encoded calldata", calldata)
        const signer = hre.ethers.provider.getSigner(0);

        const tx = await signer.sendTransaction({
            to: args.address,
            from: signer._address,
            data: calldata,
        });
        console.log(tx);
        console.log(await tx.wait());
    });

task("call", "Call contract function")
    .addPositionalParam("address", "Address of contract")
    .addPositionalParam("sig", "Signature of contract")
    .addOptionalPositionalParam("args", "Args of function call, seprated by common ','")
    .setAction(async (args, hre) => {
        if (typeof args.args != "undefined") {
            args.args = args.args.split("|");
        }
        args.sig = args.sig.replace("function ", "");
        var iface = new hre.ethers.utils.Interface(["function " + args.sig]);
        var selector = args.sig.slice(0, args.sig.indexOf("("));
        console.log(args.sig, args.args, selector);
        var calldata = iface.encodeFunctionData(selector, args.args);
        //       console.log("encoded calldata", calldata)
        const signer = hre.ethers.provider.getSigner(0);
        const result = await signer.call({
            to: args.address,
            data: calldata,
        });
        console.log("result", result);
    });

export default {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            chainId: 31337,
            // hardfork: "istanbul",
            allowUnlimitedContractSize: true,
            saveDeployments: true,
            timeout: 30000000,
            // initialBaseFeePerGas: 0, // may need to uncomment for hardhat coverage to not throw errors
        },
        localhost: {
            // exposed node of hardhat network:
            // 1. hh node --network hardhat
            // 2. hh deploy --network localhost
            chainId: 31337,
            allowUnlimitedContractSize: true,
            timeout: 30000000,
            url: "http://localhost:8545",
        },
        mumbai: {
            url: RPC ?? "https://rpc-mumbai.maticvigil.com/",
            // url: 'https://matic-mumbai.chainstacklabs.com',
            //url: 'https://rpc-mumbai.matic.today',
            chainId: 80001,
            accounts: [pk],
            // gasPrice: 15_000_000_000,
            // blockGasLimit:35_000_000,
            //gas: 10000000,
            timeout: 300_000,
        },
        zkevmTestnet: {
            url: RPC ?? "https://rpc.public.zkevm-test.net",
            chainId: 1442,
            accounts: [pk],
            timeout: 60_000,
            // gasPrice: 500_000_000,
            gas: 10_000_000,
        },
        arbitrumGoerli: {
            url: RPC ?? "https://goerli-rollup.arbitrum.io/rpc",
            chainId: 421613,
            accounts: [pk],
            timeout: 60_000,
            // gasPrice: 200000000,
            gas: 35_000_000,
        },
         zkevm: {
            url: RPC ?? "https://polygon-zkevm.drpc.org",
            chainId: 1101,
            accounts: [pk],
            timeout: 300_000,
            gas: 6_000_000,
            // gasPrice: 500_000_000
          },
        arbitrumOne: {
            url: RPC ?? "https://arbitrum-one.publicnode.com",
            chainId: 42161,
            accounts: [pk],
            timeout: 300_000,
            gasLimit: 30_000_000
        },
        X1: {
            url: RPC ?? "https://testrpc.x1.tech",
            chainId: 195,
            accounts: [pk],
            gas: 6_000_000,
        },
        sepolia: {
            url: RPC ?? "https://ethereum-sepolia.publicnode.com",
            chainId: 11155111,
            accounts: [pk],
            gas: 6_000_000
        },
        cardona: {
            url: RPC ?? "https://rpc.cardona.zkevm-rpc.com",
            chainId: 2442,
            accounts: [pk],
            gas: 6_000_000
        },
        arbitrumSepolia: {
            url: RPC ?? "https://sepolia-rollup.arbitrum.io/rpc",
            chainId: 421614,
            accounts: [pk],
            gas: 20_000_000
        }
    },
    etherscan: {
        apiKey: etherscanapikey,
        customChains: [
            {
                network: "zkevmTestnet",
                chainId: 1442,
                urls: {
                    apiURL: "https://api-testnet-zkevm.polygonscan.com/api",
                    browserURL: "https://testnet-zkevm.polygonscan.com/",
                },
            },
            {
                network: "mumbai",
                chainId: 80001,
                urls: {
                    apiURL: "https://api-testnet.polygonscan.com/api",
                    browserURL: "https://mumbai.polygonscan.com/",
                },
            },
        ],
    },
    solidity: {
        version: "0.8.19",
        settings: {
            optimizer: {
                enabled: true,
                runs: 2 ** 9,
            },
            outputSelection: {
                "*": {
                    "*": ["storageLayout"],
                },
            },
        },
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts",
        abi: "./abi",
        deploy: "./scripts/deployment/deploy",
        deployments: "./scripts/deployment/deployments",
    },
    contractSizer: {
        alphaSort: false,
        runOnCompile: false,
        disambiguatePaths: false,
    },
    gasReporter: {
        enabled: false,
        currency: "USD",
    },
    abiExporter: {
        path: "./abi",
        clear: true,
        runOnCompile: true,
        flat: true,
        spacing: 4,
        pretty: false,
    },
    mocha: {
        timeout: 100000000,
    },
    namedAccounts: {
        deployer: 0,
    },
    typechain: {
        outDir: "typechain",
        target: "ethers-v5",
    },
} as HardhatUserConfig;
