# Project Report

## What I Did

- Reviewed the fhevm documentation thoroughly to understand its integration with smart contracts.
- Integrated TFHE-based fully homomorphic encryption into the Minesweeper smart contract.
- Represented the 16x16 board as an encrypted 256-bit random number to optimize gas usage.
- Generated the game board by combining two 256-bit numbers with a bitwise AND operator, reducing the probability of
  mines.
- Employed TFHE math functions to evaluate each cell and its neighbors, determining the presence of a mine and counting
  adjacent mines,all while the data remains encrypted.
- Added an onlyPlayer modifier to restrict gameplay actions solely to the deployer.
- Built a simple TypeScript frontend to deploy and interact with the contract.
- Updated the README to include comprehensive installation, usage, and project details.

## What Went Well

- The fhevm function integration was smooth and effective.
- The Minesweeper game operates correctly, accurately revealing mines and computing adjacent mine counts.
- I gained valuable insights into securing smart contracts by hiding sensitive data using FHE.

## What Didn't Go So Well

- Revealing adjacent empty cells automatically remains a challenge:
  - A recursive approach (now commented out) failed due to limitations with decryption callbacks.
  - An iterative approach in `MinesweeeperIterative.sol` was abandoned because TFHE.select only supports encrypted
    operations, making iterator encryption impractical.
- Development was conducted exclusively on the Sepolia network without a local EVM, limiting initial testing
  flexibility.
- The project currently lacks automated tests.
- Code documentation could be more comprehensive.
- The game never transitions to a definitive win or lose state:
  - Minesweeper is designed to remain playable after a mine is triggered, allowing users to reveal additional cells.
    This is easy to implement just by checking the state of the game before picking a cell and in the callback, but i
    did not because the game would be easier to test without it.
  - A proper win state would require tracking the total number of mines and comparing it against remaining hidden cells.

## Future Improvements

If I had more time, I would:

- Set up a local testing environment to implement fuzzy, invariant, and behavior-driven testing.
- Explore robust solutions to reveal multiple adjacent empty cells automatically.
- Investigate methods to reduce interaction latency; currently, decryption callbacks occur with significant delay.
- Refine the frontend integration to improve user experience.
- Consider using a proxy pattern (potentially via contract clones) to reduce deployment costs for new game instances.
