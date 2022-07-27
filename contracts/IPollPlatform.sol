// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPollPlatform {
    struct Vote {
        uint256 pollId;
        uint256 option;
        bool isVoted;
        address voter;
    }

    struct Poll {
        uint256 id;
        uint256 votersAmount;
        uint256 optionsAmount; // Amount of options in poll
        uint256 expires; // UNIX timestamp of poll ending
        uint256 created; // UNIX timestamp when poll is created
        string url; // URL to JSON file at IPFS with detailed poll description
    }

    /**
     * @dev Emmited when a new poll is created.
     */
    event pollCreated(
        uint256 pollId,
        uint256 optionsAmount,
        uint256 created,
        uint256 expires,
        string url
    );

    /**
     * @dev Emitted when the poll time changes.
     */
    event pollTimeChanged(
        uint256 pollId,
        uint256 newTime
    );

    /**
     * @dev Emitted when someone voted in some polling.
     */
    event voted(
        uint256 pollId,
        uint256 option,
        uint256 time,
        address voter
    );

    /**
     * @dev Creates a new poll with a link to the JSON file, the number of options for the response and time to end.
     *
     * NOTE: JSON file contains a survey description and option names. Such file must be stored in IPFS.
     * optionsAmount must match the number of options in the JSON file.
     * unixExpireTime - time in UNIX timestamp when the time to vote in the poll will be exhausted.
     */
    function createPoll(string memory url, uint256 optionsAmount, uint256 unixExpireTime) external;

    /**
     * @dev Changes the expire time of a particular poll.
     */
    function changePollTime(uint256 pollId, uint256 expires) external;

    /**
     * @dev Returns a particular poll.
     */
    function getPoll(uint256 pollId) external view returns(Poll memory);

    /**
     * @dev Returns the number of votes for the options in the form of an array in a particular poll.
     */
    function getPollOptions(uint256 pollId) external view returns(uint256[] memory);

    /**
     * @dev Returns the number of votes in a particular poll.
     */
    function getVotersAmount(uint256 pollId) external view returns(uint256);

    /**
     * @dev Returns bool which tell is poll expired or not.
     */
    function isPollExpired(uint256 pollId) external view returns(bool);

    /**
     * @dev Returns boll which tell is address voted in particular poll.
     */
    function isVoted(uint256 pollId, address voter) external view returns(bool);

    /**
     * @dev Votes in a poll for a certain answer (option).
     *
     * NOTE: Option counting starts from 0.
     */
    function madeVote(uint256 pollId, uint256 option) external;

    /**
     * @dev Returns an array of polls in shich a certain address takes part.
     */
    function getVoterVotings(address voter) external view returns(uint256[] memory);

    /**
     * @dev This function is called only from the token contract.
     *
     * NOTE: You need to call this function from the _beforeTokenTransfer function in your token contract.
     */
    function transferVotingUnits(address from, address to, uint256 amount) external;
}