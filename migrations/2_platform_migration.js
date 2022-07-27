const { deployProxy, upgradeProxy } = require("@openzeppelin/truffle-upgrades");

const PollPlatformv2 = artifacts.require("PollPlatformv2");

module.exports = async function (deployer) {
  const instance = await deployProxy(PollPlatformv2, [], { deployer });
  const upgraded = await upgradeProxy(instance.address, PollPlatformv2, { deployer });
};