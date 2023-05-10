// SPDX-License-Identifier:UNLICENSED
pragma solidity 0.8.16;

interface NFTInterface {
    /**@dev we can create promo kittens, up to a limit. Only callable by COO
     *@param genes the encoded genes of the kitten to be created, any value is accepted
     *@param owner the future owner of the created kittens. Default to contract COO
     */
    function issueNFT(uint256 genes, address owner) external;
}
