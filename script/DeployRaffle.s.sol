// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "script/Helperconfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {AddConsumerToSubscription, CreateSubscription, FundSubscription} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    HelperConfig public helperConfig;
    Raffle public raffle;

    function run() public returns (Raffle, HelperConfig) {
        helperConfig = new HelperConfig(); // This comes with our mocks!
        HelperConfig.Networkconfig memory config = helperConfig.getConfig();
        AddConsumerToSubscription addConsumer = new AddConsumerToSubscription(
            helperConfig
        );

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription(
                helperConfig
            );
            (config.subscriptionId, config.vrfCoordinator) = createSubscription
                .createSubscription(config.vrfCoordinator, config.account);

            FundSubscription fundSubscription = new FundSubscription(
                helperConfig
            );
            fundSubscription.fundSubscription(
                config.vrfCoordinator,
                config.subscriptionId,
                config.link
            );
        }

        vm.startBroadcast(config.account);
        raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.keyHash,
            config.subscriptionId,
            config.callbackGasLimit,
            config.vrfCoordinator
        );
        vm.stopBroadcast();

        addConsumer.addConsumer(
            config.vrfCoordinator,
            config.subscriptionId,
            address(raffle),
            config.account
        );

        return (raffle, helperConfig);
    }
}
