//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "../access/MinterAccessControl.sol";
import "./Base64.sol";

/**
                                                                                              ##
  :####:                                                      :####:                          ##
 :######                                                     :######                          ##       ##
 ##:  :#                                                     ##:  :#                                   ##
 ##        ##    ##  ##.###:    .####:    ##.####            ##         :###.##  ##    ##   ####     #######
 ###:      ##    ##  #######:  .######:   #######            ###:      :#######  ##    ##   ####     #######
 :#####:   ##    ##  ###  ###  ##:  :##   ###.               :#####:   ###  ###  ##    ##     ##       ##
  .#####:  ##    ##  ##.  .##  ########   ##                  .#####:  ##.  .##  ##    ##     ##       ##
     :###  ##    ##  ##    ##  ########   ##                     :###  ##    ##  ##    ##     ##       ##
       ##  ##    ##  ##.  .##  ##         ##                       ##  ##.  .##  ##    ##     ##       ##
 #:.  :##  ##:  ###  ###  ###  ###.  :#   ##                 #:.  :##  ###  ###  ##:  ###     ##       ##.
 #######:   #######  #######:  .#######   ##                 #######:  :#######   #######  ########    #####
 .#####:     ###.##  ##.###:    .#####:   ##                 .#####:    :###.##    ###.##  ########    .####
                     ##                                                      ##
                     ##                                                      ##
                     ##                                                      ##
 */
