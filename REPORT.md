# Project Report

## What I Did

- I first red the whole fhevm documentation to get ready to apply it to smart contracts and understand its workings
- Integrated TFHE-based fully homomorphic encryption in the Minesweeper smart contract.
- Made sure to rapresent the 16x16 board as an encrypted random number of 256 bits to save gas.
- Generated the board starting from two generated 256 bit number, using the bitwise AND operator to limit the amount of
  1s in the board, 1 = mine.
- Used TFHE lib math function to check a cell and it's neighboors to determine if a mine is present and how many
  neighbouring mines exists around the cell. All while the board is encrypted.
- Added an onlyPlayer modifier to restrict game actions to the deployer.
- Built a simple plain ts frontend to deploy the contract and interact with it.
- Updated the README to reflect installation, usage, and project details.

## What Went Well

- The integration of fhevm functions was straightforward.
- The minesweeper game works properly by showing mines and computing correctly the surrounding mines.
- I have learnt how to hide secrets in smart contract thanks to fhEVM.

## What Did Not Go So Well

- I could not make sure that when an empty cell is shown the surrounding cell should be shown too. I have made two
  attempts. The first recursively, which is commented out in the Minesweeeper.sol contract, the transaction failed, this
  is probably because calling decryption from the Gateway itself is not allowed. The second iteratively, as shown in
  MinesweeeperIterative.sol, but once i discovered the TFHE.select only allows for encrypted operators, I left it since
  I would had to encrypt the iterators, which was not raccomended by the documentation.
- I did all the testing and development on sepolia right away, not setting up a local development EVM machine.
- There are no tests.
- The contract never reaches the win or lose state, this is for two reasons, I want the Minesweeper game to be playable
  even after a mine is choosen to enable the user to reveal more cells and verify the correctness of the generated
  board. Regarding the win state, an encrypted variable should be added that stores the total amount of mines in the
  board, so that when the number of hidden cells is equal to the amount of mines the game is won.

## Future Improvements

If I had more time, I would:

- Test the contract extensively setting up a local environment, using tecniques like fuzzy, invariant and BTT testing.
- Write the proper natspec documentation.
- Explored solutions to reveal multiple empty cells that do not have surrounding mines at once.
- The interaction is slow, callbacks are called after 2 minutes on average, I would have investigated if there is some
  way to make the UX better.
- Refine the frontend integration for a better user experience.
- Used a proxy pattern (probably clones) to make the deployment of a game contract less expensive.
