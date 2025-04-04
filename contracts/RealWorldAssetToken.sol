// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * THIS IS AN INITIAL CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN INITIAL CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

import {CrossChainBurnAndMintERC1155} from "./CrossChainBurnAndMintERC1155.sol";
import {RealWorldAssetPriceDetails} from "./RealWorldAssetPriceDetails.sol";

contract RealWorldAssetToken is CrossChainBurnAndMintERC1155, RealWorldAssetPriceDetails {
    constructor(
        string memory uri_,
        address defaultAdmin,
        address ccipRouterAddress,
        address linkTokenAddress,
        uint64 currentChainSelector,
        address functionsRouterAddress
    )
        CrossChainBurnAndMintERC1155(uri_, defaultAdmin, ccipRouterAddress, linkTokenAddress, currentChainSelector)
        RealWorldAssetPriceDetails(functionsRouterAddress)
    {}
}