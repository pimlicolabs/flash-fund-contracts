// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* solhint-disable reason-string */

import {OwnableUpgradeable} from "@openzeppelin-5.0.2/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * Helper class for creating a contract with signer.
 */
abstract contract Signer is OwnableUpgradeable {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Emitted when a signer is added.
    event SignerAdded(address signer);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Signer address.
    address private signer;

    function __Signer_init(address _signer) internal {
        _addSigner(_signer);
    }

    function _isSigner(address _signer) internal view returns (bool) {
        return signer == _signer;
    }

    function getSigner() public view returns (address) {
        return signer;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ADMIN FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function addSigner(address _signer) public onlyOwner {
        _addSigner(_signer);
    }

    function _addSigner(address _signer) internal {
        signer = _signer;

        emit SignerAdded(_signer);
    }
}
