// SPDX-License-Identifier:UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract AccessControlManager is AccessControl {
    string public constant REVOKE_ROLE_ERROR =
        "AccessControlManager: unable to revoke the given role";

    bytes32 public constant CEO_ROLE = keccak256("CEO");
    bytes32 public constant CFO_ROLE = keccak256("CFO");
    bytes32 public constant COO_ROLE = keccak256("COO");

    constructor(
        address admin,
        address ceo,
        address coo,
        address cfo
    ) AccessControl() {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(CEO_ROLE, ceo);
        _setupRole(COO_ROLE, coo);
        _setupRole(CFO_ROLE, cfo);

        _setRoleAdmin(COO_ROLE, CEO_ROLE);
        _setRoleAdmin(CFO_ROLE, CEO_ROLE);
    }

    /**@dev used to grant role
     *@param role role for which account to be granted
     *@param account account address to be granted
     */
    function grantRole(bytes32 role, address account) public virtual override {
        super.grantRole(role, account);
    }

    /**@dev used to revoke role
     *@param role role for which account to be revoked
     *@param account account address to be revoked
     */
    function revokeRole(bytes32 role, address account) public virtual override {
        super.revokeRole(role, account);
    }

    /**@dev used to renounce role
     *@param role role for which account to be renounced
     *@param account account address to be renounced
     */
    function renounceRole(bytes32 role, address account)
        public
        virtual
        override
    {
        super.renounceRole(role, account);
    }
}
