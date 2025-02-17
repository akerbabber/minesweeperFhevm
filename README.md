# Minesweeper FHEVM

A decentralized Minesweeper game powered by fhevm and TFHE for fully homomorphic encryption on Ethereum.

## Overview

This project demonstrates a Minesweeper game where mine positions and hints are handled with encrypted operations. The smart contract uses fhevm tools along with Hardhat for development.

## Installation

- Install dependencies:  
```bash
  npm install
  ```

- Compile contracts and bundle the frontend:  
```bash
  npm run build
```
- Run the frontend
```bash
  npm run run
```
## Usage

- Deploy the contract on sepolia using the frontend. The deployer becomes the only authorized player and can call `pickMine`.
- Interact with the contract through the web interface, by just pressing hidden cells.


## License

MIT
