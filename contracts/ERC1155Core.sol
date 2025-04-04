// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * THIS IS AN INITIAL CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN INITIAL CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

import {ERC1155Supply, ERC1155} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

error ERC1155Core_CallerIsNotActiveIssuerOrItself(address msgSender);
error ERC1155Core_CallerIsNotAssociatedIssuer(address msgSender);
error ERC1155Core_IssuerAlreadyExists(address issuer);
error ERC1155Core_IssuerNotExists(address issuer);
error ERC1155Core_IssuerAlreadyActive(address issuer);
error ERC1155Core_IssuerAlreadyDeactive(address issuer);
error ERC1155Core_TokenAlreadyLocked(uint256 tokenId);
error ERC1155Core_TokenNotLocked(uint256 tokenId);

contract ERC1155Core is ERC1155Supply, AccessControl {
    bytes32 public constant ISSUER_MANAGER_ROLE =
        keccak256("ISSUER_MANAGER_ROLE");

    uint256 private _nextTokenId;

    mapping(address issuer => bool isActive) internal _activeIssuers;
    mapping(uint256 tokenId => address issuer) internal _associatedTokensIssuer;
    mapping(uint256 tokenId => string uri) private _tokenURIs;
    mapping(uint256 tokenId => bool isLocked) private _lockedTokens;

    event IssuerAdded(address indexed issuer);
    event IssuerRemoved(address issuer);
    event IssuerActivated(address issuer);
    event IssuerDeactivated(address issuer);
    event TokenLocked(uint256 tokenId);
    event TokenUnlocked(uint256 tokenId);

    modifier onlyActiveIssuerOrItself() {
        if (!_activeIssuers[msg.sender] && msg.sender != address(this))
            revert ERC1155Core_CallerIsNotActiveIssuerOrItself(msg.sender);
        _;
    }

    modifier onlyAssociatedIssuer(uint256 id) {
        if (
            _activeIssuers[msg.sender] &&
            _associatedTokensIssuer[id] != msg.sender
        ) revert ERC1155Core_CallerIsNotAssociatedIssuer(msg.sender);
        _;
    }

    modifier onlyUnlockedToken(uint256 id) {
        if (_lockedTokens[id])
            revert ERC1155Core_TokenAlreadyLocked(id);
        _;
    }

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    constructor(string memory uri_, address defaultAdmin) ERC1155(uri_) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(ISSUER_MANAGER_ROLE, defaultAdmin);
    }

    function addIssuer(address issuer) external onlyRole(ISSUER_MANAGER_ROLE) {
        if (_activeIssuers[issuer])
            revert ERC1155Core_IssuerAlreadyExists(issuer);

        emit IssuerAdded(issuer);
        emit IssuerActivated(issuer);

        _activeIssuers[issuer] = true;
    }

    function removeIssuer(
        address issuer
    ) external onlyRole(ISSUER_MANAGER_ROLE) {
        if (!_activeIssuers[issuer] && _activeIssuers[issuer])
            revert ERC1155Core_IssuerNotExists(issuer);

        emit IssuerRemoved(issuer);

        delete _activeIssuers[issuer];
    }

    function activateIssuer(
        address issuer
    ) external onlyRole(ISSUER_MANAGER_ROLE) {
        if (_activeIssuers[issuer])
            revert ERC1155Core_IssuerAlreadyActive(issuer);

        emit IssuerActivated(issuer);

        _activeIssuers[issuer] = true;
    }

    function deactivateIssuer(
        address issuer
    ) external onlyRole(ISSUER_MANAGER_ROLE) {
        if (!_activeIssuers[issuer])
            revert ERC1155Core_IssuerAlreadyDeactive(issuer);

        emit IssuerDeactivated(issuer);

        _activeIssuers[issuer] = false;
    }

    function lockToken(
        uint256 id
    ) external onlyActiveIssuerOrItself onlyAssociatedIssuer(id) {
        if (_lockedTokens[id])
            revert ERC1155Core_TokenAlreadyLocked(id);

        emit TokenLocked(id);

        _lockedTokens[id] = true;
    }

    function lockTokenBatch(
        uint256[] memory ids
    ) external onlyActiveIssuerOrItself {
        for (uint256 i = 0; i <= ids.length; i++) {
            if (_lockedTokens[ids[i]])
                revert ERC1155Core_TokenAlreadyLocked(ids[i]);

            emit TokenLocked(ids[i]);

            _lockedTokens[ids[i]] = true;
        }
    }

    function unlockToken(
        uint256 id
    ) external onlyActiveIssuerOrItself onlyAssociatedIssuer(id) {
        if (!_lockedTokens[id])
            revert ERC1155Core_TokenNotLocked(id);

        emit TokenUnlocked(id);

        _lockedTokens[id] = false;
    }

    function unlockTokenBatch(
        uint256[] memory ids
    ) external onlyActiveIssuerOrItself {
        for (uint256 i = 0; i <= ids.length; i++) {
            if (!_lockedTokens[ids[i]])
                revert ERC1155Core_TokenNotLocked(ids[i]);

            if (_associatedTokensIssuer[ids[i]] != msg.sender)
                revert ERC1155Core_CallerIsNotAssociatedIssuer(msg.sender);

            emit TokenUnlocked(ids[i]);

            _lockedTokens[ids[i]] = true;
        }
    }

    function mint(
        address to,
        uint256 amount,
        bytes memory data,
        string memory tokenUri
    ) public onlyActiveIssuerOrItself {
        uint256 id = _nextTokenId++;

        _mint(to, id, amount, data);

        _tokenURIs[id] = tokenUri;
    }

    function mint(
        address to,
        uint256 amount,
        uint256 id,
        bytes memory data,
        string memory tokenUri
    ) public onlyActiveIssuerOrItself {
        _mint(to, id, amount, data);

        _tokenURIs[id] = tokenUri;
    }

    function mintBatch(
        address to,
        uint256[] memory amounts,
        bytes memory data,
        string[] memory tokenUris
    ) public onlyActiveIssuerOrItself {
        uint256[] memory ids = new uint256[](tokenUris.length);

        for (uint256 i = 0; i < tokenUris.length; ++i) {
            uint256 id = _nextTokenId++;

            _tokenURIs[id] = tokenUris[i];
            ids[i] = id;
        }

        _mintBatch(to, ids, amounts, data);
    }

    function mintBatch(
        address to,
        uint256[] memory amounts,
        uint256[] memory ids,
        bytes memory data,
        string[] memory tokenUris
    ) public onlyActiveIssuerOrItself {
        _mintBatch(to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i)
            _tokenURIs[ids[i]] = tokenUris[i];
    }

    function burn(
        address account,
        uint256 id,
        uint256 amount
    )
        public
        onlyActiveIssuerOrItself
        onlyAssociatedIssuer(id)
        onlyUnlockedToken(id)
    {
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender()))
            revert ERC1155MissingApprovalForAll(_msgSender(), account);

        _burn(account, id, amount);
        delete _tokenURIs[id];
    }

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public onlyActiveIssuerOrItself {
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender()))
            revert ERC1155MissingApprovalForAll(_msgSender(), account);

        for (uint256 i = 0; i < ids.length; ++i) {
            if (_lockedTokens[ids[i]])
                revert ERC1155Core_TokenAlreadyLocked(ids[i]);

            if (_associatedTokensIssuer[ids[i]] != msg.sender)
                revert ERC1155Core_CallerIsNotAssociatedIssuer(msg.sender);

            delete _tokenURIs[ids[i]];
        }

        _burnBatch(account, ids, amounts);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public override onlyUnlockedToken(id) {
        super.safeTransferFrom(from, to, id, value, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public override {
        for (uint256 i = 0; i <= ids.length; i++) {
            if (_lockedTokens[ids[i]])
                revert ERC1155Core_TokenAlreadyLocked(ids[i]);
        }

        super.safeBatchTransferFrom(from, to, ids, values, data);
    }

    function uri(uint256 id) public view override returns (string memory) {
        string memory tokenURI = _tokenURIs[id];

        return bytes(tokenURI).length > 0 ? tokenURI : super.uri(id);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _setURI(uint256 id, string memory tokenURI_) internal {
        _tokenURIs[id] = tokenURI_;
        emit URI(uri(id), id);
    }
}
