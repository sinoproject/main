const someMiddleware = function(req, res, next) {
    return next();
};

module.exports = {
    someMiddleware: someMiddleware
};
