// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FunctionsSource} from "./FunctionsSource.sol";
import {RealWorldAssetToken} from "./RealWorldAssetToken.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

error LatestIssueInProgress();
error IssuerAgentAlreadyExists(address agentAddr);
error IssuerAgentNotExists(address agentAddr);
error IssuerAgentAlreadyActive(address agentAddr);
error IssuerAgentAlreadyDeactive(address agentAddr);

contract Issuer is
    FunctionsClient,
    FunctionsSource,
    OwnerIsCreator,
    AccessControl
{
    using FunctionsRequest for FunctionsRequest.Request;

    struct Issuance {
        address to;
        uint256 amount;
    }

    bytes32 public constant AGENTS_MANAGER_ROLE =
        keccak256("AGENTS_MANAGER_ROLE");
    bytes32 public constant ISSUER_AGENT_ROLE = keccak256("ISSUER_AGENT_ROLE");

    // solhint-disable-next-line immutable-vars-naming, private-vars-leading-underscore
    RealWorldAssetToken internal immutable i_RealWorldAssetToken;
    bytes32 internal _lastRequestId;

    mapping(bytes32 requestId => Issuance) internal _issuesInProgress;
    mapping(address agent => bool isActive) internal _activeAgents;

    event IssuerAgentAdded(address agentAddr);
    event IssuerAgentRemoved(address agentAddr);
    event IssuerAgentActivated(address agentAddr);
    event IssuerAgentDeactivated(address agentAddr);
    event IssuanceCreated(address to, uint256 amount);
    event IssuanceCompleted(address to, uint256 amount);

    constructor(
        address defaultAdmin,
        address realWorldAssetToken,
        address functionsRouterAddress
    ) FunctionsClient(functionsRouterAddress) {
        i_RealWorldAssetToken = RealWorldAssetToken(realWorldAssetToken);

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(AGENTS_MANAGER_ROLE, defaultAdmin);
        _grantRole(ISSUER_AGENT_ROLE, defaultAdmin);
    }

    function addAgent(
        address agentAddr
    ) external onlyRole(AGENTS_MANAGER_ROLE) {
        if (_activeAgents[agentAddr])
            revert IssuerAgentAlreadyExists(agentAddr);

        emit IssuerAgentAdded(agentAddr);

        _activeAgents[agentAddr] = true;
        _grantRole(ISSUER_AGENT_ROLE, agentAddr);
    }

    function removeAgent(
        address agentAddr
    ) external onlyRole(AGENTS_MANAGER_ROLE) {
        if (!_activeAgents[agentAddr]) revert IssuerAgentNotExists(agentAddr);

        emit IssuerAgentRemoved(agentAddr);

        delete _activeAgents[agentAddr];
        _revokeRole(ISSUER_AGENT_ROLE, agentAddr);
    }

    function activateAgent(
        address agentAddr
    ) external onlyRole(AGENTS_MANAGER_ROLE) {
        if (_activeAgents[agentAddr])
            revert IssuerAgentAlreadyActive(agentAddr);

        emit IssuerAgentActivated(agentAddr);

        _activeAgents[agentAddr] = true;
    }

    function deactivateAgent(
        address agentAddr
    ) external onlyRole(AGENTS_MANAGER_ROLE) {
        if (!_activeAgents[agentAddr])
            revert IssuerAgentAlreadyDeactive(agentAddr);

        emit IssuerAgentDeactivated(agentAddr);

        _activeAgents[agentAddr] = false;
    }

    function issue(
        address to,
        uint256 amount,
        uint64 subscriptionId,
        uint32 gasLimit,
        bytes32 donID
    ) external onlyRole(ISSUER_AGENT_ROLE) returns (bytes32 requestId) {
        if (_lastRequestId != bytes32(0)) revert LatestIssueInProgress();

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(this.getNftMetadata());
        requestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        emit IssuanceCreated(to, amount);

        _issuesInProgress[requestId] = Issuance(to, amount);

        _lastRequestId = requestId;
    }

    function cancelPendingRequest() external onlyRole(ISSUER_AGENT_ROLE) {
        delete _issuesInProgress[_lastRequestId];
        _lastRequestId = bytes32(0);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // solhint-disable-next-line private-vars-leading-underscore
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (err.length != 0) revert(string(err));

        if (_lastRequestId == requestId) {
            string memory tokenURI = string(response);
            Issuance memory issue_ = _issuesInProgress[requestId];

            emit IssuanceCompleted(issue_.to, issue_.amount);

            i_RealWorldAssetToken.mint(issue_.to, issue_.amount, "", tokenURI);

            delete _issuesInProgress[_lastRequestId];
            _lastRequestId = bytes32(0);
        }
    }
}
