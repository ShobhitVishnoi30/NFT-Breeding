// SPDX-License-Identifier:UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

abstract contract BaseAccessControl is Context {
    /**
     *@dev all the management roles
     */
    bytes32 public constant CEO_ROLE = keccak256("CEO");
    bytes32 public constant CFO_ROLE = keccak256("CFO");
    bytes32 public constant COO_ROLE = keccak256("COO");

    // access control contract address
    address private _accessControl;

    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    constructor(address accessControl) Context() {
        _accessControl = accessControl;
    }

    /**@dev used to set the access control contract address.Can only be called by COO.
     *@param newAddress new access control contract address
     */
    function setAccessControlAddress(address newAddress)
        external
        onlyRole(COO_ROLE)
    {
        _accessControl = newAddress;
    }

    /**@dev to check the access control contract address
     *@return address access control contract address
     */
    function accessControlAddress() public view returns (address) {
        return _accessControl;
    }

    /**@dev to check if the current account has specified role or not
     *@param role for which account is being checked
     *@param account account address
     *@return bool true if account has role
     */
    function hasRole(bytes32 role, address account) public view returns (bool) {
        IAccessControl accessControl = IAccessControl(accessControlAddress());
        return
            accessControl.hasRole(role, account) ||
            accessControl.hasRole(CEO_ROLE, account);
    }

    /**@dev to check if the current account has specified role .Revert if not.
     *@param _role for which account is being checked
     *@param _account account address
     */
    function _checkRole(bytes32 _role, address _account) internal view {
        if (!hasRole(_role, _account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(_account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(_role), 32)
                    )
                )
            );
        }
    }
}
