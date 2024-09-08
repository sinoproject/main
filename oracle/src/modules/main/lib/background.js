const {logger} = require('./logger.js');
const {service} = require('./service.js');
const {storage} = require('./storage.js');

const background = {};
background.INITIAL_ENQUEUE_UNPROCESSED_REQUESTS_MINUTES = null;
background.RECURRING_ENQUEUE_UNPROCESSED_REQUESTS_MINUTES = null;

background.run = async function () {

    // ON START: listen for (and enqueue) new random number requests via WebSocket.
    await background.listenOnChainEvents();

    // ON START: fetch (and enqueue) recent unprocessed random number requests via RPC.
    // It's a fallback in case we restarted the service, so Websocket was down for a few seconds/minutes.
    await background.initialEnqueueUnprocessedRequests();

    // RECURRING: every 2 seconds, process a chunk of queued random number requests
    await background.registerInterval(
        background.processRequests,
        2000,
        true
    );

    // RECURRING: every 10 minutes, inject gas price into contract
    await background.registerInterval(
        background.injectGasPriceIntoContract,
        600 * 1000,
        true
    );

    // RECURRING: fetch (and enqueue) recent unprocessed random number requests via RPC.
    // It's a fallback in case WebSocket skipped a few messages.
    await background.registerInterval(
        background.recurringEnqueueUnprocessedRequests,
        background.RECURRING_ENQUEUE_UNPROCESSED_REQUESTS_MINUTES * 60 * 1000
    );

    // RECURRING: every 10 minutes, cleanup tracker of recently processed random number requests
    await background.registerInterval(
        background.deleteOldRecentlyProcessedRequests,
        600 * 1000
    );
};

background.registerInterval = async function (workerFunction, ms, alsoExecuteNow=false) {
    if (alsoExecuteNow) {
        await workerFunction();
    }
    setInterval(workerFunction, ms);
};

background.listenOnChainEvents = async function () {
    try {
        await service.listenOnChainEvents();
    } catch(err) {
        logger.error({
            message: err.toString(),
            xErrorDetails: err,
        });
    }
};

background.initialEnqueueUnprocessedRequests = async function () {
    try {
        logger.info(`background.initialEnqueueUnprocessedRequests`);
        const sinceMinutesAgo = background.INITIAL_ENQUEUE_UNPROCESSED_REQUESTS_MINUTES;
        await service.fetchRecentUnprocessedRequestsFromChainAndEnqueueThem(sinceMinutesAgo);
    } catch(err) {
        logger.error({
            message: err.toString(),
            xErrorDetails: err,
        });
    }
};

background.recurringEnqueueUnprocessedRequests = async function () {
    try {
        // logger.info(`background.recurringEnqueueUnprocessedRequests`);
        const sinceMinutesAgo = background.RECURRING_ENQUEUE_UNPROCESSED_REQUESTS_MINUTES;
        await service.fetchRecentUnprocessedRequestsFromChainAndEnqueueThem(sinceMinutesAgo);
    } catch(err) {
        logger.error({
            message: err.toString(),
            xErrorDetails: err,
        });
    }
};

background.processRequests = async function () {
    try {
        await service.processRequests();
    } catch(err) {
        logger.error({
            message: err.toString(),
            xErrorDetails: err,
        });
    }
};

background.deleteOldRecentlyProcessedRequests = async function () {
    try {
        const olderThanMinutesAgo = 30;
        await storage.deleteOldRecentlyProcessedRequests(olderThanMinutesAgo);
    } catch(err) {
        logger.error({
            message: err.toString(),
            xErrorDetails: err,
        });
    }
};

background.injectGasPriceIntoContract = async function () {
    try {
        await service.executeSetGasPriceWeiOnTheContract();
    } catch(err) {
        logger.error({
            message: err.toString(),
            xErrorDetails: err,
        });
    }
};

module.exports = {
    background: background
};
