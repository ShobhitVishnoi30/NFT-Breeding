// SPDX-License-Identifier:UNLICENSED
pragma solidity 0.8.16;

interface NFTBreedingInterface {
    /** @dev Breed a nft you own with a another nft that you own, or for which you
     * have previously been given approval.
     *@param tokenId1 The ID of the first nft
     *@param tokenId2 The ID of the second nft
     */
    function breed(uint256 tokenId1, uint256 tokenId2) external payable;

    /** @dev Grants approval to another user to breed with one of your nfts.
     *@param user The address that will be able to breed with your Kitty.
     *@param tokenId A nft that you own that user will now be able to breed with.
     */
    function approveForBreeding(address user, uint256 tokenId) external;

    /** @notice Checks that a given nft is able to breed (i.e. it is not pregnant or
     * in the middle of a cooldown).
     *@param tokenId reference the id of the nft, any user can inquire about it
     *@return bool true if kitty is available for breeding
     */
    function isAvailableForBreeding(uint256 tokenId)
        external
        view
        returns (bool);

    /**@dev checks if the two nfts are valid breeding pairs or not
     *Internal check to see if a given nfts are a valid mating pair. DOES NOT
     *check ownership permissions (that is up to the caller).
     *both should not be sibling , parents of one another etc.
     *@param tokenId1 id of the first nft
     *@param tokenId2   id of the second nft
     *@return bool return boolean
     */
    function isValidBreedingPair(uint256 tokenId1, uint256 tokenId2)
        external
        view
        returns (bool);

    /**@dev checks if the two nfts have permission to breed or not
     *Check if a nft has authorized breeding with this another nft. True if both nfts
     * have the same owner, or if the one nft's owner has given permission to
     *the other nft's owner (via approveForBreeding()).
     *@param tokenId1 id of the first nft
     *@param tokenId2   id of the second nft
     *@return bool return boolean
     */
    function isBreedingPermitted(uint256 tokenId1, uint256 tokenId2)
        external
        view
        returns (bool);

    /**@notice Checks to see if two nfts can breed together, including checks for
     *ownership and  approvals etc. Does NOT check that both nfts are ready for
     *breeding.
     *TODO: Shouldn't this check pregnancy and cooldowns?!?
     *@param tokenId1 The ID of the proposed first nft.
     *@param tokenId2 The ID of the proposed second nft.
     *@return bool return true if nfts can breed otherwise false
     */
    function canBreed(uint256 tokenId1, uint256 tokenId2)
        external
        view
        returns (bool);

    /** @dev Check if a nft has authorized breeding with this user. True if the tokenId's owner has given permission to
     * the user (via approveForBreeding()).
     *@param user user address to whom permission is given
     *@param tokenId cat id
     *@return bool true if the user is approved to use NFT
     */
    function isApprovedForBreeding(address user, uint256 tokenId)
        external
        view
        returns (bool);
}
