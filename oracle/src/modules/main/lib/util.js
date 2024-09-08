const fsp = require('fs').promises;
const path = require('path');
const {exec} = require('child_process');

const util = {};

util.bashExecute = function (command) {
    return new Promise((resolve, reject) => {
        exec(command, (error, stdout, stderr) => {
            if (error) {
                reject(error);
            } else if (stderr) {
                reject(stderr);
            } else {
                resolve(stdout);
            }
        });
    });
};

util.sleep = function (ms) {
	return new Promise(resolve => setTimeout(resolve, ms));
};

util.writeNestedFile = async function (diskFilePath, contents) {
    await fsp.mkdir(path.dirname(diskFilePath), { recursive: true });
	await fsp.writeFile(diskFilePath, contents);
};

module.exports = {
    util: util
};