contract SuperSquidERC721V2 is
ERC721Enumerable,
ReentrancyGuard,
Ownable,
MinterAccessControl
{
    event Squid721OperatorUpdated(
        address indexed _operatorAddress,
        bool indexed _flag
    );

    event Squid721GeneUpdated(
        address indexed _operatorAddress,
        uint256 indexed _tokenId
    );
    //Used to manipulate game attribute
    mapping(address => bool) private operators;

    uint256 private price;

    //0-characteristic 1-occupation 2-physical 3-(0-unused 1-win 2-die) 4-reserve 5-reserve 6-reserve
    mapping(uint256 => uint256[]) private gene;
    mapping(uint256 => string) private life;

    uint256[] winners;

    address receiverAddress;

    uint256 internal salt = 99;
    string private bg =
    "https://gateway.pinata.cloud/ipfs/QmT2Lqr7m8ZT4ZKo3Fx17FznoFg3iUEw3FcuHkAtstqVpp";

    string[] private characteristic = [
    "Man",
    "Elder",
    "Young Man",
    "Young Woman",
    "Woman",
    "Foreigner",
    "Transgender",
    "Squid Man",
    "Alien"
    ];

    string[] private occupation = [
    "Driver",
    "Financier",
    "Police",
    "Thief",
    "Gangster",
    "Laborer",
    "Surgeon",
    "Priest",
    "Math Teacher",
    "Glass worker",
    "Mysterious occupational",
    "Super Star",
    "Scientist",
    "The Richest",
    "Second-Generation Rich",
    "President",
    "Lawyer",
    "Fisher",
    "Farmer",
    "Haulage Man",
    "Courier",
    "Chef",
    "Developer",
    "Designer",
    "Artist",
    "entrepreneur",
    "Athlete",
    "Director",
    "Actor",
    "Coach",
    "Sales",
    "Accountant",
    "Photographer",
    "Tour Guide",
    "Hairdresser",
    "Cleaner",
    "Barista",
    "Dishwasher",
    "Recruiter",
    "Beggar",
    "Rapper"
    ];
    string[] private physical = [
    "Brawny",
    "Health",
    "Normal",
    "Fat",
    "Pygmyism",
    "Emaciated",
    "Valetudinarianism",
    "Terminal Cancer",
    "Limb Disability",
    "Psychogeny",
    "Depressive Disoder",
    "Energy",
    "Enthusiasm",
    "Indifferent",
    "Loyalty",
    "Intelligence",
    "Irritability",
    "Impulsivity",
    "Depression",
    "Melancholy",
    "Dull",
    "Dementia",
    "Abnormal",
    "Crapulent",
    "Social Disorder",
    "Blindness",
    "Hypertension",
    "Stability",
    "Dexterous",
    "Eutrapelia",
    "Stupid",
    "Weakness",
    "Optimistic",
    "Strong",
    "Endurance",
    "Speed",
    "Insomnia",
    "Influenza",
    "Insomnia",
    "Nervous",
    "Tired"
    ];

    string[] private result = ["", "WIN", "DIE"];

    constructor(string memory name, string memory symbol)
    ERC721(name, symbol)
    {}

    function claim(
        uint256 _nftAmount
    ) public payable nonReentrant {
        require(
            msg.value == _nftAmount * price,
            "msg.value is incorrect"
        );
        require(_nftAmount <= 10, "Wrong token amount. max 10");

        for (uint256 i = 0; i < _nftAmount; i++) {
            //start from 1e18
            uint256 tokenId = this.totalSupply() + 1e7;
            uint256 rand1 = 0;
            uint256 rand2 = 0;
            uint256 rand3 = 0;
            (salt, rand1) = random(salt, characteristic.length);
            (salt, rand2) = random(salt, occupation.length);
            (salt, rand3) = random(salt, physical.length);

            gene[tokenId].push(rand1);
            gene[tokenId].push(rand2);
            gene[tokenId].push(rand3);
            gene[tokenId].push(0);
            //unused
            gene[tokenId].push(0);
            gene[tokenId].push(0);
            gene[tokenId].push(0);
            _safeMint(_msgSender(), tokenId);
        }
        payable(receiverAddress).transfer(msg.value);
    }

    function tokenURI(uint256 tokenId)
    public
    view
    override
    returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string[21] memory parts;
        parts[
        0
        ] = '<svg id="p" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 278 414"><defs><style>.cls-10,.cls-11,.cls-2,.cls-4,.cls-5{isolation:isolate;font-family:AbadiMT-CondensedExtraBold, Abadi MT Condensed Extra Bold;font-weight:800;}.cls-2{font-size:20px;letter-spacing:0.08em;}.cls-2,.cls-4,.cls-5{fill:#e6d0d0;}.cls-10,.cls-11,.cls-4{font-size:32px;letter-spacing:0.08em;}.cls-5{font-size:18px;}.cls-10{fill:#980003;}.cls-11{fill:#009874;}.cls-12{color: #e6d0d0;word-break: break-all;word-wrap: break-word;font-family: AbadiMT-CondensedExtraBold, Abadi MT Condensed Extra old;font-weight: 800;margin: 0;padding: 0;font-size: 18px;line-height: 24px;}</style></defs><image width="278" height="414" xlink:href="';
        parts[1] = bg;
        parts[
        2
        ] = '"/><text class="cls-2" transform="translate(56 118)">#</text><text class="cls-4" transform="translate(71 118)">';
        parts[3] = toString(tokenId);
        parts[4] = '</text><text class="cls-5" transform="translate(27 163)">';
        parts[5] = characteristic[gene[tokenId][0]];
        parts[6] = '</text><text class="cls-5" transform="translate(27 192)">';
        parts[7] = occupation[gene[tokenId][1]];
        parts[8] = '</text><text class="cls-5" transform="translate(27 221)">';
        parts[9] = physical[gene[tokenId][2]];
        parts[
        10
        ] = '</text><foreignObject x="27" y="234" width="220" height="100"><p xmlns="http://www.w3.org/1999/xhtml" class="cls-12">';
        parts[11] = life[tokenId];
        parts[
        12
        ] = '</p></foreignObject><text class="cls-5" transform="translate(27 279)">';
        parts[13] = gene[tokenId][4] == 0 ? "" : toString(gene[tokenId][4]);
        parts[14] = '</text><text class="cls-5" transform="translate(27 308)">';
        parts[15] = gene[tokenId][5] == 0 ? "" : toString(gene[tokenId][5]);
        parts[16] = '</text><text class="cls-5" transform="translate(27 337)">';
        parts[17] = gene[tokenId][6] == 0 ? "" : toString(gene[tokenId][6]);
        if (gene[tokenId][3] == 1) {
            parts[
            18
            ] = '</text><text class="cls-11" transform="translate(200 393)">';
        } else if (gene[tokenId][3] == 2) {
            parts[
            18
            ] = '</text><text class="cls-10" transform="translate(200 393)">';
        } else {
            parts[
            18
            ] = '</text><text class="cls-10" transform="translate(200 393)">';
        }
        parts[19] = result[gene[tokenId][3]];
        parts[20] = "</text></svg>";

        string memory output = string(
            abi.encodePacked(
                parts[0],
                parts[1],
                parts[2],
                parts[3],
                parts[4],
                parts[5],
                parts[6],
                parts[7],
                parts[8]
            )
        );
        output = string(
            abi.encodePacked(
                output,
                parts[9],
                parts[10],
                parts[11],
                parts[12],
                parts[13],
                parts[14],
                parts[15],
                parts[16]
            )
        );
        output = string(
            abi.encodePacked(output, parts[17], parts[18], parts[19], parts[20])
        );
        return output;
    }

    function updateLife(uint256 _tokenId, string memory _life)
    public
    nonReentrant
    {
        require(_exists(_tokenId), "ERC721: Wrong tokenId");
        require(bytes(_life).length <= 22, "ERC721: life length too long");
        require(
            ownerOf(_tokenId) == _msgSender(),
            "ERC721: transfer of token that is not own"
        );
        life[_tokenId] = _life;
    }

    function exist(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    function getGene(uint256 _tokenId) public view returns (uint256[] memory) {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        uint256[] memory genes = gene[_tokenId];
        return genes;
    }

    function getGeneByIndex(uint256 _tokenId, uint256 _index)
    public
    view
    returns (uint256)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        uint256[] memory genes = gene[_tokenId];
        require(_index <= genes.length, "ERC721: gene index error");
        return genes[_index];
    }

    function setGeneByIndex(
        uint256 _tokenId,
        uint256 _index,
        uint256 _value
    ) public {
        require(operators[_msgSender()], "ERC721: attribute address error");
        require(_index > 2 && _index < 7, "ERC721: index >2 and <7");
        if (_index == 3) {
            require(_value < 3, "ERC721: index 2,value error");
            if (_value == 1) {
                winners.push(_tokenId);
            }
        }
        gene[_tokenId][_index] = _value;
    }

    /**
     * @dev Set a NFT operator
     * @param _operatorAddress the tokenId of NFT
     * @param _flag the attributes of NFT
     **/
    function setOperator(address _operatorAddress, bool _flag)
    public
    onlyOwner
    {
        operators[_operatorAddress] = _flag;
        emit Squid721OperatorUpdated(_operatorAddress, _flag);
    }

    function setBg(string memory _bg) public onlyOwner {
        bg = _bg;
    }

    function setPrice(uint256 _mintPrice)
    public
    onlyOwner
    {
        require(
            _mintPrice > 0,
            "Battle: The sending address cannot be a 0 address"
        );
        price = _mintPrice;
    }

    function setReceiverAddress(address _receiverAddress)
    public
    onlyOwner
    {
        receiverAddress = _receiverAddress;
    }

    function getPrice() public view returns (uint256) {
        return price;
    }

    function getBg() public view returns (string memory) {
        return bg;
    }

    function getReceiverAddress() public view returns (address) {
        return receiverAddress;
    }

    function getWinners() public view returns (uint256[] memory) {
        return winners;
    }

    function getOperator(address _operatorAddress) public view returns (bool) {
        return operators[_operatorAddress];
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function withdraw() public nonReentrant onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    /**
     * @dev Get random number
     **/
    function random(uint256 _salt, uint256 _baseNumber)
    internal
    view
    returns (uint256, uint256)
    {
        uint256 r = uint256(
            keccak256(
                abi.encodePacked(
                    _salt,
                    block.coinbase,
                    block.difficulty,
                    block.number,
                    block.timestamp
                )
            )
        );
        return (r, r % _baseNumber);
    }
}
