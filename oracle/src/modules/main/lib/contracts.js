const contracts = {};

contracts.setAddress = function (contractName, address) {
    contracts[contractName].address = address;
};

contracts.RandomizerProxy = {
    address: null,
    abi: [
        // Properties
        // TODO if needed

        // Events
        'event RequestReceived(uint256 indexed requestId)',
        'event RequestFulfilled(uint256 indexed requestId, uint256 randomNumber)',

        // Functions
        'function setCallbackGasLimit(uint256 value) public',
        'function setGasPriceWei(uint256 value, bool triggerCasinoUpdateRandomizerCallbackFee) public',
        'function randomizerCallback(uint256 requestId, uint256 randomNumber) external',
    ]
};

module.exports = {
    contracts: contracts
};
