// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

/// @notice Tracks valid Destination Vaults for the system
interface IDestinationVaultRegistry {
    /// @notice Determines if a given address is a valid Destination Vault in the system
    /// @param destinationVault address to check
    /// @return True if vault is registered
    function isRegistered(address destinationVault) external view returns (bool);

    /// @notice Registers a new Destination Vault
    /// @dev Should be locked down to only a factory
    /// @param newDestinationVault Address of the new vault
    function register(address newDestinationVault) external;

    /// @notice Checks if an address is a valid Destination Vault and reverts if not
    /// @param destinationVault Destination Vault address to checked
    function verifyIsRegistered(address destinationVault) external view;
}
