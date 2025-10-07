// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
error Helperconfig__ChainIdNotSupported();

abstract contract codeconstants {
    uint256 public constant SEPOLIA_ETH_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint96 public constant BASE_FEE = 0.04 ether; // 0.25 LINK per request
    uint96 public constant GAS_PRICE = 1e9; // 1 Gwei
    int256 public constant WEI_PER_UNIT_LINK = 1e18; // 1
}

contract HelperConfig is codeconstants, Script {
    struct Networkconfig {
        uint256 entranceFee;
        uint256 interval;
        bytes32 keyHash;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address vrfCoordinator;
        address link;
        address account;
    }

    Networkconfig public localNetworkConfig;
    mapping(uint256 => Networkconfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_ETH_CHAIN_ID] = getSepoliaEthconfig();
    }

    function getConfigbyChainId(
        uint256 chainId
    ) public returns (Networkconfig memory) {
        Networkconfig memory config = networkConfigs[chainId];
        if (config.vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        }

        if (chainId == SEPOLIA_ETH_CHAIN_ID) {
            return getSepoliaEthconfig();
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getorCreateAnvilconfig();
        } else {
            revert Helperconfig__ChainIdNotSupported();
        }
    }

    function getConfig() public returns (Networkconfig memory) {
        return getConfigbyChainId(block.chainid);
    }

    function getSepoliaEthconfig() public pure returns (Networkconfig memory) {
        return
            Networkconfig({
                entranceFee: 0.01 ether,
                interval: 30 seconds,
                keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionId: 94335478896486008268924862587106233291656592156716324409077529226756883244297,
                callbackGasLimit: 500000,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                account: 0xDB80c0A5771D39F487ac37cFdA8c1736cd2bE3ab
            });
    }

    function getorCreateAnvilconfig() public returns (Networkconfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock mockvrfCoordinator = new VRFCoordinatorV2_5Mock(
            BASE_FEE,
            GAS_PRICE,
            WEI_PER_UNIT_LINK
        );
        LinkToken linktoken = new LinkToken();

        vm.stopBroadcast();

        localNetworkConfig = Networkconfig({
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            vrfCoordinator: address(mockvrfCoordinator),
            link: address(linktoken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });

        return localNetworkConfig;
    }
}
