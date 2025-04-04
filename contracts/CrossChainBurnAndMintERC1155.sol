// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * THIS IS AN INITIAL CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN INITIAL CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

import {ERC1155Core} from "./ERC1155Core.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IAny2EVMMessageReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error InvalidRouter(address router);
error NotEnoughBalanceForFees(uint256 currentBalance, uint256 calculatedFees);
error ChainNotEnabled(uint64 chainSelector);
error SenderNotEnabled(address sender);
error OperationNotAllowedOnCurrentChain(uint64 chainSelector);
error NothingToWithdraw();
error FailedToWithdrawEth(address owner, address beneficiary, uint256 value);

contract CrossChainBurnAndMintERC1155 is
    ERC1155Core,
    IAny2EVMMessageReceiver,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    struct XNftDetails {
        address xNftAddress;
        bytes ccipExtraArgsBytes;
    }

    bytes32 public constant CHAIN_MANAGER_ROLE =
        keccak256("CHAIN_MANAGER_ROLE");
    bytes32 public constant WITHDRAWAL_MANAGER_ROLE =
        keccak256("WITHDRAWAL_MANAGER_ROLE");

    // solhint-disable-next-line immutable-vars-naming, private-vars-leading-underscore
    IRouterClient internal immutable i_ccipRouter;
    // solhint-disable-next-line immutable-vars-naming, private-vars-leading-underscore
    LinkTokenInterface internal immutable i_linkToken;
    // solhint-disable-next-line immutable-vars-naming, private-vars-leading-underscore
    uint64 private immutable i_currentChainSelector;

    mapping(uint64 destChainSelector => XNftDetails xNftDetailsPerChain)
        public chains;

    event ChainEnabled(
        uint64 chainSelector,
        address xNftAddress,
        bytes ccipExtraArgs
    );
    event ChainDisabled(uint64 chainSelector);
    event CrossChainSent(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes data,
        uint64 sourceChainSelector,
        uint64 destinationChainSelector
    );
    event CrossChainReceived(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes data,
        uint64 sourceChainSelector,
        uint64 destinationChainSelector
    );

    modifier onlyRouter() {
        if (msg.sender != address(i_ccipRouter))
            revert InvalidRouter(msg.sender);
        _;
    }

    modifier onlyEnabledChain(uint64 chainselector) {
        if (chains[chainselector].xNftAddress == address(0))
            revert ChainNotEnabled(chainselector);
        _;
    }

    modifier onlyEnabledSender(uint64 chainselector, address sender) {
        if (chains[chainselector].xNftAddress != sender)
            revert SenderNotEnabled(sender);
        _;
    }

    modifier onlyOtherChains(uint64 chainselector) {
        if (chainselector == i_currentChainSelector)
            revert OperationNotAllowedOnCurrentChain(chainselector);
        _;
    }

    constructor(
        string memory uri_,
        address defaultAdmin,
        address ccipRouterAddress,
        address linkTokenAddress,
        uint64 currentChainSelector
    ) ERC1155Core(uri_, defaultAdmin) {
        i_ccipRouter = IRouterClient(ccipRouterAddress);
        i_linkToken = LinkTokenInterface(linkTokenAddress);
        i_currentChainSelector = currentChainSelector;

        _grantRole(CHAIN_MANAGER_ROLE, defaultAdmin);
        _grantRole(WITHDRAWAL_MANAGER_ROLE, defaultAdmin);
    }

    function enableChain(
        uint64 chainSelector,
        address xNftAddress,
        bytes memory ccipExtraArgs
    ) external onlyRole(CHAIN_MANAGER_ROLE) onlyOtherChains(chainSelector) {
        emit ChainEnabled(chainSelector, xNftAddress, ccipExtraArgs);

        chains[chainSelector] = XNftDetails({
            xNftAddress: xNftAddress,
            ccipExtraArgsBytes: ccipExtraArgs
        });
    }

    function disableChain(
        uint64 chainSelector
    ) external onlyRole(CHAIN_MANAGER_ROLE) onlyOtherChains(chainSelector) {
        emit ChainDisabled(chainSelector);

        delete chains[chainSelector];
    }

    function crossChainTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data,
        uint64 destinationChainSelector,
        bool payFeesInLink
    )
        external
        nonReentrant
        onlyEnabledChain(destinationChainSelector)
        returns (bytes32 messageId)
    {
        string memory tokenUri = uri(id);
        burn(from, id, amount);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(chains[destinationChainSelector].xNftAddress),
            data: abi.encode(from, to, id, amount, data, tokenUri),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: chains[destinationChainSelector].ccipExtraArgsBytes,
            feeToken: payFeesInLink ? address(i_linkToken) : address(0)
        });

        // Get the fee required to send the CCIP message
        uint256 fees = i_ccipRouter.getFee(destinationChainSelector, message);

        if (payFeesInLink) {
            if (fees > i_linkToken.balanceOf(address(this))) {
                revert NotEnoughBalanceForFees(
                    i_linkToken.balanceOf(address(this)),
                    fees
                );
            }

            // Approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
            i_linkToken.approve(address(i_ccipRouter), fees);

            // Send the message through the router and store the returned message ID
            messageId = i_ccipRouter.ccipSend(
                destinationChainSelector,
                message
            );
        } else {
            if (fees > address(this).balance) {
                revert NotEnoughBalanceForFees(address(this).balance, fees);
            }

            // Send the message through the router and store the returned message ID
            messageId = i_ccipRouter.ccipSend{value: fees}(
                destinationChainSelector,
                message
            );
        }

        emit CrossChainSent(
            from,
            to,
            id,
            amount,
            data,
            i_currentChainSelector,
            destinationChainSelector
        );
    }

    /// @inheritdoc IAny2EVMMessageReceiver
    function ccipReceive(
        Client.Any2EVMMessage calldata message
    )
        external
        virtual
        override
        onlyRouter
        nonReentrant
        onlyEnabledChain(message.sourceChainSelector)
        onlyEnabledSender(
            message.sourceChainSelector,
            abi.decode(message.sender, (address))
        )
    {
        uint64 sourceChainSelector = message.sourceChainSelector;
        (
            address from,
            address to,
            uint256 id,
            uint256 amount,
            bytes memory data,
            string memory tokenUri
        ) = abi.decode(
                message.data,
                (address, address, uint256, uint256, bytes, string)
            );

        mint(to, id, amount, data, tokenUri);

        emit CrossChainReceived(
            from,
            to,
            id,
            amount,
            data,
            sourceChainSelector,
            i_currentChainSelector
        );
    }

    function withdraw(
        address beneficiary,
        address token
    ) public onlyRole(WITHDRAWAL_MANAGER_ROLE) {
        if (token == address(this)) {
            uint256 amountEth = address(this).balance;

            if (amountEth == 0) revert NothingToWithdraw();

            (bool sent, ) = beneficiary.call{value: amountEth}("");

            if (!sent)
                revert FailedToWithdrawEth(msg.sender, beneficiary, amountEth);
        }

        uint256 amount = IERC20(token).balanceOf(address(this));

        if (amount == 0) revert NothingToWithdraw();

        IERC20(token).safeTransfer(beneficiary, amount);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155Core) returns (bool) {
        return
            interfaceId == type(IAny2EVMMessageReceiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
