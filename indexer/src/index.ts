import {
  JsonRpcProvider,
  Contract,
  Wallet,
  parseEther,
  Interface,
  InterfaceAbi,
  id,
} from "ethers";
import { BRIDGE_CONTRACT_SEPOLIA_ABI } from "./contract_abis/BridgeSepolia";
import { BRIDGE_CONTRACT_HOLESKY_ABI } from "./contract_abis/BridgeHolesky";
import { KJCOIN_ABI } from "./contract_abis/KJCOIN";
import { BJCOIN_ABI } from "./contract_abis/BJCOIN";
import { PrismaClient, Network } from "@prisma/client";

import dotenv from "dotenv";
dotenv.config();

const prisma = new PrismaClient();

const KJCOIN_CONTRACT_ADDRESS = "0xC25f7c4ef41f05921257c7efE69A8C58CDAc8f7B";
const BJCOIN_CONTRACT_ADDRESS = "0xBaC12daE1febEf94B5ba118eCF5C2A08d80E581D";

const WALLET_PRIVATE_KEY = process.env.WALLET_PRIVATE_KEY;

const BRIDGE_CONTRACT_ADDRESS_SEPOLIA =
  "0xBaC12daE1febEf94B5ba118eCF5C2A08d80E581D";
const BRIDGE_CONTRACT_ADDRESS_HOLESKY =
  "0x108E111f5b5C0412071404cdBadD41091A6e0d06";

const sepoliaProvider = new JsonRpcProvider(`${process.env.SEPOLIA_RPC_URL}`);
const holeskyProvider = new JsonRpcProvider(`${process.env.HOLESKY_RPC_URL}`);

const sepoliaBridgeContract = new Contract(
  BRIDGE_CONTRACT_ADDRESS_SEPOLIA,
  BRIDGE_CONTRACT_SEPOLIA_ABI,
  sepoliaProvider
);

const holeskyBridgeContract = new Contract(
  BRIDGE_CONTRACT_ADDRESS_HOLESKY,
  BRIDGE_CONTRACT_HOLESKY_ABI,
  holeskyProvider
);

const sepoliaBridgeContractInterface = new Interface(
  BRIDGE_CONTRACT_SEPOLIA_ABI
);

const holeskyBridgeContractInterface = new Interface(
  BRIDGE_CONTRACT_HOLESKY_ABI
);

async function listenBridgeEvents(
  network: Network,
  provider: JsonRpcProvider,
  contractInterface: Interface
) {
  try {
    let networkStatus = await prisma.networkStatus.findUnique({
      where: {
        network: network,
      },
    });
    const currentBlock = await provider.getBlockNumber();

    if (!networkStatus) {
      networkStatus = await prisma.networkStatus.create({
        data: {
          network: network,
          lastProcessedBlock: currentBlock,
        },
      });
    }

    if (networkStatus.lastProcessedBlock >= currentBlock) return;
    
    console.log(
      "Processing block",
      networkStatus.lastProcessedBlock,
      currentBlock
    );

    const filter =
      network == Network.SEPOLIA
        ? "Deposit(address,address,uint256)"
        : "Burn(address,address,uint256)";
    // get Events from block
    const logs = await provider.getLogs({
      address:
        network === Network.SEPOLIA
          ? BRIDGE_CONTRACT_ADDRESS_SEPOLIA
          : BRIDGE_CONTRACT_ADDRESS_HOLESKY,
      fromBlock: networkStatus.lastProcessedBlock + 1,
      toBlock: currentBlock,
      topics: [id(filter)],
    });

    for (let i = 0; i < logs.length; i++) {
      const log = logs[i];
      const parsedLogs = contractInterface.parseLog(log);
      if (parsedLogs) {
        const txHash = log.transactionHash;
        const tokenAddress = parsedLogs.args[0].toString();
        const sender = parsedLogs.args[1].toString();
        const amount = parsedLogs.args[2].toString();

        console.log("Transaction Recieved", sender, amount);

        // Add this transaction to the Queue
        await processQueue(network, txHash, sender, amount, tokenAddress);
      }
      await new Promise((resolve) => setTimeout(resolve, 2000));
    }

    await prisma.networkStatus.update({
      where: {
        network: network,
      },
      data: {
        lastProcessedBlock: currentBlock,
      },
    });
  } catch (error) {
    console.log(error);
  }
}

// // call every 10 seconds
setInterval(() => {
  listenBridgeEvents(
    Network.SEPOLIA,
    sepoliaProvider,
    sepoliaBridgeContractInterface
  );
}, 10000);

