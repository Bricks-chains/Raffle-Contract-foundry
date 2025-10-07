// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Script, console2} from "lib/forge-std/src/Script.sol";
import {HelperConfig, codeconstants} from "./Helperconfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    HelperConfig public immutable i_helperconfig;

    constructor(HelperConfig _helperConfig) {
        i_helperconfig = _helperConfig;
    }

    function createSubscription(
        address vrfCoordinator,
        address account
    ) public returns (uint256, address) {
        console2.log("Creating subscription on chain ID:", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console2.log("Subscription created with ID:", subId);
        console2.log(
            "please update the subscription ID in the HelperConfig.s.sol file"
        );
        return (subId, vrfCoordinator);
    }

    function CreateSubscriptionUsingConfig() public returns (uint256, address) {
        address vrfCoordinator = i_helperconfig.getConfig().vrfCoordinator;
        address account = i_helperconfig.getConfig().account;
        (uint256 subId, ) = createSubscription(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    function run() external {
        CreateSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, codeconstants {
    uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK tokens

    HelperConfig public helperconfig;

    constructor(HelperConfig _helperConfig) {
        helperconfig = _helperConfig;
    }

    function FundSubscriptionUsingConfig(
        uint256 subID,
        address vrfCoordinator
    ) public {
        address link = helperconfig.getConfig().link;
        fundSubscription(vrfCoordinator, subID, link);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subID,
        address link
    ) public {
        console2.log("funding subscription with ID:", subID);
        console2.log("vrfCoordinator address:", vrfCoordinator);
        console2.log("chain ID:", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subID,
                FUND_AMOUNT * 3
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subID)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        uint256 subId = helperconfig.getConfig().subscriptionId;
        address vrfCoordinator = helperconfig.getConfig().vrfCoordinator;
        FundSubscriptionUsingConfig(subId, vrfCoordinator);
    }
}

contract AddConsumerToSubscription is Script, codeconstants {
    HelperConfig public helperconfig;

    constructor(HelperConfig _helperConfig) {
        helperconfig = _helperConfig;
    }

    function AddConsumerUsingConfig(
        address mostRecentConsumer,
        address vrfCoordinator,
        uint256 subId
    ) public returns (address) {
        address account = helperconfig.getConfig().account;
        addConsumer(vrfCoordinator, subId, mostRecentConsumer, account);
        return mostRecentConsumer;
    }

    function addConsumer(
        address vrfCoordinator,
        uint256 subId,
        address consumer,
        address account
    ) public {
        console2.log("Adding consumer to subscription ID:", subId);
        console2.log("vrfCoordinator address:", vrfCoordinator);
        console2.log("consumer address:", consumer);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, consumer);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentConsumer = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        address vrfCoordinator = helperconfig.getConfig().vrfCoordinator;
        uint256 subId = helperconfig.getConfig().subscriptionId;
        console2.log("Most recent consumer address:", mostRecentConsumer);
        AddConsumerUsingConfig(mostRecentConsumer, vrfCoordinator, subId);
    }
}
