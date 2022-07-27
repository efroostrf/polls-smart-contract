const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

var deployer, user1, user2 = null;
var token, pollPlatform = null;

const createNewPoll = async (options = 2, secondsToExpire = 60) => {
    return await pollPlatform.createPoll(
        "", 
        options, 
        Date.now() + secondsToExpire * 1000
    );
};

const expirePoll = async (pollId) => await pollPlatform.changePollTime(pollId, 0);

describe("MyToken", () => {
    it("Create deployer", async () => {
        [deployer, user1, user2] = await ethers.getSigners();

        expect(deployer).not.to.be.equal(null);
    });

    it("Deploy to proxy", async () => {
        const MyToken = await ethers.getContractFactory("MyToken", deployer);
        token = await upgrades.deployProxy(MyToken, []);

        await token.deployed();
        expect(token.address).to.be.properAddress;
    });

    it("Mint for accounts", async () => {
        await token.safeMint(user1.address, "");
        await token.safeMint(user2.address, "");
    });
});

describe("PollPlatform", () => {
    describe("Initialize", () => {
        it("Deploy to proxy", async () => {
            const PollPlatform = await ethers.getContractFactory("PollPlatform", deployer);
            pollPlatform = await upgrades.deployProxy(PollPlatform, []);
    
            await pollPlatform.deployed();
            expect(pollPlatform.address).to.be.properAddress;
        });
    
        it("Set token address", async () => {
            await pollPlatform.setTokenAddress(token.address);
        });
    
        it("Set address in MyToken", async () => {
            await token.setPollPlatform(pollPlatform.address);
        });
    });

    describe("New polls & operations with them", () => {
        it("Create new polls", async () => {
            await createNewPoll();
            await createNewPoll();
            await expect(pollPlatform.getPoll(1)).not.to.be.reverted;
        });

        it("Vote from user 1 in first poll", async () => {
            var optionVotes = await pollPlatform.getPollOptions(0);

            expect(optionVotes[0]).to.be.equal(0);

            await pollPlatform.connect(user1).madeVote(0, 0);
            optionVotes = await pollPlatform.getPollOptions(0);

            expect(await pollPlatform.isVoted(0, user1.address)).to.be.equal(true);
            expect(optionVotes[0]).to.be.equal(1);
        });

        it("User 1 can't revote", async () => {
            await expect(pollPlatform.madeVote(0, 1)).to.be.reverted;
        });
        
        it("Transfer NFT from user 1 to user 2", async () => {
            await token.connect(user1).transferFrom(user1.address, user2.address, 0);
            
            const optionVotes = await pollPlatform.getPollOptions(0);
            
            expect(await token.balanceOf(user1.address)).to.be.equal(0);
            expect(await token.balanceOf(user2.address)).to.be.equal(2);
            expect(optionVotes[0]).to.be.equal(0);
        });

        it("User 1 can't vote in second poll without NFTs", async () => {
            await expect(pollPlatform.connect(user1).madeVote(1, 0)).to.be.reverted;
            const votings = await pollPlatform.getVoterVotings(user1.address);
        });
    });
    
    describe("Transfer NFTs", () => {
        it("Vote from user 2 in polls", async () => {
            await expect(pollPlatform.connect(user2).madeVote(0, 1)).not.to.be.reverted;
            await expect(pollPlatform.connect(user2).madeVote(1, 1)).not.to.be.reverted;

            const optionVotes = [
                await pollPlatform.getPollOptions(0),
                await pollPlatform.getPollOptions(1)
            ];

            expect(optionVotes[0][1]).to.be.equal(2);
            expect(optionVotes[1][1]).to.be.equal(2);
        });

        it("Transfer NFTS from user 2 to user 1", async () => {
            await expect(token.connect(user2).transferFrom(user2.address, user1.address, 0)).not.to.be.reverted;
            await expect(token.connect(user2).transferFrom(user2.address, user1.address, 1)).not.to.be.reverted;

            const optionVotes = [
                await pollPlatform.getPollOptions(0),
                await pollPlatform.getPollOptions(1)
            ];

            expect(optionVotes[0][0]).to.be.equal(2);
            expect(optionVotes[0][1]).to.be.equal(0);
            expect(optionVotes[1][0]).to.be.equal(0);
            expect(optionVotes[1][1]).to.be.equal(0);
        });
    });

    describe("User error testing", () => {
        it("Revert with incorrect options amount while creating new poll", async () => {
            await expect(createNewPoll(1)).to.be.reverted;
        });

        it("User can't vote in expired poll", async () => {
            await expirePoll(1);
            await expect(pollPlatform.connect(user1).madeVote(1, 0)).to.be.reverted;
        });
    });
});