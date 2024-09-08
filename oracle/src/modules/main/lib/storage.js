const storage = {};

storage.queues = {
    RequestReceived: [],
};

// Tracker of last gas price we set into the contract
storage.lastInjectedGasPrice = null;

// Tracker of recently processed requestIds, helps avoid re-processing the same.
// That could happen because we fetch requests from chain via both WebSocket and RPC.
storage.recentlyProcessedRequests = {};



// Queues: functions
storage.appendItemsToQueue = function (queueName, items) {
    if (items.length > 0) {
        const queue = storage.queues[queueName];
        queue.push(...items);
    }
};

storage.getNextQueueItemsToProcess = function (queueName, howManyItems=1) {
    const queue = storage.queues[queueName];
    return queue.splice(0, howManyItems); // return (and delete) x items from top of queue
};

storage.prependItemsToQueue = function (queueName, items) {
    if (items.length > 0) {
        const queue = storage.queues[queueName];
        queue.unshift(...items);
    }
};



// Recently processed requests: functions
storage.deleteOldRecentlyProcessedRequests = function (olderThanMinutesAgo) {
    if (!olderThanMinutesAgo) {
        return;
    }
    const nowDate = new Date();
    const cutoffDate = new Date(nowDate.getTime() - (olderThanMinutesAgo * 60 * 1000));
    const cutoffMS = cutoffDate.getTime();
    for (const requestId in storage.recentlyProcessedRequests) {
        const processedMS = storage.recentlyProcessedRequests[requestId];
        if (processedMS < cutoffMS) {
            delete storage.recentlyProcessedRequests[requestId];
        }
    }
};

storage.isRecentlyProcessedRequest = function (requestId) {
    requestId = parseInt(requestId);
    if (storage.recentlyProcessedRequests[requestId] !== undefined) {
        return true;
    } else {
        return false;
    }
};

storage.setRecentlyProcessedRequest = function (requestId) {
    requestId = parseInt(requestId);
    storage.recentlyProcessedRequests[requestId] = (new Date()).toISOString();
};



module.exports = {
    storage: storage
};
