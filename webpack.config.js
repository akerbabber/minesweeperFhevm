const path = require("path");

module.exports = {
  entry: "./frontend/src/main.ts", // correct entry path relative to project root
  output: {
    path: path.resolve(__dirname, "frontend/dist"),
    filename: "main.js",
  },
  resolve: {
    extensions: [".ts", ".js"],
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
