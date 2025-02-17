pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import { SepoliaZamaFHEVMConfig } from "fhevm/config/ZamaFHEVMConfig.sol";
import { SepoliaZamaGatewayConfig } from "fhevm/config/ZamaGatewayConfig.sol";
import "fhevm/gateway/GatewayCaller.sol";

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

    constructor() {
        // Initialize the board
        generateBoard();
    }

    function generateBoard() public {
        // Generate a random seed
        hiddenBoard = TFHE.asEuint256(0);
        TFHE.allowThis(hiddenBoard);
    }

    // New struct for holding cell coordinates in the iterative queue.
    struct CellCoord {
        uint8 row;
        uint8 col;
    }

    // Modified pickMine function: Instead of requesting decryption for one cell,
    // it calls iterativeReveal to compute the empty area chunk at once.
    function pickMine(uint8 row, uint8 col) public {
        if (state != GameState.ongoing) {
            return;
        }
        if (board[row][col] != Cell.hidden) {
            return;
        }
        iterativeReveal(row, col);
    }

    // New function: iterativeReveal gathers the chunk of cells to reveal using an iterative approach.
    function iterativeReveal(uint8 startRow, uint8 startCol) internal {
        // Create a dynamic array to simulate a queue.
        CellCoord[] memory queue = new CellCoord[](256); // max capacity (16x16)
        uint index = 0;
        uint end = 0;

        // Use a temporary boolean grid to mark already scheduled cells.
        bool[16][16] memory scheduled;

        // Initialize queue with the starting cell.
        queue[end++] = CellCoord(startRow, startCol);
        scheduled[startRow][startCol] = true;

        // Dynamic array to collect ciphertexts for each queued cell.
        uint totalCells = 0;
        uint256[] memory ctBuffer = new uint256[](512); // two per cell

        // Iterative processing of cell queue.
        while (index < end) {
            CellCoord memory cell = queue[index++];
            uint8 x = cell.row;
            uint8 y = cell.col;
            uint8 idxValue = getIndex(x, y);

            // Get encrypted hidden bit.
            ebool hiddenCell = TFHE.asEbool(TFHE.shr(TFHE.shl(hiddenBoard, idxValue), 255));

            // Get encrypted surrounding cells and count.
            euint8 surrounding = getSurroundingCells(x, y);
            euint8 numMines = getNumberSurroundingMines(surrounding);

            // Append ciphertexts for this cell.
            ctBuffer[totalCells * 2] = Gateway.toUint256(hiddenCell);
            ctBuffer[totalCells * 2 + 1] = Gateway.toUint256(numMines);
            totalCells++;

            // If not a mine candidate and if (conceivably) empty, we schedule neighbors.
            // Note: actual decision will be made after decryption.
            // We use zero sentinel to indicate potential emptiness.
            // For now, add all neighbors that are hidden and unscheduled.
            for (uint8 j = 0; j < 8; j++) {
                int8 newRow = int8(x) + [-1, -1, -1, 0, 0, 1, 1, 1][j];
                int8 newCol = int8(y) + [-1, 0, 1, -1, 1, -1, 0, 1][j];
                if (newRow >= 0 && newRow < 16 && newCol >= 0 && newCol < 16) {
                    uint8 r = uint8(newRow);
                    uint8 c = uint8(newCol);
                    if (!scheduled[r][c] && board[r][c] == Cell.hidden) {
                        // Get encrypted booleans/values
                        ebool _hiddenCell = TFHE.asEbool(TFHE.shr(TFHE.shl(hiddenBoard, getIndex(r, c)), 255));
                        euint8 _surrounding = getSurroundingCells(x, y);

                        // // Combine conditions: cell must not be hidden and must have zero neighbours
                        // ebool condition = TFHE.and(TFHE.eq(_hiddenCell, false), TFHE.eq(_surrounding, uint8(0)));

                        // // Instead of a branch, we use TFHE.select to conditionally update our state.
                        // // (Here we assume that 'end' and scheduled[r][c] can be updated in this manner.)
                        // // Update the queue index if condition is true
                        // uint8 newEnd = TFHE.select(condition, end + 1, end);
                        // // Always write the candidate coordinate; only "commit" the update if condition holds.
                        // queue[end] = CellCoord(r, c);
                        // // Similarly, update the scheduled flag:
                        // scheduled[r][c] = TFHE.select(condition, true, scheduled[r][c]);
                        // // Finalize the update to end:
                        // end = newEnd;
                    }
                }
            }
        }

        // Request a single batch decryption for all queued cells.
        // The callback will receive an array of decrypted pairs.
        uint requestID = Gateway.requestDecryption(
            ctBuffer,
            this.pickMineBatchCallback.selector,
            totalCells, // passing total number of cell pairs to expect
            block.timestamp + 1000,
            false
        );

        // Record the starting index in params to later recover the queued cells.
        // For brevity, assume addParamsUint256 is called per cell in enqueue order.
        for (uint i = 0; i < end; i++) {
            addParamsUint256(requestID, uint(queue[i].row));
            addParamsUint256(requestID, uint(queue[i].col));
        }
    }

    // New batch callback to process the decrypted results from iterativeReveal.
    // It receives a uint[] with 2 decrypted values per cell (hidden bit and number of mines).
    function pickMineBatchCallback(uint requestId, uint[] calldata decryptedValues) external onlyGateway {
        uint[] memory params = getParamsUint256(requestId);
        uint totalCells = params.length / 2;
        for (uint i = 0; i < totalCells; i++) {
            uint row = params[i * 2];
            uint col = params[i * 2 + 1];
            // Each cell's decryption values.
            bool decryptedHidden = (decryptedValues[i * 2] == 1);
            uint8 decryptedMineCount = uint8(decryptedValues[i * 2 + 1]);

            if (decryptedHidden) {
                board[row][col] = Cell.mine;
                state = GameState.lose;
            } else {
                if (decryptedMineCount == 0) {
                    board[row][col] = Cell.empty;
                } else {
                    if (decryptedMineCount == 1) board[row][col] = Cell.one;
                    else if (decryptedMineCount == 2) board[row][col] = Cell.two;
                    else if (decryptedMineCount == 3) board[row][col] = Cell.three;
                    else if (decryptedMineCount == 4) board[row][col] = Cell.four;
                    else if (decryptedMineCount == 5) board[row][col] = Cell.five;
                    else if (decryptedMineCount == 6) board[row][col] = Cell.six;
                    else if (decryptedMineCount == 7) board[row][col] = Cell.seven;
                    else if (decryptedMineCount == 8) board[row][col] = Cell.eight;
                }
            }
        }
        // Optionally, clear queue parameters if needed.
    }

    function getIndex(uint8 row, uint8 col) public pure returns (uint8) {
        return row * 16 + col;
    }

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

    function getNumberSurroundingMines(euint8 surroundingCells) internal returns (euint8) {
        // Initialize encrypted result as 0 (pseudo-code; adjust with actual TFHE method)
        euint8 numberOfSurroundingMines = TFHE.asEuint8(0);
        for (uint8 i = 0; i < 8; i++) {
            // Extract the neighbor bit encrypted, similar to pickMine.
            euint8 neighborBit = TFHE.asEuint8(TFHE.asEbool(TFHE.shr(surroundingCells, i)));
            // Add the neighbor bit to the numberOfSurroundingMines result.
            numberOfSurroundingMines = TFHE.add(numberOfSurroundingMines, neighborBit);
        }
        return numberOfSurroundingMines;
    }

    function getBoard() public view returns (Cell[16][16] memory) {
        return board;
    }
}
