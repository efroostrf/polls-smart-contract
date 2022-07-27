// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "./IPollPlatform.sol";

contract PollPlatform is
    Initializable,
    IPollPlatform,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    address public tokenAddress;

    Poll[] public polls;
    
    mapping(uint256 => mapping(address => Vote)) pollVoters;
    mapping(uint256 => mapping(uint256 => uint256)) pollVotes;
    mapping(address => uint256[]) voterActivePolls;

    modifier onlyToken() {
        require(
            _msgSender() == tokenAddress,
            "This function can be called only by token contract"
        );
        _;
    }

    modifier pollExist(uint256 _pollId) {
        require(
            _pollId < polls.length && polls[_pollId].id == _pollId,
            "Poll not found"
        );
        _;
    }

    modifier pollNotExpired(uint256 _pollId) {
        require(
            isPollExpired(_pollId) == false,
            "Poll is expired"
        );
        _;
    }

    modifier notVoted(uint256 _pollId) {
        require(
            isVoted(_pollId, msg.sender) == false,
            "You already voted in this voting"
        );
        _;
    }

    function initialize() public initializer {
        __Ownable_init();
        tokenAddress = address(0);
    }

    function setTokenAddress(address _address) public onlyOwner {
        tokenAddress = _address;
    }

    /**
     * @dev Creates a new poll with a link to the JSON file, the number of options for the response and time to end.
     *
     * NOTE: JSON file contains a survey description and option names. Such file must be stored in IPFS.
     * optionsAmount must match the number of options in the JSON file.
     * unixExpireTime - time in UNIX timestamp when the time to vote in the poll will be exhausted.
     */
    function createPoll(
        string memory url, 
        uint256 optionsAmount,
        uint256 unixExpireTime
    ) public virtual override onlyOwner {
        require(optionsAmount >= 2, "The number of options must be at least 2");

        uint256 newPollId = polls.length;

        Poll storage poll = polls.push();

        poll.id = newPollId;
        poll.optionsAmount = optionsAmount;
        poll.expires = unixExpireTime;
        poll.created = block.timestamp;
        poll.url = url;

        emit pollCreated(newPollId, optionsAmount, block.timestamp, unixExpireTime, url);
    }

    /**
     * @dev Changes the expire time of a particular poll.
     */
    function changePollTime(uint256 pollId, uint256 expires) 
        public 
        virtual
        override
        onlyOwner 
        pollExist(pollId)
    {
        polls[pollId].expires = expires;

        emit pollTimeChanged(pollId, expires);
    }

    /**
     * @dev Returns a particular poll.
     */
    function getPoll(uint256 pollId)
        public
        view
        virtual
        pollExist(pollId)
        returns (Poll memory)
    {
        return polls[pollId];
    }
    
    /**
     * @dev Returns the number of votes for the options in the form of an array in a particular poll.
     */    
    function getPollOptions(uint256 pollId)
        public
        view
        virtual
        override
        pollExist(pollId)
        returns (uint256[] memory)
    {
        uint256 optionsAmount = polls[pollId].optionsAmount;
        uint256[] memory options = new uint256[](optionsAmount);

        for (uint256 i = 0; i < optionsAmount; i++) {
            options[i] = pollVotes[pollId][i];
        }
        
        return options;
    }

    /**
     *@dev Returns the number of polls since creating poll contract.
     */
    function getPollsLength() 
        public 
        view 
        returns(uint256) 
    {
        return polls.length;
    }

    /**
     * @dev Returns the number of votes in a particular poll.
     */
    function getVotersAmount(uint256 pollId)
        public
        view
        virtual
        override
        pollExist(pollId)
        returns(uint256)
    {
        return polls[pollId].votersAmount;
    }

    /**
     * @dev Returns bool which tell is poll expired or not.
     */
    function isPollExpired(uint256 pollId)
        public
        view
        virtual
        override
        pollExist(pollId)
        returns(bool)
    {
        if (block.timestamp > polls[pollId].expires) return true;
        return false;
    }

    /**
     * @dev Returns boll which tell is address voted in particular poll.
     */
    function isVoted(uint256 pollId, address voter)
        public
        view
        virtual
        override
        returns(bool)
    {
        return pollVoters[pollId][voter].isVoted;
    }

    /**
     * @dev Votes in a poll for a certain answer (option).
     *
     * NOTE: Option counting starts from 0.
     */
    function madeVote(uint256 pollId, uint256 option)
        public
        virtual
        override
        nonReentrant
        pollExist(pollId)
        pollNotExpired(pollId)
        notVoted(pollId)
    {
        require(option >= 0, "Selected option can't be negative");
        require(
            option < polls[pollId].optionsAmount,
            "Selected option is unexist"
        );
        require(
            IERC721Upgradeable(tokenAddress).balanceOf(msg.sender) > 0,
            "You need to have at least one NFT to vote"
        );

        Vote memory vote = Vote(
            pollId,
            option,
            true,
            msg.sender
        );

        voterActivePolls[msg.sender].push(pollId);
        pollVoters[pollId][msg.sender] = vote;
        pollVotes[pollId][option] += IERC721Upgradeable(tokenAddress).balanceOf(msg.sender);
        polls[pollId].votersAmount++;

        emit voted(pollId, option, block.timestamp, msg.sender);
    }

    /**
     * @dev Returns an array of polls in shich a certain address takes part.
     */
    function getVoterVotings(address voter) 
        public 
        view 
        virtual
        override
        returns(uint256[] memory) 
    {
        return voterActivePolls[voter];
    }

    /**
     * @dev This function is called only from the token contract.
     *
     * NOTE: You need to call this function from the _beforeTokenTransfer function in your token contract.
     */
    function transferVotingUnits(
        address from,
        address to,
        uint256 amount
    ) external onlyToken {
        if (from != address(0)) {
            _deleteInactivePolls(from);

            for (uint256 i = 0; i < voterActivePolls[from].length; i++) {
                uint256 pollId = voterActivePolls[from][i];
                Vote storage vote_from = pollVoters[pollId][from];
                uint256 option_from = vote_from.option;

                if (pollVotes[pollId][option_from] - amount >= 0) {
                    pollVotes[pollId][option_from] -= amount;
                }
            }
        }

        if (to != address(0)) {
            _deleteInactivePolls(to);

            for (uint256 i = 0; i < voterActivePolls[to].length; i++) {
                uint256 pollId = voterActivePolls[to][i];
                Vote storage vote_to = pollVoters[pollId][to];
                uint256 option_to = vote_to.option;

                pollVotes[pollId][option_to] += amount;
            }
        }
    }

    /**
     *@dev Removes inactive polls from an array at a specific voter.
     */
    function _deleteInactivePolls(address voter) 
        internal 
    {
        uint256[] memory _polls = voterActivePolls[voter];

        if (_polls.length > 0) {
            delete voterActivePolls[voter];

            for (uint256 i = 0; i < _polls.length; i++) {
                uint256 pollId = _polls[i];

                if (!isPollExpired(pollId)) {
                    voterActivePolls[voter].push(pollId);
                }
            }
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[46] private __gap;
}