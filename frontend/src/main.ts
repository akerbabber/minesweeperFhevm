import { BrowserProvider, Contract, JsonRpcSigner, ethers } from "ethers";
import { createInstance, initFhevm } from "fhevmjs";

import contractArtifact from "../../artifacts/contracts/Minesweeper.sol/Minesweeper.json";

declare global {
  interface Window {
    ethereum: any;
  }
}

const createFhevmInstance = async () => {
  await initFhevm();
  return createInstance({
    chainId: 11155111, // Sepolia chain ID
    networkUrl: "https://eth-sepolia.public.blastapi.io", // Sepolia RPC URL
    gatewayUrl: "https://gateway.sepolia.zama.ai",
    kmsContractAddress: "0x9D6891A6240D6130c54ae243d8005063D05fE14b",
    aclContractAddress: "0xFee8407e2f5e3Ee68ad77cAE98c434e637f516e5",
  });
};
createFhevmInstance().then((instance) => {
  console.log(instance);
});

const abi = contractArtifact.abi;
const bytecode = contractArtifact.bytecode; // Replace with actual contract bytecode.
const BOARD_SIZE = 16;

let provider: BrowserProvider, signer: JsonRpcSigner, contract: Contract;
const accountArea = document.getElementById("accountArea") as HTMLElement;
const connectButton = document.getElementById("connectButton") as HTMLButtonElement;
const deployButton = document.getElementById("deployButton") as HTMLButtonElement;
const boardDiv = document.getElementById("board") as HTMLElement;

connectButton.onclick = async () => {
  if (window.ethereum) {
    provider = new BrowserProvider(window.ethereum);
    await provider.send("eth_requestAccounts", []);
    signer = await provider.getSigner();
    const address = await signer.getAddress();
    accountArea.textContent = `Connected as: ${address}`;
    connectButton.style.display = "none";
    deployButton.style.display = "inline-block";
  } else {
    alert("Metamask not found");
  }
};

deployButton.onclick = async () => {
  const factory = new ethers.ContractFactory(abi, bytecode).connect(signer);
  contract = (await (await factory.deploy()).waitForDeployment()) as Contract;
  // contract = new Contract("0x6eE276EA5763214c9E117A99e5eF97f8c4025415", abi, signer);
  deployButton.style.display = "none";
  initBoard();
};

function initBoard() {
  boardDiv.style.gridTemplateColumns = `repeat(${BOARD_SIZE}, 30px)`;
  boardDiv.innerHTML = "";
  for (let i = 0; i < BOARD_SIZE; i++) {
    for (let j = 0; j < BOARD_SIZE; j++) {
      const cell = document.createElement("div");
      cell.className = "cell hidden";
      cell.id = `cell-${i}-${j}`;
      cell.addEventListener("click", () => onCellClick(i, j));
      boardDiv.appendChild(cell);
    }
  }
}

async function pollBoard() {
  if (!contract) return;
  try {
    const boardData = await contract.getBoard();
    for (let i = 0; i < BOARD_SIZE; i++) {
      for (let j = 0; j < BOARD_SIZE; j++) {
        const cellRaw = boardData[i][j];
        const cellValue: bigint = cellRaw;
        updateCell(i, j, cellValue);
      }
    }
  } catch (e) {
    console.error(e);
  }
}

function updateCell(row: number, col: number, cellValue: bigint) {
  const cell = document.getElementById(`cell-${row}-${col}`);
  if (!cell) return;
  // 0 = hidden, 1 = empty, 2 = mine, >2 = number with offset.
  if (cellValue === 0n) {
    cell.className = "cell hidden";
    cell.textContent = "";
  } else if (cellValue === 2n) {
    cell.className = "cell mine";
    cell.textContent = "💣";
  } else if (cellValue === 1n) {
    cell.className = "cell empty";
    cell.textContent = "0";
  } else {
    cell.className = "cell revealed";
    // Assuming enum: one = 3, so subtract one to show number.
    cell.textContent = (cellValue - 2n).toString();
  }
}

async function onCellClick(row: number, col: number) {
  if (!contract) return;
  try {
    const tx = await contract.pickMine(row, col);
    await tx.wait();
  } catch (e) {
    console.error(e);
  }
}

setInterval(pollBoard, 1000);
