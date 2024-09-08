const asyncNode = require('async');
const crypto = require('crypto');
const {contracts} = require('./contracts.js');
const {ethers} = require('ethers');
const {logger} = require('./logger.js');
const {storage} = require('./storage.js');
const {util} = require('./util.js');

const service = {};
service._ethersProviderJsonRpcObjects = null;
service.lastInjectedGasPriceMS = null;
service.BLOCKS_PER_MINUTE = null;
service.CHAIN_ID = null;
service.CONCURRENT_REQUESTS_TO_PROCESS = null;
service.OPERATOR_WALLET_ADDRESS = null;
service.OPERATOR_WALLET_PK = null;
service.PROVIDER_HTTP_URL = null;
service.PROVIDER_WEBSOCKET_URL = null;

service.getEthersProviderRpcObjects = function () {
    if (service._ethersProviderJsonRpcObjects) {
        return service._ethersProviderJsonRpcObjects;
    }
    const provider = new ethers.providers.JsonRpcProvider(service.PROVIDER_HTTP_URL);
    const signer = new ethers.Wallet(service.OPERATOR_WALLET_PK, provider);
    const ethersContractRandomizerProxy = new ethers.Contract(
        contracts.RandomizerProxy.address,
        contracts.RandomizerProxy.abi,
        signer
    );
    const objectToReturn = {
        ethersContractRandomizerProxy: ethersContractRandomizerProxy,
        provider: provider,
        signer: signer,
    };
    service._ethersProviderJsonRpcObjects = objectToReturn;
    return objectToReturn;
}

service.getEthersProviderWebSocket = function () {
    const ethersProvider = new ethers.providers.WebSocketProvider(service.PROVIDER_WEBSOCKET_URL);
    return ethersProvider;
};

service.listenOnChainEvents = async function () {

    const WS_EXPECTED_PONG_BACK = 15000; // 15 sec
    const WS_KEEP_ALIVE_CHECK_INTERVAL = 7500; // 7.5 sec
    let pingTimeout = null;
    let keepAliveInterval = null;

    // Connect to WebSocket, implement auto-reconnect
    // (got the idea from https://github.com/ethers-io/ethers.js/issues/1053)
    const ethersProvider = service.getEthersProviderWebSocket();

    ethersProvider._websocket.on('open', async function () {
        logger.info('service.listenOnChainEvents - opened WebSocket connection');

        keepAliveInterval = setInterval(function () {
            ethersProvider._websocket.ping();
            pingTimeout = setTimeout(function () {
                logger.info('service.listenOnChainEvents - not received pong, so closing the WebSocket connection');
                ethersProvider._websocket.terminate();
            }, WS_EXPECTED_PONG_BACK);
        }, WS_KEEP_ALIVE_CHECK_INTERVAL);

        service.addListenersForOnchainEvents(ethersProvider);
    });

    ethersProvider._websocket.on('pong', async function () {
        clearInterval(pingTimeout);
    });

    ethersProvider._websocket.on('close', async function () {
        logger.info('service.listenOnChainEvents - closed WebSocket connection, will auto-reopen shortly');
        ethersProvider._websocket.terminate();
        clearInterval(keepAliveInterval);
        clearTimeout(pingTimeout);
        await util.sleep(3000);
        service.listenOnChainEvents();
    });
};

service.addListenersForOnchainEvents = function (ethersProviderWebSocket) {
    const interfaceForParsing = new ethers.utils.Interface(contracts.RandomizerProxy.abi);
    const ethersContractRandomizerProxy = new ethers.Contract(
        contracts.RandomizerProxy.address,
        contracts.RandomizerProxy.abi,
        ethersProviderWebSocket
    );
    ethersContractRandomizerProxy.on('*', async function(event) {
        if (event.event === 'RequestReceived') {
            const parsedEvent = interfaceForParsing.parseLog(event);
            const requestId = parseInt(parsedEvent.args.requestId);
            await storage.appendItemsToQueue('RequestReceived', [parsedEvent]);
            logger.info({
                message: 'WebSocket event: RequestReceived',
                xRequestId: requestId,
                xContractEvent: 'RequestReceived',
            });
            return;
        }
        if (event.event === 'RequestFulfilled') {
            const parsedEvent = interfaceForParsing.parseLog(event);
            const requestId = parseInt(parsedEvent.args.requestId);
            logger.info({
                message: 'WebSocket event: RequestFulfilled',
                xRequestId: requestId,
                xContractEvent: 'RequestFulfilled',
            });
        }
    });
};

