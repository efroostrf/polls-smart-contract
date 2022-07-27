const { deployProxy, upgradeProxy } = require("@openzeppelin/truffle-upgrades");

const MyToken = artifacts.require("MyToken");

module.exports = async function (deployer) {
  const instance = await deployProxy(MyToken, [], { deployer });
  const upgraded = await upgradeProxy(instance.address, MyToken, { deployer });
};
