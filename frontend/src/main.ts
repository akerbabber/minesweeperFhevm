import { Web3Provider } from "@ethersproject/providers";
import { ethers } from "ethers";
import { createInstance } from "fhevmjs/node";

import contractArtifact from "../../artifacts/contracts/Minesweeper.sol/Minesweeper.json";

declare global {
  interface Window {
    Ethereum: any;
  }
}

const createFhevmInstance = async () => {
  return createInstance({
    chainId: 11155111, // Sepolia chain ID
    networkUrl: "https://eth-sepolia.public.blastapi.io", // Sepolia RPC URL
    gatewayUrl: "https://gateway.sepolia.zama.ai",
    kmsContractAddress: "0x9D6891A6240D6130c54ae243d8005063D05fE14b";
    aclContractAddress: "0xFee8407e2f5e3Ee68ad77cAE98c434e637f516e5";
  });
};
createFhevmInstance().then((instance) => {
  console.log(instance);
});

const abi = contractArtifact.abi;
const bytecode = contractArtifact.bytecode; // Replace with actual contract bytecode.
const BOARD_SIZE = 16;

let provider: any, signer: any, contract: any;
const accountArea = document.getElementById("accountArea") as HTMLElement;
const connectButton = document.getElementById("connectButton") as HTMLButtonElement;
const deployButton = document.getElementById("deployButton") as HTMLButtonElement;
const boardDiv = document.getElementById("board") as HTMLElement;

connectButton.onclick = async () => {
  if (window.Ethereum) {
    provider = new Web3Provider(window.Ethereum);
    await provider.send("eth_requestAccounts", []);
    signer = provider.getSigner();
    const address = await signer.getAddress();
    accountArea.textContent = `Connected as: ${address}`;
    connectButton.style.display = "none";
    deployButton.style.display = "inline-block";
  } else {
    alert("Metamask not found");
  }
};

deployButton.onclick = async () => {
  const factory = new ethers.ContractFactory(abi, bytecode, signer);
  contract = await factory.deploy();
  await contract.deployed();
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
        const cellValue: number = cellRaw.toNumber ? cellRaw.toNumber() : cellRaw;
        updateCell(i, j, cellValue);
      }
    }
  } catch (e) {
    console.error(e);
  }
}

function updateCell(row: number, col: number, cellValue: number) {
  const cell = document.getElementById(`cell-${row}-${col}`);
  if (!cell) return;
  // 0 = hidden, 1 = empty, 2 = mine, >2 = number with offset.
  if (cellValue === 0) {
    cell.className = "cell hidden";
    cell.textContent = "";
  } else if (cellValue === 2) {
    cell.className = "cell mine";
    cell.textContent = "💣";
  } else if (cellValue === 1) {
    cell.className = "cell empty";
    cell.textContent = "0";
  } else {
    cell.className = "cell revealed";
    // Assuming enum: one = 3, so subtract one to show number.
    cell.textContent = (cellValue - 2).toString();
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
