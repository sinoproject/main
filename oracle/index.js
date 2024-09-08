const {config} = require('./config');
const {logger} = require('./src/logger');
const {
    background: mainBackground,
    contracts: mainContracts,
    service: mainService,
    storage: mainStorage,
} = require('./src/modules/main');

// Inject configs into modules
mainBackground.INITIAL_ENQUEUE_UNPROCESSED_REQUESTS_MINUTES = parseInt(config.INITIAL_ENQUEUE_UNPROCESSED_REQUESTS_MINUTES);
mainBackground.RECURRING_ENQUEUE_UNPROCESSED_REQUESTS_MINUTES = parseInt(config.RECURRING_ENQUEUE_UNPROCESSED_REQUESTS_MINUTES);
mainContracts.setAddress('RandomizerProxy', config.RANDOMIZERPROXY_CONTRACT_ADDRESS);
mainService.BLOCKS_PER_MINUTE = parseInt(config.BLOCKS_PER_MINUTE);
mainService.CHAIN_ID = config.CHAIN_ID;
mainService.CONCURRENT_REQUESTS_TO_PROCESS = parseInt(config.CONCURRENT_REQUESTS_TO_PROCESS);
mainService.OPERATOR_WALLET_ADDRESS = config.OPERATOR_WALLET_ADDRESS;
mainService.OPERATOR_WALLET_PK = config.OPERATOR_WALLET_PK;
mainService.PROVIDER_HTTP_URL = config.PROVIDER_HTTP_URL;
mainService.PROVIDER_WEBSOCKET_URL = config.PROVIDER_WEBSOCKET_URL;

// Start background workers
mainBackground.run().catch((err)=>{
    logger.error({
        message: err,
        logType: 'mainBackground.run'
    });
});
