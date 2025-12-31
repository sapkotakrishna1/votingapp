const express = require("express");
const cors = require("cors"); // add this
const { createProxyMiddleware } = require("http-proxy-middleware");

const app = express();

app.use(cors()); // enable CORS

app.use(
  "/rpc",
  createProxyMiddleware({
    target: "http://127.0.0.1:8545", // Ganache RPC URL
    changeOrigin: true,
    pathRewrite: { "^/rpc": "" },
  })
);

app.listen(3000, () => console.log("Proxy running on http://localhost:3000"));
