require('dotenv').config();

let args = {};
process.argv.forEach(function (item) {
    item = item.split('=');
    let name = item[0];
    let value = (item.length > 1) ? item[1] : true;
    args[name] = value;
});

const config = {
    ...process.env,

    args:               args,
    environment:        process.env.NODE_ENV || 'development',

    isProduction: function() {
        return (this.environment === 'production');
    }
};

module.exports = {
    config: config
};
