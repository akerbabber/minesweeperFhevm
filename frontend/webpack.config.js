const path = require("path");

module.exports = {
  entry: "./src/main.ts", // corrected entry path relative to the frontend folder
  output: {
    path: path.resolve(__dirname, "dist"),
    filename: "main.js",
  },
  resolve: {
    extensions: [".ts", ".js"],
    alias: {
      process: "process/browser",
    },
  },
  module: {
    rules: [
      {
        test: /\.ts$/,
        use: "ts-loader",
        exclude: /node_modules/,
      },
    ],
  },
  mode: "development", // or "production" as needed
};
