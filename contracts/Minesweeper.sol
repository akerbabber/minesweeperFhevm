// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import { SepoliaZamaFHEVMConfig } from "fhevm/config/ZamaFHEVMConfig.sol";
import { SepoliaZamaGatewayConfig } from "fhevm/config/ZamaGatewayConfig.sol";
import "fhevm/gateway/GatewayCaller.sol";

/**
 * @title Minesweeper
 * @notice A decentralized Minesweeper game where operations on encrypted data are performed using fhevm.
 * @dev The contract uses TFHE for fully homomorphic encryption and integrates authorization with an onlyPlayer modifier.
 */
contract Minesweeper is SepoliaZamaFHEVMConfig, SepoliaZamaGatewayConfig, GatewayCaller {
    euint256 hiddenBoard;
    enum Cell {
        hidden, // 0
        empty, // 1
        mine, // 2
        one, // 3
        two, // 4
        three, // 5
        four, // 6
        five, // 7
        six, // 8
        seven, // 9
        eight // 10
    }

    enum GameState {
        ongoing,
        win,
        lose
    }

    // Public revealed board; default is hidden, rowsxcols = 16x16
    Cell[16][16] public board;

    // Game state
    GameState public state;

    address public immutable player;

    modifier onlyPlayer() {
        require(msg.sender == player, "Not authorized");
        _;
    }

    /**
     * @notice Constructs the Minesweeper contract and sets the deployer as the player.
     */
    constructor() {
        player = msg.sender;
        // Initialize the board
        generateBoard();
    }

    /**
     * @notice Generates a new random encrypted game board.
     * @dev Combines two random 256-bit numbers using AND to reduce mine probability.
     */
    function generateBoard() public {
        // Generate a random board by using AND operation to lower the probability of mines
        euint256 firstGen = TFHE.randEuint256();
        euint256 secondGen = TFHE.randEuint256();
        hiddenBoard = TFHE.and(firstGen, secondGen);
        TFHE.allowThis(hiddenBoard);
    }

    /**
     * @notice Allows the authorized player to reveal a cell.
     * @param row The row index of the cell.
     * @param col The column index of the cell.
     * @dev Calls Gateway.requestDecryption to determine if the cell is mined and the count of surrounding mines.
     */
    function pickMine(uint8 row, uint8 col) public onlyPlayer {
        // Check if the cell is not already revealed
        if (board[row][col] != Cell.hidden) {
            return;
        }
        uint8 index = getIndex(row, col);
        // Check if the cell is mined
        ebool hiddenCell = TFHE.asEbool(TFHE.shr(TFHE.shl(hiddenBoard, index), 255));
        TFHE.allowThis(hiddenCell);
        euint8 hiddenSurroundingCells = getSurroundingCells(row, col);
        euint8 numberOfSurroundingMines = getNumberSurroundingMines(hiddenSurroundingCells);
        TFHE.allowThis(numberOfSurroundingMines);
        uint256[] memory cts = new uint256[](2);
        cts[0] = Gateway.toUint256(hiddenCell);
        cts[1] = Gateway.toUint256(numberOfSurroundingMines);
        uint requestID = Gateway.requestDecryption(
            cts,
            this.pickMineCallback.selector,
            0,
            block.timestamp + 1000,
            false
        );
        addParamsUint256(requestID, uint(row));
        addParamsUint256(requestID, uint(col));
    }

    /**
     * @notice Callback function from the gateway after decryption.
     * @param requestId The identifier of the decryption request.
     * @param decryptedCell The result indicating if the cell was mined.
     * @param decryptedNumberOfSurroundingMines The decrypted count of surrounding mines.
     * @dev Updates the board and game state based on the decryption results.
     */
    function pickMineCallback(
        uint requestId,
        bool decryptedCell,
        uint8 decryptedNumberOfSurroundingMines
    ) external onlyGateway {
        uint[] memory params = getParamsUint256(requestId);
        uint row = params[0];
        uint col = params[1];
        if (decryptedCell) {
            board[row][col] = Cell.mine;
            state = GameState.lose;
        } else {
            if (decryptedNumberOfSurroundingMines == 0) {
                // Pick surrounding cells
                board[row][col] = Cell.empty;
                // for (uint i = 0; i < 8; i++) {
                //     int8 newRow = int8(uint8(row)) + [-1, -1, -1, 0, 0, 1, 1, 1][i];
                //     int8 newCol = int8(uint8(col)) + [-1, 0, 1, -1, 1, -1, 0, 1][i];
                //     if (newRow >= 0 && newRow < 16 && newCol >= 0 && newCol < 16) {
                //         pickMine(uint8(newRow), uint8(newCol));
                //     }
                // }
            } else {
                if (decryptedNumberOfSurroundingMines == 1) board[row][col] = Cell.one;
                else if (decryptedNumberOfSurroundingMines == 2) board[row][col] = Cell.two;
                else if (decryptedNumberOfSurroundingMines == 3) board[row][col] = Cell.three;
                else if (decryptedNumberOfSurroundingMines == 4) board[row][col] = Cell.four;
                else if (decryptedNumberOfSurroundingMines == 5) board[row][col] = Cell.five;
                else if (decryptedNumberOfSurroundingMines == 6) board[row][col] = Cell.six;
                else if (decryptedNumberOfSurroundingMines == 7) board[row][col] = Cell.seven;
                else if (decryptedNumberOfSurroundingMines == 8) board[row][col] = Cell.eight;
            }
        }
    }

    /**
     * @notice Calculates the one-dimensional index from 2D board coordinates.
     * @param row The row index.
     * @param col The column index.
     * @return The computed index.
     */
    function getIndex(uint8 row, uint8 col) public pure returns (uint8) {
        return row * 16 + col;
    }

    /**
     * @notice Retrieves encrypted values of neighboring cells.
     * @param row The row index of the target cell.
     * @param col The column index of the target cell.
     * @return An encrypted uint8 representing neighboring cells bits.
     * @dev Iterates through all 8 neighbors using relative offsets.
     */
    function getSurroundingCells(uint8 row, uint8 col) internal returns (euint8) {
        // Initialize encrypted result as 0 (pseudo-code; adjust with actual TFHE method)
        euint8 surroundingCells = TFHE.asEuint8(0);
        // Relative positions for neighbors in order:
        // 0: (-1,-1), 1: (-1,0), 2: (-1,+1), 3: (0,-1), 4: (0,+1), 5: (+1,-1), 6: (+1,0), 7: (+1,+1)
        int8[8] memory dRow = [-1, -1, -1, 0, 0, 1, 1, 1];
        int8[8] memory dCol = [-1, 0, 1, -1, 1, -1, 0, 1];
        for (uint8 i = 0; i < 8; i++) {
            int16 newRow = int16(uint16(row)) + dRow[i];
            int16 newCol = int16(uint16(col)) + dCol[i];
            if (newRow >= 0 && newRow < 16 && newCol >= 0 && newCol < 16) {
                uint8 idx = getIndex(uint8(int8(newRow)), uint8(int8(newCol)));
                // Extract the neighbor bit encrypted, similar to pickMine.
                ebool neighborBit = TFHE.asEbool(TFHE.shr(TFHE.shl(hiddenBoard, idx), 255));
                // Convert the boolean to an encrypted uint8: 1 if true, 0 if false.
                euint8 encryptedBit = TFHE.select(neighborBit, TFHE.asEuint8(1), TFHE.asEuint8(0));
                // Shift the encrypted bit left by i bits to position it in the result.
                euint8 shiftedBit = TFHE.shl(encryptedBit, i);
                // Add the shifted bit to the encrypted surroundingCells result.
                surroundingCells = TFHE.add(surroundingCells, shiftedBit);
            }
            // If out-of-bound, the bit remains 0.
        }
        return surroundingCells;
    }

    /**
     * @notice Sums the bits that indicate mines in the surrounding cells.
     * @param surroundingCells The encrypted representation of surrounding cells.
     * @return The encrypted count of surrounding mines.
     */
    function getNumberSurroundingMines(euint8 surroundingCells) internal returns (euint8) {
        // Initialize encrypted result as 0
        euint8 numberOfSurroundingMines = TFHE.asEuint8(0);
        for (uint8 i = 0; i < 8; i++) {
            // Extract the bit in position i using an AND with 1 after shifting
            euint8 neighborBit = TFHE.and(TFHE.shr(surroundingCells, i), TFHE.asEuint8(1));
            numberOfSurroundingMines = TFHE.add(numberOfSurroundingMines, neighborBit);
        }
        return numberOfSurroundingMines;
    }

    /**
     * @notice Retrieves the current state of the game board.
     * @return The 16x16 board array.
     */
    function getBoard() public view returns (Cell[16][16] memory) {
        return board;
    }
}
