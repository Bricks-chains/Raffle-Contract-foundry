// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/Helperconfig.s.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {codeconstants} from "../../script/Helperconfig.s.sol";

contract RaffleTest is Test, codeconstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    bytes32 keyHash;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    address vrfCoordinatorTest;
    LinkToken linkToken;

    event RaffleEntered(address indexed participant);
    event WinnerSelected(address indexed winner);
    event RequestedRandomnumber(uint256 indexed requestid);

    modifier raffleEnteredModifier() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipForking() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              SETUP
    //////////////////////////////////////////////////////////////*/
    /// @notice Sets up the test environment by deploying the Raffle contract and initializing necessary variables.
    /// @dev This function is called before each test to ensure a clean state.
    /// It deploys the Raffle contract using the DeployRaffle script and retrieves the configuration
    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);

        HelperConfig.Networkconfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        keyHash = config.keyHash;
        interval = config.interval;
        entranceFee = config.entranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorTest = config.vrfCoordinator;
        linkToken = LinkToken(config.link);
    }

    function testRafflestateinitializesToOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/
    function testEnterRaffleRevertsIfNotEnoughEth() public {
        // Arrange
        vm.prank(PLAYER);
        // Act & Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughETHSent.selector);
        raffle.enterRaffle();
    }

    function testEnterRaffleRecordsParticipant() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        assertEq(raffle.getNumberOfParticipants(), 1);
        assertEq(raffle.getParticipant(0), PLAYER);
    }

    function testEnteringRaffleEmitsRaffleEnteredEvent() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testUserCantEnterRaffleWhenCalculatingWinner()
        public
        raffleEnteredModifier
    {
        // Arrange
        raffle.performUpkeep("");

        // Act & Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECKUPKEEP
    //////////////////////////////////////////////////////////////*/
    function testCheckUpkeepreturnsUpkeepNeeded()
        external
        raffleEnteredModifier
    {
        // Arrange

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertTrue(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughBalance() external {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughParticipants() external {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimePassed() external {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen()
        external
        raffleEnteredModifier
    {
        // Arrange
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assertFalse(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORMUPKEEP
    //////////////////////////////////////////////////////////////*/
    function testPerformUpkeepRuns() external raffleEnteredModifier {
        // Arrange
        raffle.checkUpkeep("");

        // Act
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsUpkeepNotNeeded() external {
        // Arrange
        uint256 checkBalance = 0;
        uint256 numberOfParticipants = 0;
        raffle.getRaffleState() == Raffle.RaffleState.CALCULATING;

        vm.expectRevert(
            abi.encode(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                checkBalance,
                numberOfParticipants,
                uint256(Raffle.RaffleState.CALCULATING)
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepReturnsRequestId()
        external
        raffleEnteredModifier
    {
        // Arrange

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestid = entries[1].topics[1];

        // Assert
        Raffle.RaffleState rafflestate = raffle.getRaffleState();
        assertGt(uint256(requestid), 0);
        assertEq(uint256(rafflestate), 1);
    }

    /*//////////////////////////////////////////////////////////////
                           FUFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/
    function testFufillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) external raffleEnteredModifier skipForking {
        // Arrange / Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinatorTest).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFufillRandomWordsFundsWinnerAndResetsRaffle()
        external
        raffleEnteredModifier
        skipForking
    {
        // Arrange
        uint256 additionalParticipants = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalParticipants;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimestamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinatorTest).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState rafflestate = raffle.getRaffleState();
        uint256 endingTimestamp = block.timestamp;
        uint256 winnerBalance = recentWinner.balance;
        uint256 prize = entranceFee * (additionalParticipants + 1);
        console2.log("recentWinner", recentWinner);
        console2.log("expectedWinner", expectedWinner);

        assert(recentWinner == expectedWinner);
        assert(uint256(rafflestate) == 0);
        assert(endingTimestamp > startingTimestamp);
        assert(winnerBalance == winnerStartingBalance + prize);

        console2.log(
            "Winner: %s Balance: %s Prize: %s",
            recentWinner,
            winnerBalance,
            prize
        );
    }
}
