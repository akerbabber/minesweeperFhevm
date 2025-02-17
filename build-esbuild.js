const esbuild = require("esbuild");
const aliasPlugin = require("esbuild-plugin-alias");
const wasmPlugin = require("esbuild-plugin-wasm"); // added new WASM plugin

esbuild
  .build({
    entryPoints: ["./frontend/src/main.ts"],
    bundle: true,
    outdir: "./frontend/dist",
    loader: {
      ".wasm": "file", // tell esbuild to handle .wasm files as files
    },
    plugins: [
      aliasPlugin({
        "tfhe_bg.wasm": require.resolve("tfhe/tfhe_bg.wasm"), // fallback alias
      }),
      wasmPlugin.wasmLoader(), // enable wasm import
    ],
    sourcemap: true,
    platform: "browser",
    target: "es2020",
  })
  .catch(() => process.exit(1));
