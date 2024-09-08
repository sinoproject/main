require('dotenv').config();
const express = require('express');
const { ethers } = require('ethers');

// Configuration - Read environment variables once
const PORT = process.env.PORT || 3000;
const OPERATOR_WALLET_PK = process.env.OPERATOR_WALLET_PK;
const PROVIDER_HTTP_URL = process.env.PROVIDER_HTTP_URL;
const CASINO_TOKEN_CONTRACT_ADDRESS = process.env.CASINO_TOKEN_CONTRACT_ADDRESS;
const DAILY_LIMIT = parseFloat(process.env.DAILY_LIMIT);
const CASINO_TOKEN_AMOUNT = parseFloat(process.env.CASINO_TOKEN_AMOUNT);
const ETH_AMOUNT = parseFloat(process.env.ETH_AMOUNT);

// Keep track of tokens sent today, so we can impose hard limits
let recipientAddressesToday = [];
let casinoTokensSentToday = 0;
let lastReset = new Date().setHours(0, 0, 0, 0); // Midnight today

// Ethers.js setup
const provider = new ethers.providers.JsonRpcProvider(PROVIDER_HTTP_URL);
const wallet = new ethers.Wallet(OPERATOR_WALLET_PK, provider);
const casinoTokenContract = new ethers.Contract(
    CASINO_TOKEN_CONTRACT_ADDRESS,
    [
        'function transfer(address to, uint amount)',
    ],
    wallet
);

// Simple logger
const logger = {
    add: function (level, message, extraParams) {
        console.log(JSON.stringify({
            level: level,
            message: message,
            ...extraParams,
            timestamp: (new Date()).toISOString(),
        }));
    },
    error: function (message, extraParams) {
        this.add('error', message, extraParams);
    },
    info: function (message, extraParams) {
        this.add('info', message, extraParams);
    },
};

// Start Express
const app = express();
app.use(express.json());

// Middleware to reset counter daily
const resetDailyCounter = (req, res, next) => {
    const now = new Date();
    if (now.setHours(0, 0, 0, 0) !== lastReset) {
        recipientAddressesToday = [];
        casinoTokensSentToday = 0;
        lastReset = now.setHours(0, 0, 0, 0);
    }
    next();
};

// Endpoints
app.get('/', async (req, res) => {
    return res.status(200).json({ message: 'Faucet up and running' });
});

app.post('/send', resetDailyCounter, async (req, res) => {
    const { destinationAddress } = req.body;

    if (!ethers.utils.isAddress(destinationAddress)) {
        const error = 'Invalid destinationAddress, it should be a valid Ethereum address';
        logger.error(error, {destinationAddress: destinationAddress});
        return res.status(400).json({ error: error });
    }

    if (recipientAddressesToday.indexOf(destinationAddress) !== -1) {
        const error = 'Already sent tokens to this address today, retry again after 00:00 GMT tomorrow';
        logger.error(error, {destinationAddress: destinationAddress});
        return res.status(403).json({ error: error });
    }

    if (casinoTokensSentToday + parseFloat(CASINO_TOKEN_AMOUNT) > parseFloat(DAILY_LIMIT)) {
        const error = 'Daily casino token limit reached';
        logger.error(error);
        return res.status(403).json({ error: error });
    }

    try {
        // Send ETH
        const ethAmountWei = ethers.utils.parseUnits(ETH_AMOUNT.toString(), 'ether');
        const ethTx = await wallet.sendTransaction({
            to: destinationAddress,
            value: ethAmountWei
        });
        await ethTx.wait(); // Wait for the transaction to be mined

        // Send Casino Tokens
        const casinoTokenAmountWei = ethers.utils.parseUnits(CASINO_TOKEN_AMOUNT.toString(), 'ether');
        const casinoTokenTx = await casinoTokenContract.transfer(destinationAddress, casinoTokenAmountWei);
        await casinoTokenTx.wait(); // Wait for the transaction to be mined

        // Update the daily trackers
        recipientAddressesToday.push(destinationAddress);
        casinoTokensSentToday += parseFloat(CASINO_TOKEN_AMOUNT);

        // Log and respond
        const message = `Sent ${ETH_AMOUNT} ETH and ${CASINO_TOKEN_AMOUNT} casino tokens successfully`;
        const infoObject = {
            destinationAddress: destinationAddress,
            ethTransactionHash: ethTx.hash,
            casinoTokenTransactionHash: casinoTokenTx.hash,
            timestamp: (new Date()).toISOString(),
        };
        logger.info(message, infoObject);
        res.json({message: message, ...infoObject,});

    } catch (err) {
        logger.error('Error sending casino tokens or ETH:', {errorDetails: err.toString()});
        res.status(500).json({ error: 'Failed to process the transaction' });
    }
});

app.listen(PORT, () => {
    logger.info(`Server running on port ${PORT}`);
});
