//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

/**
 * @title GameBattleLib
 *
 * @author Squid
 */
library GameBattleLib {
    struct BattleData {
        //The height of the last restricted block for the user to participate in the competition  block.timestamp
        uint256 round;
        //isComplete = true means the race has been activated and properly configured
        bool isComplete;
        //First corresponding NFT address
        address winnerAddress;
        //First corresponding NFT tokenId
        uint256 firstTokenId;
        //FT track information for the current race
        uint256[] racingTokenIds;
        //FT track information for the current race
        uint256[] participateTokenIds;

        //All battle ticket amount
        uint256 battleTotalTicketAmount;
        //All racing ticket amount
        uint256 racingTotalTicketAmount;
        //All winner
        address[] racingWinnerAddresses;
    }


    function initBattle(
        GameBattleLib.BattleData storage _self,
        uint256 _blockTimestamp
    ) internal {
        _self.round = _blockTimestamp;
        _self.isComplete = false;
        _self.firstTokenId = 0;
    }
}
