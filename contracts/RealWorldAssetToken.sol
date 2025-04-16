// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl";
import {CrossChainBurnAndMintERC1155} from "./CrossChainBurnAndMintERC1155.sol";
import {RealWorldAssetPriceDetails} from "./RealWorldAssetPriceDetails.sol";
import {Access} from "./utils/Access.sol";
import {Withdraw} from "./utils/Withdraw.sol";

contract RealWorldAssetToken is
    Access,
    Withdraw,
    CrossChainBurnAndMintERC1155,
    RealWorldAssetPriceDetails
{
    constructor(
        string memory uri_,
        address defaultAdmin,
        address ccipRouterAddress,
        address linkTokenAddress,
        uint64 currentChainSelector,
        address functionsRouterAddress
    )
        Access(defaultAdmin)
        CrossChainBurnAndMintERC1155(
            uri_,
            ccipRouterAddress,
            linkTokenAddress,
            currentChainSelector
        )
        RealWorldAssetPriceDetails(functionsRouterAddress)
    {}

    function enableChain(
        uint64 chainSelector,
        address nftContractAddr,
        bytes memory ccipExtraArgs
    ) external override onlyRole(CHAIN_MANAGER_ROLE) {
        super.enableChain(chainSelector, nftContractAddr, currentChainSelector);
    }

    function disableChain(
        uint64 chainSelector
    ) external override onlyRole(CHAIN_MANAGER_ROLE) {
        super.disableChain(chainSelector);
    }

    function addIssuer(address issuer) external onlyRole(ISSUER_MANAGER_ROLE) {
        super.addIssuer(issuer);
    }

    function removeIssuer(
        address issuer
    ) external onlyRole(ISSUER_MANAGER_ROLE) {
        super.removeIssuer(issuer);
    }

    function activateIssuer(
        address issuer
    ) external onlyRole(ISSUER_MANAGER_ROLE) {
        super.activateIssuer(issuer);
    }

    function deactivateIssuer(
        address issuer
    ) external onlyRole(ISSUER_MANAGER_ROLE) {
        super.deactivateIssuer(issuer);
    }

    function withdraw(
        address beneficiary,
        address token
    ) public override onlyRole(WITHDRAWAL_MANAGER_ROLE) {
        super.withdraw(beneficiary, token);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControl, ERC1155) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
