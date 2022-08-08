// SPDX-License-Identifier: MIT
// Coin2Fish Contract (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";
import "../utils/MultiSigWallet.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context, MultiSignatureWallet {
    address private _backend;
    address private _owner;
    address[] private _owners;
    mapping(address => bool) private isOwner;

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor (address[] memory _constructorOwners, address _constructorBackend) {
        require(_constructorOwners.length >= 3, "Ownable: Requires the at least three owners");
        for (uint i = 0; i < _constructorOwners.length; i++) {
            address newOwner = _constructorOwners[i];
            require(newOwner != address(0), "Ownable: Owner is the zero address");
            require(!isOwner[newOwner], "Ownable: Owner is not unique");
            isOwner[newOwner] = true;
            _owner = msg.sender;
            _backend = _constructorBackend;
        }
        _backend = _constructorBackend;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }
    function requiredConfirmations() internal view returns (uint256) {
        return _owners.length;
    }
    /**
     * @dev Returns the address of the current backend.
     */
    function backend() internal view returns (address) {
        return _backend;
    }
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner[_msgSender()],  "Ownable: caller is not an owner");
        _;
    }
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyBackend() {
        require(backend() == _msgSender(), "Ownable: caller is not the backend");
        _;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function isAnOwner(address account) internal view returns (bool) {
        return isOwner[account];
    }
    /**
     * @dev See {IERC20-balanceOf}.
     */
    function getOwner(uint256 index) internal view returns (address) {
        return _owners[index];
    }
    /**
     * @dev Transfers backend Control of the contract to a new account (`newBackend`).
     * Can only be called by the current owner.
     */
    function transferBackend(address newBackend) internal {
        require(newBackend != address(0), "Ownable: new owner is the zero address");
        _backend = newBackend;
    }
}