service.fetchRecentUnprocessedRequestsFromChainAndEnqueueThem = async function (sinceMinutesAgo) {
    if (!sinceMinutesAgo) {
        return;
    }

    const { provider } = service.getEthersProviderRpcObjects();
    const latestBlockNumber = await provider.getBlockNumber();
    if (!latestBlockNumber) {
        logger.error('Could not fetch latest block number using RPC');
        return;
    }
    const sinceBlockNumber = parseInt(latestBlockNumber) - ((sinceMinutesAgo+1) * service.BLOCKS_PER_MINUTE);
    const recentRequestReceivedEvents = await service.fetchRequestReceivedEventsFromChain(sinceBlockNumber, latestBlockNumber);
    const recentRequestFulfilledEvents = await service.fetchRequestFulfilledEventsFromChain(sinceBlockNumber, latestBlockNumber);

    if (recentRequestReceivedEvents.length === recentRequestFulfilledEvents) {
        return;
    }

    const isRequestFulfilled = {};
    for (const parsedEvent of recentRequestFulfilledEvents) {
        const requestId = parseInt(parsedEvent.args.requestId);
        isRequestFulfilled[requestId] = true;
    }

    const requestReceivedEventsToEnqueue = [];
    for (const parsedEvent of recentRequestReceivedEvents) {
        const requestId = parseInt(parsedEvent.args.requestId);
        if (!isRequestFulfilled[requestId]) {
            requestReceivedEventsToEnqueue.push(parsedEvent);
            logger.info({
                message: 'RPC event: RequestReceived',
                xRequestId: requestId,
                xContractEvent: 'RequestReceived',
            });
        }
    }

    storage.appendItemsToQueue('RequestReceived', requestReceivedEventsToEnqueue);
};

service.fetchRequestReceivedEventsFromChain = async function (fromBlockNumber, toBlockNumber) {
    // https://docs.ethers.org/v5/api/providers/types/#providers-EventFilter
    // https://docs.ethers.org/v5/concepts/events/#events--filters
    const arrayToReturn = [];
    const { provider } = service.getEthersProviderRpcObjects();
    const interfaceForParsing = new ethers.utils.Interface(contracts.RandomizerProxy.abi);
    const filter = [ethers.utils.id('RequestReceived(uint256)')];
    const events = await provider.getLogs({
        fromBlock: parseInt(fromBlockNumber),
        toBlock: parseInt(toBlockNumber),
        address: contracts.RandomizerProxy.address,
        topics: filter,
    });
    for (const event of events) {
        const parsedEvent = interfaceForParsing.parseLog(event);
        if (parsedEvent.name === 'RequestReceived') {
            arrayToReturn.push(parsedEvent);
        }
    }
    return arrayToReturn;
};

service.fetchRequestFulfilledEventsFromChain = async function (fromBlockNumber, toBlockNumber) {
    // https://docs.ethers.org/v5/api/providers/types/#providers-EventFilter
    // https://docs.ethers.org/v5/concepts/events/#events--filters
    const arrayToReturn = [];
    const { provider } = service.getEthersProviderRpcObjects();
    const interfaceForParsing = new ethers.utils.Interface(contracts.RandomizerProxy.abi);
    const filter = [ethers.utils.id('RequestFulfilled(uint256,uint256)')];
    const events = await provider.getLogs({
        fromBlock: parseInt(fromBlockNumber),
        toBlock: parseInt(toBlockNumber),
        address: contracts.RandomizerProxy.address,
        topics: filter,
    });
    for (const event of events) {
        const parsedEvent = interfaceForParsing.parseLog(event);
        if (parsedEvent.name === 'RequestFulfilled') {
            arrayToReturn.push(parsedEvent);
        }
    }
    return arrayToReturn;
};

service.processRequests = async function () {
    const requestReceivedParsedEvents = storage.getNextQueueItemsToProcess('RequestReceived', service.CONCURRENT_REQUESTS_TO_PROCESS);
    await asyncNode.eachLimit(requestReceivedParsedEvents, service.CONCURRENT_REQUESTS_TO_PROCESS, async function (requestReceivedParsedEvent) {
        await service.processIndividualRequest(requestReceivedParsedEvent);
    });
};

