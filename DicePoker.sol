// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./RandomNumber.sol";

contract DicePoker {

    enum DiceFace {Nine, Ten, Jack, Queen, King, Ace}

    struct Player {
        address payable addr;
        uint32 numRollsLeft;
        DiceFace[5] dice;
    }

    Player public player1;
    Player public player2;

    bool public gameStarted = false;
    uint256 public pot;

    RandomNumber public randomNumberContract; // Instance of RandomNumber contract

    // Mapping to convert DiceFace enum to string
    mapping(DiceFace => string) public diceFaceToString;

    modifier onlyBeforeGameStarts() {
        require(!gameStarted, "Game has already started");
        _;
    }

    modifier onlyPlayer() {
        require(
            msg.sender == player1.addr || msg.sender == player2.addr,
            "Only players can call this"
        );
        _;
    }

    constructor(address _randomNumberContract) {
        player1 = Player(payable(msg.sender), 3, [DiceFace.Nine, DiceFace.Nine, DiceFace.Nine, DiceFace.Nine, DiceFace.Nine]);
        randomNumberContract = RandomNumber(_randomNumberContract);

        // Initialize mapping for DiceFace to string
        diceFaceToString[DiceFace.Nine] = "N";
        diceFaceToString[DiceFace.Ten] = "T";
        diceFaceToString[DiceFace.Jack] = "J";
        diceFaceToString[DiceFace.Queen] = "Q";
        diceFaceToString[DiceFace.King] = "K";
        diceFaceToString[DiceFace.Ace] = "A";
    }

    function joinGame() public onlyBeforeGameStarts {
        // No fee to join, just start the game
        player2 = Player(payable(msg.sender), 3, [DiceFace.Nine, DiceFace.Nine, DiceFace.Nine, DiceFace.Nine, DiceFace.Nine]);
        gameStarted = true;
    }

    function rollDice(uint8[] calldata _diceToReRoll) public onlyPlayer {

        Player storage player = msg.sender == player1.addr ? player1 : player2;

        require(player.numRollsLeft > 0, "No rolls left");

        // Make a request to generate random numbers
        randomNumberContract.makeRequestUint256Array();

       

        // Fetch random numbers from RandomNumber contract
        (uint256[] memory randomNumbers,) = randomNumberContract.getGeneratedData();
        require(randomNumbers.length == 5, "Invalid response length");

        for(uint i = 0; i < player.dice.length; i++) {
            if(_diceToReRoll[i] == 1) {
                // Map random number to DiceFace
                player.dice[i] = mapRandomToDiceFace(randomNumbers[i]);
            }
        }

        player.numRollsLeft--;
    }

    // Function to map random number to DiceFace
    function mapRandomToDiceFace(uint256 randomNumber) internal pure returns (DiceFace) {
        uint256 randNum = randomNumber % 6;

        if (randNum == 0) {
            return DiceFace.Nine;
        } else if (randNum == 1) {
            return DiceFace.Ten;
        } else if (randNum == 2) {
            return DiceFace.Jack;
        } else if (randNum == 3) {
            return DiceFace.Queen;
        } else if (randNum == 4) {
            return DiceFace.King;
        } else if (randNum == 5) {
            return DiceFace.Ace;
        }
    }

    // Function to view the outcome of dice rolls
    function viewDiceOutcome() public view onlyPlayer returns (string[5] memory) {
        Player storage player = msg.sender == player1.addr ? player1 : player2;

        string[5] memory diceFaces;

        for(uint i = 0; i < player.dice.length; i++) {
            diceFaces[i] = diceFaceToString[player.dice[i]];
        }

        return diceFaces;
    }

    function getFinalScore() public view onlyPlayer returns (string[5] memory player1Outcome, string[5] memory player2Outcome, uint8 player1Score, uint8 player2Score) {
        Player storage p1 = player1;
        Player storage p2 = player2;

        if (msg.sender == player1.addr) {
            player1Outcome = viewDiceOutcome();
            player2Outcome = getPlayerOutcome(p2.dice);
        } else {
            player1Outcome = getPlayerOutcome(p1.dice);
            player2Outcome = viewDiceOutcome();
        }

        player1Score = getOutcomeRank(p1.dice);
        player2Score = getOutcomeRank(p2.dice);
    }

    function getPlayerOutcome(DiceFace[5] memory dice) internal view returns (string[5] memory) {
        string[5] memory diceFaces;

        for(uint i = 0; i < dice.length; i++) {
            diceFaces[i] = diceFaceToString[dice[i]];
        }

        return diceFaces;
    }

    function decideWinner() public onlyPlayer {
        require(player1.numRollsLeft == 0 && player2.numRollsLeft == 0, "Both players must finish rolling");

        // Get the rank of outcomes for each player
        uint8 rankPlayer1 = getOutcomeRank(player1.dice);
        uint8 rankPlayer2 = getOutcomeRank(player2.dice);

        if (rankPlayer1 > rankPlayer2) {
            // Player 1 wins
            player1.addr.transfer(pot);
        } else if (rankPlayer1 < rankPlayer2) {
            // Player 2 wins
            player2.addr.transfer(pot);
        } else {
            
            player1.addr.transfer(pot / 2);
            player2.addr.transfer(pot / 2);
        }

        // Reset the game state
        resetGame();
    }

    function getOutcomeRank(DiceFace[5] memory dice) internal pure returns (uint8) {
        if (checkHand(dice, 5)) return 8; // Five of a kind
        if (checkHand(dice, 4)) return 7; // Four of a kind
        if (checkFullHouse(dice)) return 6; // Full house
        if (checkStraight(dice)) return 5; // Straight
        if (checkHand(dice, 3)) return 4; // Three of a kind
        if (checkTwoPair(dice)) return 3; // Two pair
        if (checkHand(dice, 2)) return 2; // One pair
        return 1; // Bust (high card)
    }

    function checkHand(DiceFace[5] memory dice, uint8 count) internal pure returns (bool) {
        for (uint8 i = 0; i < dice.length; i++) {
            uint8 sameCount = 1;
            for (uint8 j = 0; j < dice.length; j++) {
                if (i != j && dice[i] == dice[j]) {
                    sameCount++;
                }
            }
            if (sameCount == count) {
                return true;
            }
        }
        return false;
    }

    function checkFullHouse(DiceFace[5] memory dice) internal pure returns (bool) {
        return (checkHand(dice, 3) && checkHand(dice, 2));
    }

    function checkStraight(DiceFace[5] memory dice) internal pure returns (bool) {
        // Check for Ace, King, Queen, Jack, Ten or King, Queen, Jack, Ten, Nine
        for (uint8 i = 0; i < dice.length - 1; i++) {
            if (uint8(dice[i]) != uint8(dice[i + 1]) - 1) {
                return false;
            }
        }
        return true;
    }

    function checkTwoPair(DiceFace[5] memory dice) internal pure returns (bool) {
        uint8 pairCount = 0;
        for (uint8 i = 0; i < dice.length; i++) {
            for (uint8 j = i + 1; j < dice.length; j++) {
                if (uint8(dice[i]) == uint8(dice[j])) {
                    pairCount++;
                }
            }
        }
        return pairCount == 4; // Two pairs result in four matching dice
    }

    function resetGame() internal {
        gameStarted = false;
        pot = 0;
        player1.numRollsLeft = 3;
        player2.numRollsLeft = 3;
    }

    function getWinner() public view returns (address winner) {
        require(!gameStarted, "Game has not finished yet");

        // Get the rank of outcomes for each player
        uint8 rankPlayer1 = getOutcomeRank(player1.dice);
        uint8 rankPlayer2 = getOutcomeRank(player2.dice);

        if (rankPlayer1 > rankPlayer2) {
            winner = player1.addr;
        } else if (rankPlayer1 < rankPlayer2) {
            winner = player2.addr;
        } else {
            // It's a tie, winner is address(0)
            winner = address(0);
        }
    }
}
