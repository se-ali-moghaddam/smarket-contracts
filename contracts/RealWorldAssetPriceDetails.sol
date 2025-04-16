// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {FunctionsSource} from "./FunctionsSource.sol";

error CallerIsNotAutomationForwarder(address caller);

contract RealWorldAssetPriceDetails is
    FunctionsClient,
    FunctionsSource,
    OwnerIsCreator
{
    using FunctionsRequest for FunctionsRequest.Request;

    struct PriceDetails {
        uint80 listPrice;
        uint80 originalListPrice;
        uint80 taxAssessedValue;
    }

    address internal _automationForwarderAddress;

    mapping(uint256 tokenId => PriceDetails) internal _priceDetails;

    modifier onlyAutomationForwarder() {
        if (msg.sender != _automationForwarderAddress)
            revert CallerIsNotAutomationForwarder(msg.sender);
        _;
    }

    constructor(
        address functionsRouterAddress
    ) FunctionsClient(functionsRouterAddress) {}

    function setAutomationForwarder(
        address automationForwarderAddress
    ) external onlyOwner {
        _automationForwarderAddress = automationForwarderAddress;
    }

    function updatePriceDetails(
        string memory tokenId,
        uint64 subscriptionId,
        uint32 gasLimit,
        bytes32 donID
    ) external onlyAutomationForwarder returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(this.getPrices());

        string[] memory args = new string[](1);
        args[0] = tokenId;

        req.setArgs(args);

        requestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );
    }

    function getPriceDetails(
        uint256 tokenId
    ) external view returns (PriceDetails memory) {
        return _priceDetails[tokenId];
    }

    // solhint-disable-next-line private-vars-leading-underscore
    function fulfillRequest(
        bytes32,
        /*requestId*/ bytes memory response,
        bytes memory err
    ) internal override {
        if (err.length != 0) revert(string(err));

        (
            uint256 tokenId,
            uint256 listPrice,
            uint256 originalListPrice,
            uint256 taxAssessedValue
        ) = abi.decode(response, (uint256, uint256, uint256, uint256));

        _priceDetails[tokenId] = PriceDetails({
            listPrice: uint80(listPrice),
            originalListPrice: uint80(originalListPrice),
            taxAssessedValue: uint80(taxAssessedValue)
        });
    }
}