service.processIndividualRequest = async function (requestReceivedParsedEvent) {
    const requestId = parseInt(requestReceivedParsedEvent.args.requestId);
    if (storage.isRecentlyProcessedRequest(requestId)) {
        return;
    }
    try {
        const randomNumber = crypto.randomInt(1, 10001); // between 1 and 10,000
        await service.executeRandomizerCallbackOnTheContract(requestId, randomNumber);
        logger.info({
            message: 'Executed randomizerCallback on the contract',
            xRequestId: requestId,
            xRandomNumber: randomNumber,
        });
        storage.setRecentlyProcessedRequest(requestId);
    } catch (err) {
        storage.prependItemsToQueue('RequestReceived', [requestReceivedParsedEvent]);
        logger.error({
            message: 'Error processing random number request (now put back to top of queue)',
            xRequestId: requestId,
            xErrorDetails: err,
        });
    }
};

service.executeRandomizerCallbackOnTheContract = async function (requestId, randomNumber) {

    // Simple version
    const { ethersContractRandomizerProxy } = service.getEthersProviderRpcObjects();
    const submittedTx = await ethersContractRandomizerProxy.randomizerCallback(requestId, randomNumber);
    const receipt = await submittedTx.wait();

    // // Simple version with gas limit override
    // const { ethersContractRandomizerProxy } = service.getEthersProviderRpcObjects();
    // const overrides = {
    //     gasLimit: ethers.utils.hexlify(2000000)
    // };
    // const submittedTx = await ethersContractRandomizerProxy.randomizerCallback(requestId, randomNumber, overrides);
    // const receipt = await submittedTx.wait();

    // // Extended version
    // const { ethersContractRandomizerProxy, provider, signer } = service.getEthersProviderRpcObjects();
    // const estimatedGasLimitRaw = await ethersContractRandomizerProxy.estimateGas.randomizerCallback(requestId, randomNumber);
    // const estimatedGasLimit = parseInt(parseFloat(estimatedGasLimitRaw) * 1.2); // increase by 20% just to be safe
    // const txUnsigned = await ethersContractRandomizerProxy.populateTransaction.randomizerCallback(requestId, randomNumber);
    // txUnsigned.chainId = parseInt(service.CHAIN_ID);
    // txUnsigned.gasLimit = estimatedGasLimit;
    // txUnsigned.gasPrice = await provider.getGasPrice();
    // txUnsigned.nonce = await provider.getTransactionCount(service.OPERATOR_WALLET_ADDRESS);
    // // console.log(txUnsigned);
    // const txSigned = await signer.signTransaction(txUnsigned);
    // const submittedTx = await provider.sendTransaction(txSigned);
    // const receipt = await submittedTx.wait();
    // return receipt.transactionHash;
}

service.executeSetGasPriceWeiOnTheContract = async function () {

    // Fetch gas price from chain
    const { ethersContractRandomizerProxy, provider } = service.getEthersProviderRpcObjects();
    const nowMS = (new Date()).getTime();
    let gasPriceWei = await provider.getGasPrice();
    gasPriceWei = BigInt(gasPriceWei);

    // Increase gas price we inject. This will make Casino contract get an higher
    // estimated fee when it asks the RandomizerProxy contract. Just to be safe.
    gasPriceWei = gasPriceWei * BigInt(2);

    // If gas price equals the one injected on chain, then don't do anything
    if (
        storage.lastInjectedGasPrice
        && BigInt(gasPriceWei) == BigInt(storage.lastInjectedGasPrice)
    ) {
        return;
    }

    // If gas price is less than the one injected on chain but we injected
    // that less than 2H ago, then don't do anything. This reduces the frequency
    // (and cost) of injecting transactions.
    if (
        storage.lastInjectedGasPrice
        && BigInt(gasPriceWei) < BigInt(storage.lastInjectedGasPrice)
        && service.lastInjectedGasPriceMS
        && (nowMS - service.lastInjectedGasPriceMS) < (7200*1000)
    ) {
        return;
    }

    // Inject gas price into the randomizer contract
    const triggerCasinoUpdateRandomizerCallbackFee = true;
    const submittedTx = await ethersContractRandomizerProxy.setGasPriceWei(gasPriceWei, triggerCasinoUpdateRandomizerCallbackFee);
    const receipt = await submittedTx.wait();
    storage.lastInjectedGasPrice = gasPriceWei;
    service.lastInjectedGasPriceMS = (new Date()).getTime();
    logger.info({
        message: 'Executed setGasPriceWei on the contract',
        xGasPriceWei: gasPriceWei.toString(),
    });
}

module.exports = {
    service: service
};
