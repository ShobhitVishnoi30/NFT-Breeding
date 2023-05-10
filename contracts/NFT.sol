// SPDX-License-Identifier:UNLICENSED
pragma solidity 0.8.16;

import "./NFTBreeding.sol";
import "./Interfaces/NFTInterface.sol";

contract NFT is NFTBreeding, NFTInterface {
    // Limits the number of cats the contract owner can ever create.
    uint256 public constant GENERATION0_LIMIT = 5000;

    // Constants for gen0 auctions.
    uint256 public constant GEN0_STARTING_PRICE = 10 gwei;

    uint256 public gen0CreatedCount;

    constructor(
        string memory name,
        string memory symbol,
        address accessControl
    ) NFTBreeding(name, symbol, accessControl) {
        // start with the mythical kitten 0 - so we don't have generation-0 parent issues
        _createKitty(0, 0, 0, type(uint256).max, address(0));
    }

    /**@dev we can create promo kittens, up to a limit. Only callable by COO
     *@param genes the encoded genes of the kitten to be created, any value is accepted
     *@param owner the future owner of the created kittens. Default to contract COO
     */
    function issueNFT(uint256 genes, address owner)
        external
        override
        onlyRole(COO_ROLE)
    {
        require(owner != address(0), "owner can not be zero");
        require(gen0CreatedCount < GENERATION0_LIMIT, "limit exceeded");

        gen0CreatedCount++;
        _createKitty(0, 0, 0, genes, owner);
    }

    /**@dev Allows the CFO to capture the balance available to the contract.
     *@param reciever reciever address
     */
    function withdrawBalance(address reciever) external onlyRole(CFO_ROLE) {
        uint256 balance = address(this).balance;
        // Subtract all the currently pregnant kittens we have, plus 1 of margin.
        uint256 subtractFees = (pregnantKitties + 1) * autoBirthFee;

        if (balance > subtractFees) {
            payable(reciever).transfer(balance - subtractFees);
        }
    }

    /**@dev Returns all the relevant information about a specific kitty.
     *@param id The ID of the kitty of interest.
     */
    function getKitty(uint256 id)
        external
        view
        returns (
            bool isGestating,
            bool isReady,
            uint256 cooldownIndex,
            uint256 nextActionAt,
            uint256 siringWithId,
            uint256 birthTime,
            uint256 matronId,
            uint256 sireId,
            uint256 generation,
            uint256 genes
        )
    {
        Kitty storage kit = kitties[id];

        // if this variable is 0 then it's not gestating
        isGestating = (kit.siringWithId != 0);
        isReady = (kit.cooldownEndBlock <= block.number);
        cooldownIndex = uint256(kit.cooldownIndex);
        nextActionAt = uint256(kit.cooldownEndBlock);
        siringWithId = uint256(kit.siringWithId);
        birthTime = uint256(kit.birthTime);
        matronId = uint256(kit.matronId);
        sireId = uint256(kit.sireId);
        generation = uint256(kit.generation);
        genes = kit.genes;
    }
}
