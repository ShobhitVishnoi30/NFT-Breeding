// SPDX-License-Identifier:UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Utility/BaseAccessControl.sol";

abstract contract NFTCore is ERC721, BaseAccessControl {
    // Mapping token id to uri
    mapping(uint256 => string) private _tokenURIs;

    constructor(
        string memory name,
        string memory symbol,
        address accessControl
    ) ERC721(name, symbol) BaseAccessControl(accessControl) {}

    /**
     *@notice function used to set the token uri
     *@dev can only be called  by COO
     *@param tokenId token id for which uri is being set
     *@param uri uri for the token
     */
    function setTokenURI(uint256 tokenId, string calldata uri)
        external
        onlyRole(COO_ROLE)
    {
        _requireMinted(tokenId);
        require(bytes(_tokenURIs[tokenId]).length > 0, "URI is already set");
        _tokenURIs[tokenId] = uri;
    }

    /**
     *@dev to check if the given token has uri or not
     *@param tokenId token id
     *@return available true if token has uri
     */
    function hasURI(uint256 tokenId) public view returns (bool available) {
        _requireMinted(tokenId);
        return bytes(_tokenURIs[tokenId]).length > 0;
    }

    /**
     *@dev gives the uri of the token
     *@param tokenId token id
     *@return uri URL of the metadata of the token
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory uri)
    {
        _requireMinted(tokenId);
        return _tokenURIs[tokenId];
    }
}
