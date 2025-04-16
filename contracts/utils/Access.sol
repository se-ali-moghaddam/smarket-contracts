//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract Access is AccessControl {
    //solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant CHAIN_MANAGER_ROLE =
        keccak256("CHAIN_MANAGER_ROLE");
    //solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant ACCESS_MANAGER_ROLE =
        keccak256("ACCESS_MANAGER_ROLE");
    //solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant WITHDRAWAL_MANAGER_ROLE =
        keccak256("WITHDRAWAL_MANAGER_ROLE");
    //solhint-disable-next-line private-vars-leading-underscore
    bytes32 public constant ISSUER_MANAGER_ROLE =
        keccak256("ISSUER_MANAGER_ROLE");

    constructor(address defaultAdmin) {
        grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        grantRole(CHAIN_MANAGER_ROLE, defaultAdmin);
        grantRole(ACCESS_MANAGER_ROLE, defaultAdmin);
        grantRole(WITHDRAWAL_MANAGER_ROLE, defaultAdmin);
        grantRole(ISSUER_MANAGER_ROLE, defaultAdmin);
    }

    function grantRole(
        bytes32 role,
        address agent
    ) public override onlyRole(ACCESS_MANAGER_ROLE) {
        super.grantRole(role, agent);
    }

    function revokeRole(
        bytes32 role,
        address agent
    ) public override onlyRole(ACCESS_MANAGER_ROLE) {
        super.revokeRole(role, agent);
    }
}