setInterval(() => {
  listenBridgeEvents(
    Network.HOLESKY,
    holeskyProvider,
    holeskyBridgeContractInterface
  );
}, 10000);

async function processQueue(
  network: Network,
  txHash: string,
  sender: string,
  amount: string,
  tokenAddress: string
) {
  try {
    // check if current tx is already processed
    // if not, then create new entry in the transaction table
    // process other side of the contract
    // make transation done `true`
    let tx = await prisma.transactionData.findUnique({
      where: {
        txHash: txHash,
        network: network,
      },
    });

    if (!tx) {
      // increment nonce
      let networkStatus = await prisma.networkStatus.findUnique({
        where: {
          network,
        },
      });

      if (!networkStatus) return;

      tx = await prisma.transactionData.create({
        data: {
          txHash,
          network,
          isDone: false,
          nonce: networkStatus.nonce,
          tokenAddress,
          sender,
          amount,
        },
      });
    }

    if (tx.isDone) return;

    const oppositeNetwork =
      network == Network.SEPOLIA ? Network.HOLESKY : Network.SEPOLIA;
    const oppositeProvider =
      network == Network.SEPOLIA ? holeskyProvider : sepoliaProvider;

    // check if opposite network exists
    let oppositeNetworkStatus = await prisma.networkStatus.findFirst({
      where: {
        network: oppositeNetwork,
      },
    });

    if (!oppositeNetworkStatus) {
      const currentBlock = await oppositeProvider.getBlockNumber();
      oppositeNetworkStatus = await prisma.networkStatus.create({
        data: {
          network: oppositeNetwork,
          lastProcessedBlock: currentBlock,
          nonce: 0,
        },
      });
    }

    // increase nonce
    oppositeNetworkStatus = await prisma.networkStatus.update({
      where: {
        network: network == Network.SEPOLIA ? Network.HOLESKY : Network.SEPOLIA,
      },
      data: {
        nonce: {
          increment: 1,
        },
      },
    });

    await processOnOppositeSide(
      oppositeNetworkStatus.network,
      oppositeProvider,
      network == Network.SEPOLIA
        ? holeskyBridgeContract
        : sepoliaBridgeContract,
      oppositeNetworkStatus.nonce,
      network == Network.SEPOLIA
        ? BRIDGE_CONTRACT_HOLESKY_ABI
        : BRIDGE_CONTRACT_SEPOLIA_ABI,
      sender,
      amount
    );

    await prisma.transactionData.update({
      where: {
        txHash: txHash,
      },
      data: {
        isDone: true,
      },
    });
  } catch (error) {
    console.log(error);
  }
}

async function processOnOppositeSide(
  network: Network,
  provider: JsonRpcProvider,
  contract: Contract,
  nonce: number,
  abi: InterfaceAbi,
  sender: string,
  amount: string
) {
  const wallet = new Wallet(WALLET_PRIVATE_KEY || "", provider);
  const contractInstance = new Contract(contract, abi, wallet);
  try {
    console.log("Processing on opposite end");
    if (network == Network.SEPOLIA) {
      const tx = await contractInstance.redeem(
        KJCOIN_CONTRACT_ADDRESS,
        sender,
        amount,
        nonce
      );
      await tx.wait();
      console.log(tx);
    } else {
      const tx = await contractInstance.mint(
        BJCOIN_CONTRACT_ADDRESS,
        sender,
        amount,
        nonce
      );
      await tx.wait();
      console.log(tx);
    }
  } catch (error) {
    console.log(error);
  }
}

// async function main() {
//   // approve this bridge contract 10 ETH

//   const wallet = new Wallet(WALLET_PRIVATE_KEY || "", sepoliaProvider);
//   const tokenContractInstance = new Contract(
//     KJCOIN_CONTRACT_ADDRESS,
//     KJCOIN_ABI,
//     wallet
//   );
//   const tx1 = await tokenContractInstance.approve(
//     BRIDGE_CONTRACT_ADDRESS_SEPOLIA,
//     parseEther("5")
//   );
//   await tx1.wait();
//   console.log("approved 5 ETH");

//   const contractInstance = new Contract(
//     BRIDGE_CONTRACT_ADDRESS_SEPOLIA,
//     BRIDGE_CONTRACT_SEPOLIA_ABI,
//     wallet
//   );
//   const tx2 = await contractInstance.deposit(
//     KJCOIN_CONTRACT_ADDRESS,
//     parseEther("5")
//   );
//   await tx2.wait();
//   listenBridgeEvents(
//     Network.SEPOLIA,
//     sepoliaProvider,
//     sepoliaBridgeContractInterface
//   );
// }

// main();
