//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../access/OperatorAccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IERC721 {
    function mintTo(
        address _to,
        uint256 _tokenId,
        uint256[] memory _attributes,
        uint256[] memory _attributesMax,
        uint256[] memory _genes,
        string memory _tokenURI
    ) external;
}

interface IERC1155 {
    function mintTo(
        address to,
        uint256 id,
        uint256 amount,
        string calldata _uri
    ) external;
}

contract NFTFactory is OperatorAccessControl {
    using Address for address;

    function batchMintERC721To(
        address _erc721Address,
        address[] memory _tos,
        uint256[] memory _tokenId,
        uint256[][] memory _attributes,
        uint256[][] memory _attributesMax,
        uint256[][] memory _genes,
        string[] memory _tokenURIs
    ) public isOperatorOrOwner {
        require(
            _erc721Address.isContract(),
            "NFTFactory: batchMintERC721To erc721Address must be contract address"
        );
        require(
            _tos.length == _tokenId.length,
            "NFTFactory: batchMintERC721To tos length does not match tokenIds length"
        );
        require(
            _tos.length == _attributes.length,
            "NFTFactory: batchMintERC721To tos length does not match attributes length"
        );
        require(
            _tos.length == _attributesMax.length,
            "NFTFactory: batchMintERC721To tos length does not match attributesMax length"
        );
        require(
            _tos.length == _genes.length,
            "NFTFactory: batchMintERC721To tos length does not match genes length"
        );
        require(
            _tos.length == _tokenURIs.length,
            "NFTFactory: batchMintERC721To tos length does not match tokenURIs length"
        );
        IERC721 erc721 = IERC721(_erc721Address);

        for (uint256 _i; _i < _tos.length; _i++) {
            erc721.mintTo(_tos[_i], _tokenId[_i], _attributes[_i], _attributesMax[_i], _genes[_i], _tokenURIs[_i]);
        }
    }

}
