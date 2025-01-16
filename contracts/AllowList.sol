// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./Tokenomics/IAllowlist.sol";

/**
 * @title Allowlist contract
 * @author RBL
 */
contract AllowList is IAllowList, Ownable2Step{
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The addresses that are allowed
    EnumerableSet.AddressSet internal _allowedAddresses; 

    /// @notice Emitted when an address is allowed
    event AddressAllowed(address address_);

    /// @notice Emitted when an address is disallowed
    event AddressDisallowed(address address_);

    /**
     * @notice Add address to allowed list
     */
    function allow(address address_) external onlyOwner {
        require(!_allowedAddresses.contains(address_), 'address already allowed');

        emit AddressAllowed(address_);
        _allowedAddresses.add(address_);        
    }

    /**
     * @notice Remove address from allowed list
     */
    function disallow(address address_) external onlyOwner {
        require(_allowedAddresses.contains(address_), 'address already disallowed');

        emit AddressDisallowed(address_);
        _allowedAddresses.remove(address_);
    }

    /**
     * @dev returns length of _allowedAddresses array
     */
    function allowedAddressesLength() external view returns (uint256) {
        return _allowedAddresses.length();
    }

    /**
     * @dev returns _allowedAddresses array item's address for "index"
     */
    function allowedAddresses(uint256 index) external view returns (address) {
        return _allowedAddresses.at(index);
    }

    /**
     * @notice Check if a address is allowed
     */
    function allowed(address address_) external view returns (bool) {
        return _allowedAddresses.contains(address_);
    }
}