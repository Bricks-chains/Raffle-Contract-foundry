// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts@1.1.1/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts@1.1.1/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle
 * @author Andrew Gideon
 * @notice A simple raffle contract that allows users to enter a raffle by sending Ether.
 * @dev This contract implements chainlink VRF to securely select a random winner. Users can enter the raffle by sending Ether. The contract keeps track
 * of the participants and randomly selects a winner when the raffle is closed. The winner receives
 * the total balance of the contract.
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* custom errors */
    error Raffle__NotEnoughETHSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__IndexOutOfBounds();
    error Raffle__UpkeepNotNeeded(
        uint256 numberOfParticipants,
        uint256 contractBalance,
        uint256 raffleState
    );

    /* type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* state variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; // @dev The time interval in seconds after which the raffle can be closed and a winner can be picked.
    uint256 private s_lastTimestamp;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_participants;
    address private s_Winner;
    RaffleState private s_raffleState = RaffleState.OPEN;

    /* events */
    event RaffleEntered(address indexed participant);
    event WinnerSelected(address indexed winner);
    event RequestedRandomnumber(uint256 indexed requestedId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        bytes32 keyHash,
        uint256 subscriptionId,
        uint32 callbackGasLimit,
        address vrfCoordinator
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimestamp = block.timestamp;
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // Checks
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        // Effects
        s_participants.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @notice This function is called by the Chainlink Keeper to check if upkeep is needed.
     * @dev the function checks the following conditions:
     * 1. If the raffle is in the OPEN state.
     * 2. If the time since the last timestamp is greater than or equal to the interval.
     * 3. If there are participants in the raffle.
     * 4. If the balance of the contract is greater than 0.
     * 5. if subscription has enough balance to pay for the VRF request.
     * @param - ignored checkData parameter, as it is not used in this implementation.
     * @return upkeepNeeded A boolean indicating if upkeep is needed.
     * @return - ignored performData parameter, as it is not used in this implementation.
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool raffleOpen = (s_raffleState == RaffleState.OPEN);
        bool timeHasPassed = ((block.timestamp - s_lastTimestamp) >=
            i_interval);
        bool hasParticipants = (s_participants.length > 0);
        bool hasBalance = (address(this).balance > 0);
        upkeepNeeded = (raffleOpen &&
            timeHasPassed &&
            hasParticipants &&
            hasBalance);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        // automatically call the function
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                s_participants.length,
                address(this).balance,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestID = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRandomnumber(requestID);
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] calldata randomWords
    ) internal override {
        // Effects
        uint256 indexofWinner = randomWords[0] % s_participants.length;
        address payable winner = s_participants[indexofWinner];
        s_Winner = winner;
        s_raffleState = RaffleState.OPEN;
        s_participants = new address payable[](0);

        // Interactions
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerSelected(winner);
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumberOfParticipants() external view returns (uint256) {
        return s_participants.length;
    }

    function getParticipant(uint256 index) external view returns (address) {
        if (index >= s_participants.length) {
            revert Raffle__IndexOutOfBounds();
        }
        return s_participants[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimestamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_Winner;
    }
}
