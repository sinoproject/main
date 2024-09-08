const {background} = require('./lib/background.js');
const {config} = require('./lib/config.js');
const {contracts} = require('./lib/contracts.js');
const {logger} = require('./lib/logger.js');
const {service} = require('./lib/service.js');
const {storage} = require('./lib/storage.js');
const {util} = require('./lib/util.js');

module.exports = {
    background: background,
    config: config,
    contracts: contracts,
    logger: logger,
    service: service,
    storage: storage,
    util: util
};
