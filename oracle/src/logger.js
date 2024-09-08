const {transports, format, createLogger} = require('winston');

// const level = (process.env.NODE_ENV === 'production') ? 'error' : 'debug';
const level = 'info';

const logger = createLogger({
    level: level,
    format: format.combine(
        format.timestamp(),
        format.errors({stack: true}),
        format.json()
    ),
    defaultMeta: {
        // service: 'oraclerandomizer',
        // environment: process.env.NODE_ENV
    },
    exitOnError: false,
    transports: [new transports.Console()]
});

module.exports = {
    logger: logger
};
