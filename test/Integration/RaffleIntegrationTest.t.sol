// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {CreateSubscription, FundSubscription, AddConsumerToSubscription} from "../../script/Interactions.s.sol";
import {HelperConfig} from "../../script/Helperconfig.s.sol";
import {Test, console2} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";

contract IntegrationTest is Test {
    CreateSubscription createsub;
    FundSubscription fundsub;
    AddConsumerToSubscription addConsumerToSub;
    HelperConfig helperConfig;
    Raffle raffle;

    uint256 subscriptionId;
    address vrfCoordinator;
    address link;

    function setUp() public {
        // 1. Deploy fresh helper config
        helperConfig = new HelperConfig();
        createsub = new CreateSubscription(helperConfig);
        fundsub = new FundSubscription(helperConfig);
        addConsumerToSub = new AddConsumerToSubscription(helperConfig);

        (uint256 subID, address vrfCoord) = createsub
            .CreateSubscriptionUsingConfig();
        subscriptionId = subID;
        vrfCoordinator = vrfCoord;
        address linkaddy = helperConfig.getConfig().link;
        link = linkaddy;

        HelperConfig.Networkconfig memory config = helperConfig.getConfig();
        raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.keyHash,
            subscriptionId,
            config.callbackGasLimit,
            vrfCoordinator
        );
    }

    /*//////////////////////////////////////////////////////////////
                           CREATESUBSCRIPTION
    //////////////////////////////////////////////////////////////*/

    function testCreateSubscriptionCreatesSubIdAndReturnSameVrfCoordinator()
        external
    {
        (uint256 subID, address returnedVrfCoordinator) = createsub
            .CreateSubscriptionUsingConfig();

        assertGt(subID, 0);
        assertEq(returnedVrfCoordinator, vrfCoordinator);
    }

    /*//////////////////////////////////////////////////////////////
                           FUND_SUBSCRIPTIOON
    //////////////////////////////////////////////////////////////*/
    function testFundSubscriptionFundsmySubscription() external {
        fundsub.FundSubscriptionUsingConfig(subscriptionId, vrfCoordinator);

        (uint256 balance, , , , ) = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .getSubscription(subscriptionId);

        assertEq(balance, 9 ether);
    }

    /*//////////////////////////////////////////////////////////////
                              ADD_CONSUMER
    //////////////////////////////////////////////////////////////*/
    function testAddConsumerAddsConsumerToSubscription() external {
        fundsub.FundSubscriptionUsingConfig(subscriptionId, vrfCoordinator);
        address consumer = addConsumerToSub.AddConsumerUsingConfig(
            address(raffle),
            vrfCoordinator,
            subscriptionId
        );

        assertEq(consumer, address(raffle));
    }
}
