//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../access/OperatorAccessControl.sol";

import "../tokenization/SuperSquidERC721V2.sol";
import "../libraries/GameBattleLib.sol";

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
contract SquidBattleV2 is OperatorAccessControl, ReentrancyGuard {

    using GameBattleLib for GameBattleLib.BattleData;

    /*************************************Event***************************************************/
    event BaseConfigUpdated(
        uint256 flag_,
        uint256 maxNFTCount_,
        uint256 racingGamePrice_,
        uint256 battleStartTime_,
        uint256 battleSpanTime_,
        uint256 racingSpanTime_,
        uint256 platFormFeeRatio_
    );
    event BattleInitEvent(uint256 battleStartTime_, uint256 battleSpanTime_, uint256 racingStartTime_, uint256 racingSpanTime_);
    event BattleLiquidateEvent(uint256 round_, uint256 status_, uint256 participateNum_);
    event RacingLiquidateEvent(uint256 round_, uint256 status_, uint256 racingWinnerNum_, uint256 firstTokenId_);
    event JoinBattleEvent(address indexed userAddress_, uint256 round_, uint256 tokenId_);
    event JoinRacingEvent(address indexed userAddress_, uint256 round_, uint256 tokenId_, uint256 amount_);
    event ClaimEvent(address indexed to, uint256 amount, uint256 type_);

    /*************************************Config***************************************************/
    //Maximum number of NFTs per game
    uint256 internal maxNFTCount = 456;
    //Number of tickets to be paid for each parameter competition
    uint256 internal racingPriceAmount = 1e17;
    //Random number distortion salt
    uint256 internal salt = 99;
    //Proportion of service charges charged by the platform
    uint256 internal platFormFeeRatio = 95;
    //Maximum number of times each NFT can be selected
    uint256 internal guessCountMaxPerTokenId = 20;
    //Platform fee address
    address internal feeAddress;
    //NFT contract address
    address internal erc721Address;

    /*************************************Statistic***************************************************/
    uint256 internal totalNFTCount;
    uint256 internal totalRacingCount;

    //All current game amounts. totalAmount=battleAmount+racingAmount;
    uint256 internal totalAmount;
    //Current game battle amount
    uint256 internal battleAmount;
    //Current game racing amount
    uint256 internal racingAmount;
    //User does not withdraw cash
    uint256 internal notWithdrawAmount;
    // Total handling fee charged by the platform
    uint256 totalFeeAmount = 0;

    /*************************************Battle***************************************************/
    //status = true means the race has been activated and properly configured
    uint256 internal status;
    uint256 internal battleStartTime = 0;
    uint256 internal battleSpanTime = 12 * 60 * 60;
    uint256 internal racingStartTime = 0;
    uint256 internal racingSpanTime = 12 * 60 * 60;
    uint256 internal racingUserCount = 16;
    //Game data corresponding to round
    mapping(uint256 => GameBattleLib.BattleData) internal bts2BattleHistory;
    //All round of the game
    uint256[] public btsRounds;
    //User address corresponding to tokenId
    mapping(uint256 => address) internal tokenId2Address;
    //TokenId selected by user address in the round
    mapping(uint256 => mapping(address => uint256[])) internal round2RacingUserGuessTokens;
    //Number of times the match tokenId is bet
    mapping(uint256 => mapping(uint256 => uint256)) internal round2TokenIdBetNum;
    //All battle rounds participated by user address
    mapping(address => uint256[]) internal address2BattleRounds;
    //All racing rounds participated by user address
    mapping(address => uint256[]) internal address2RacingRounds;
    //Bonus corresponding to user address
    mapping(address => uint256) internal userReward;


    constructor() {
        status = 0;
    }

    /**
     * @dev Set global configuration
     **/
    function setConfig(
        uint256 _status,
        uint256 _maxNFTCount,
        uint256 _racingGamePrice,
        address _feeAddress,
        address _erc721Address,
        uint256 _battleStartTime,
        uint256 _battleSpanTime,
        uint256 _racingSpanTime,
        uint256 _platFormFeeRatio
    ) public onlyOwner {
        require(_status == 0 || _status == 1 || _status == 2, "SetConfig: status in 0,1,2");
        require(_maxNFTCount > 0, "SetConfig: The maxNFTCount>0");
        require(_racingGamePrice > 0, "SetConfig: The racingGamePrice>0");
        require(address(_feeAddress) != address(0), "SetConfig: The fee address cannot be a 0 address");
        require(address(_erc721Address) != address(0), "SetConfig: The 721 address cannot be a 0 address");
        require(_battleSpanTime > 0, "SetConfig: The battleSpanTime>0");
        require(_racingSpanTime > 0, "SetConfig: The racingSpanTime>0");
        require(_platFormFeeRatio >= 0 && _platFormFeeRatio <= 100, "SetConfig: The 100>=platFormFeeRatio>=0");

        maxNFTCount = _maxNFTCount;
        racingPriceAmount = _racingGamePrice;
        feeAddress = _feeAddress;
        erc721Address = _erc721Address;
        battleSpanTime = _battleSpanTime;
        racingSpanTime = _racingSpanTime;
        platFormFeeRatio = _platFormFeeRatio;

        if (status == 0 && _status == 1) {
            if (_battleStartTime == 0) {
                battleStartTime = block.timestamp;
            } else {
                battleStartTime = _battleStartTime;
            }
            racingStartTime = battleStartTime + battleSpanTime;
            bts2BattleHistory[battleStartTime].initBattle(battleStartTime);
            btsRounds.push(battleStartTime);
            emit BattleInitEvent(battleStartTime, battleSpanTime, racingStartTime, racingSpanTime);
        }
        status = _status;
        emit BaseConfigUpdated(_status, maxNFTCount, _racingGamePrice, _battleStartTime, _battleSpanTime, _racingSpanTime, _platFormFeeRatio);
    }



    /**
     * @dev Get global configuration and current game properties
     **/
    function getConfig() public view returns (
        uint256 status_,
        uint256 maxNFTCount_,
        uint256 racingGamePrice_,
        uint256 currentNFTCount_,
        uint256 timestamp_,
        uint256 notWithdrawAmount_,
        uint256 currentRound_,
        uint256 battleSpanTime_,
        uint256 racingStartTime_,
        uint256 battleEnd_,
        uint256 platFormFeeRatio_
    ){
        GameBattleLib.BattleData storage battleDataInfo = bts2BattleHistory[
        battleStartTime
        ];
        return (
        status,
        maxNFTCount,
        racingPriceAmount,
        battleDataInfo.participateTokenIds.length,
        block.timestamp,
        notWithdrawAmount,
        battleStartTime,
        battleSpanTime,
        racingStartTime,
        battleStartTime + battleSpanTime + racingSpanTime,
        platFormFeeRatio
        );
    }

    /**
     * @dev Get all ConfigAddress
     **/
    function getConfigAddress() public view returns (
        address feeAddress_,
        address erc721Address_
    ){
        return (
        feeAddress,
        erc721Address
        );
    }

    /**
     * @dev Get all statistics
     **/
    function getStatistic() public view returns (
        uint256 totalNFTCount_,
        uint256 totalRacingCount_,
        uint256 totalBalance_,
        uint256 totalFeeAmount_,
        uint256 battleBalance_,
        uint256 racingBalance_,
        uint256 notWithdrawAmount_
    ){
        return (
        totalNFTCount,
        totalRacingCount,
        totalAmount,
        totalFeeAmount,
        battleAmount,
        racingAmount,
        notWithdrawAmount
        );
    }


    /*************************************Battle***************************************************/
    /**
     * @dev Join the game
     * @param _tokenIds NFT tokenId
     */
    function joinBattle(uint256[] memory _tokenIds) public payable nonReentrant returns (uint256 round_)
    {
        require(
            battleStartTime < block.timestamp,
            "Battle: The current block time cannot be later than start time"
        );
        require(
            address(_msgSender()) != address(0),
            "Battle: The sending address cannot be a 0 address"
        );

        GameBattleLib.BattleData storage battleDataInfo = bts2BattleHistory[
        battleStartTime
        ];
        //The following process contract status must be 1
        require(status == 1, "Battle: Contract status must be 1");
        require(
            battleDataInfo.participateTokenIds.length <= maxNFTCount,
            "Battle: The current number of participants is greater than maxNFTCount"
        );

        SuperSquidERC721V2 erc721 = SuperSquidERC721V2(erc721Address);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];

            //Current address is not the owner of NFT
            if (address(erc721.ownerOf(tokenId)) != _msgSender()) {
                continue;
            }
            //NFT has been used
            if (erc721.getGeneByIndex(tokenId, 3) != 0) {
                continue;
            }

            battleDataInfo.participateTokenIds.push(tokenId);

            tokenId2Address[tokenId] = _msgSender();
            //All States are uniformly set to 2-die, and the only user who finally wins the game is set to 1-win
            erc721.setGeneByIndex(tokenId, 3, 2);
            totalNFTCount++;
            emit JoinBattleEvent(_msgSender(), battleDataInfo.round, tokenId);
        }
        // record each user join game
        uint256 nftPrice = erc721.getPrice();
        battleDataInfo.battleTotalTicketAmount = battleDataInfo.participateTokenIds.length * nftPrice;

        address2BattleRounds[_msgSender()].push(battleStartTime);


        uint256 battleEndTime = battleStartTime + battleSpanTime;
        if (block.timestamp >= battleEndTime) {
            _liquidateBattle(battleDataInfo);
        }
        return (battleStartTime);
    }

    /**
     * @dev Liquidation Battle
     * @param _battleDataInfo battleDataInfo
     **/
    function _liquidateBattle(
        GameBattleLib.BattleData storage _battleDataInfo
    ) internal {
        //Modify the contract status to being bet
        status = 2;
        _generateRacingTokenIds(_battleDataInfo);
        if (_battleDataInfo.racingTokenIds.length > 0) {
            _generateChampion(_battleDataInfo);
        }
        emit BattleLiquidateEvent(_battleDataInfo.round, status, _battleDataInfo.participateTokenIds.length);
    }

    /**
     * @dev Generate selected tokenIds
     * @param _battleDataInfo battleDataInfo
     **/
    function _generateRacingTokenIds(
        GameBattleLib.BattleData storage _battleDataInfo
    ) internal {
        //Get people who have participated in the game
        uint256[] memory tokenIds = _battleDataInfo.participateTokenIds;
        uint256 battleTokensLen = tokenIds.length;
        //If the number of NFT in the battle is less than 16, it does not need to be random
        if (battleTokensLen <= racingUserCount) {
            for (uint256 i = 0; i < battleTokensLen; i++) {
                _battleDataInfo.racingTokenIds.push(tokenIds[i]);
            }
        } else {
            uint256 randomIdx = 0;
            while (true) {
                (salt, randomIdx) = random(salt, battleTokensLen);

                uint256 randomTokenId = tokenIds[randomIdx];

                if (randomTokenId != 0) {
                    _battleDataInfo.racingTokenIds.push(randomTokenId);
                    //Set this index data=0
                    tokenIds[randomIdx] = 0;
                }
                if (_battleDataInfo.racingTokenIds.length == racingUserCount) {
                    break;
                }
            }
        }
    }

    /**
     * @dev Generate Champion
     * @param _battleDataInfo battleDataInfo
     **/
    function _generateChampion(GameBattleLib.BattleData storage _battleDataInfo) internal {
        uint256 randomNumber = 0;
        (salt, randomNumber) = random(
            salt,
            _battleDataInfo.racingTokenIds.length
        );

        uint256 championTokenId = _battleDataInfo.racingTokenIds[randomNumber];

        _battleDataInfo.firstTokenId = championTokenId;
        _battleDataInfo.winnerAddress = tokenId2Address[championTokenId];
    }

    /**
     * @dev Liquidation Battle Job
     **/
    function liquidateBattle() public payable isOperatorOrOwner {
        require(status == 1, "Game: status is 0");
        GameBattleLib.BattleData storage battleDataInfo = bts2BattleHistory[battleStartTime];
        _liquidateBattle(battleDataInfo);
    }

    /*************************************Racing***************************************************/
    /**
     * @dev Join the game
     * @param _tokenIds NFT tokenId
     **/
    function joinRacing(uint256[] memory _tokenIds) public payable nonReentrant returns (uint256 round_)
    {
        require(battleStartTime < block.timestamp, "Racing: The current block time cannot be later than start time");
        require(address(_msgSender()) != address(0), "Racing: The sending address cannot be a 0 address");
        require(status == 2, "Racing: current game is not in battle");
        require(_tokenIds.length > 0, "Racing: Choose at least one");
        require(_msgSender().balance >= racingPriceAmount * _tokenIds.length, "Racing: User balance is not enough");
        require(msg.value >= racingPriceAmount * _tokenIds.length, "Racing: racingGamePrice error");

        require(round2RacingUserGuessTokens[battleStartTime][_msgSender()].length == 0, "Racing: The address had join racing");
        GameBattleLib.BattleData storage battleDataInfo = bts2BattleHistory[battleStartTime];

        uint256 championTokenId = battleDataInfo.firstTokenId;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint tokenId = _tokenIds[i];
            //If the current tokenId is selected, the data exceeds the max limit
            uint256 count = round2TokenIdBetNum[battleStartTime][tokenId];
            require(count <= guessCountMaxPerTokenId, "Racing: TokenId guess max");

            round2RacingUserGuessTokens[battleStartTime][_msgSender()].push(tokenId);
            if (championTokenId == tokenId) {
                battleDataInfo.racingWinnerAddresses.push(_msgSender());
            }
            round2TokenIdBetNum[battleStartTime][tokenId]++;
            totalRacingCount++;
            emit JoinRacingEvent(_msgSender(), battleDataInfo.round, tokenId, racingPriceAmount);
        }
        // record each user join game
        battleDataInfo.racingTotalTicketAmount = battleDataInfo.racingTotalTicketAmount + msg.value;

        address2RacingRounds[_msgSender()].push(battleStartTime);

        uint256 racingEndTime = racingStartTime + racingSpanTime;
        if (block.timestamp >= racingEndTime) {
            _liquidateRacing(battleDataInfo);
        }
        return (battleStartTime);
    }

    /**
     * @dev Liquidation Racing
     * @param _battleDataInfo battleDataInfo
     **/
    function _liquidateRacing(GameBattleLib.BattleData storage _battleDataInfo) internal {
        SuperSquidERC721V2 erc721 = SuperSquidERC721V2(erc721Address);

        status = 1;
        _battleDataInfo.isComplete = true;

        //If no one takes part in the game
        if (_battleDataInfo.firstTokenId == 0) {
            //Restart a round of the game
            battleStartTime = racingStartTime + racingSpanTime;
            racingStartTime = battleStartTime + battleSpanTime;
            bts2BattleHistory[battleStartTime].initBattle(battleStartTime);
            btsRounds.push(battleStartTime);
            emit BattleInitEvent(battleStartTime, battleSpanTime, racingStartTime, racingSpanTime);
            return;
        }
        //Set first winner status
        erc721.setGeneByIndex(_battleDataInfo.firstTokenId, 3, 1);

        address[] memory racingWinnerAddresses = _battleDataInfo.racingWinnerAddresses;
        if (_battleDataInfo.racingWinnerAddresses.length == 0) {
            userReward[_battleDataInfo.winnerAddress] += _battleDataInfo.racingTotalTicketAmount;
        } else {
            uint256 racingAverageBonus = _battleDataInfo.racingTotalTicketAmount / racingWinnerAddresses.length;
            for (uint256 i = 0; i < racingWinnerAddresses.length; i++) {
                userReward[racingWinnerAddresses[i]] += racingAverageBonus;
            }
        }

        //Get ticket price
        userReward[_battleDataInfo.winnerAddress] += _battleDataInfo.battleTotalTicketAmount;

        notWithdrawAmount += _battleDataInfo.racingTotalTicketAmount;
        racingAmount += _battleDataInfo.racingTotalTicketAmount;
        totalAmount += _battleDataInfo.racingTotalTicketAmount;

        notWithdrawAmount += _battleDataInfo.battleTotalTicketAmount;
        battleAmount += _battleDataInfo.battleTotalTicketAmount;
        totalAmount += _battleDataInfo.battleTotalTicketAmount;

        //Restart a round of the game
        battleStartTime = racingStartTime + racingSpanTime;
        racingStartTime = battleStartTime + battleSpanTime;
        bts2BattleHistory[battleStartTime].initBattle(battleStartTime);
        btsRounds.push(battleStartTime);
        emit BattleInitEvent(battleStartTime, battleSpanTime, racingStartTime, racingSpanTime);
        emit RacingLiquidateEvent(_battleDataInfo.round, status, racingWinnerAddresses.length, _battleDataInfo.firstTokenId);
    }

    /**
     * @dev Liquidation Battle Job
     **/
    function liquidateRacing() public payable isOperatorOrOwner {
        require(status == 2, "Game: status is 0");
        GameBattleLib.BattleData storage battleDataInfo = bts2BattleHistory[battleStartTime];
        _liquidateRacing(battleDataInfo);
    }

    /*************************************Claim***************************************************/
    /**
     * @dev claim
     **/
    function claim()  public payable{
        if (userReward[address(_msgSender())] == 0) {
            return;
        }

        uint256 balance = userReward[address(_msgSender())];
        require(address(this).balance >= balance, "Game: game reward balance is not enough");
        require(notWithdrawAmount >= balance, "Game: notWithdrawAmount balance is not enough");

        uint256 userClaimAmount = (balance * platFormFeeRatio) / 100;
        totalFeeAmount = totalFeeAmount + balance - userClaimAmount;

        notWithdrawAmount -= balance;
        userReward[address(_msgSender())] = 0;

        payable(_msgSender()).transfer(userClaimAmount);
        payable(feeAddress).transfer(balance - userClaimAmount);


        emit ClaimEvent(_msgSender(), userClaimAmount, 0);
        emit ClaimEvent(feeAddress, balance - userClaimAmount, 1);

    }

    /*************************************Get Function***************************************************/
    /**
     * @dev Get the reward by userAddress
     * @param _userAddress  userAddress
     **/
    function getReward(address _userAddress) public view returns (uint256) {
        return userReward[_userAddress];
    }

    /**
     * @dev Get all round
     **/
    function getRounds() public view returns (uint256[] memory btsRounds_){
        return btsRounds;
    }

    /**
     * @dev Get global configuration and current game properties
     * @param _round  identification of the game
     **/
    function getBattleData(uint256 _round) public view returns (
        uint256 round_,
        bool isComplete_,
        uint256 firstTokenId_,
        address winnerAddress_,
        uint256 battleTotalTicketAmount_,
        uint256 racingTotalTicketAmount_,
        uint256[] memory racingTokenIds_,
        uint256[] memory participateTokenIds_,
        address[] memory racingWinnerAddresses_
    ){
        GameBattleLib.BattleData storage battleDataInfo = bts2BattleHistory[_round];

        return (
        battleDataInfo.round,
        battleDataInfo.isComplete,
        battleDataInfo.isComplete ? battleDataInfo.firstTokenId : 0,
        battleDataInfo.isComplete ? battleDataInfo.winnerAddress : address(0),
        battleDataInfo.battleTotalTicketAmount,
        battleDataInfo.racingTotalTicketAmount,
        battleDataInfo.racingTokenIds,
        battleDataInfo.participateTokenIds,
        battleDataInfo.isComplete ? battleDataInfo.racingWinnerAddresses : new address[](0)
        );
    }

    /**
     * @dev Get the user data participating in the game
     * @param _round  identification of the game
     **/
    function getParticipateTokenIds(uint256 _round) public view returns (uint256[] memory)
    {
        GameBattleLib.BattleData storage battleDataInfo = bts2BattleHistory[_round];
        return (battleDataInfo.participateTokenIds);
    }
    /**
     * @dev Get the user data participating in the game
     * @param _round  identification of the game
     **/
    function getRacingTokenIds(uint256 _round) public view returns (uint256[] memory){
        GameBattleLib.BattleData storage battleDataInfo = bts2BattleHistory[_round];
        return (battleDataInfo.racingTokenIds);
    }

    /**
     * @dev Gets the number of times each tokenId of the specified round is selected
     * @param _round  identification of the game
     **/
    function getTokenIdGuessCounts(uint256 _round) public view returns (uint256[] memory){
        GameBattleLib.BattleData storage battleDataInfo = bts2BattleHistory[_round];
        uint256[] memory racingTokenIds = battleDataInfo.racingTokenIds;
        uint256[] memory tokenIdCounts = new uint256[](racingTokenIds.length);
        for (uint256 i = 0; i < racingTokenIds.length; i++) {
            tokenIdCounts[i] = round2TokenIdBetNum[battleDataInfo.round][racingTokenIds[i]];
        }
        return tokenIdCounts;
    }

    /**
     * @dev Get the user data participating in the game
     * @param _round  identification of the game
     **/
    function getRacingGuessTokenIds(uint256 _round, address _address) public view returns (uint256[] memory){
        return round2RacingUserGuessTokens[_round][_address];
    }

    /**
     * @dev Gets the number of tokenId the specified round is selected
     * @param _round  identification of the game
     **/
    function getBetNum(uint256 _round, uint256 _tokenId) public view returns (uint256) {
        return round2TokenIdBetNum[_round][_tokenId];
    }

    /**
     * @dev Battle round for the user address
     * @param _address  user address
     **/
    function getBattles(address _address) public view returns (uint256[] memory){
        return address2BattleRounds[_address];
    }

    /**
     * @dev Racing round for the user address
     * @param _address  user address
     **/
    function getRacing(address _address) public view returns (uint256[] memory){
        return address2RacingRounds[_address];
    }


    /**
     * @dev Get random number
     **/
    function random(uint256 _salt, uint256 _baseNumber) internal view returns (uint256, uint256){
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
