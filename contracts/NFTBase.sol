// SPDX-License-Identifier:UNLICENSED
pragma solidity 0.8.16;

import "./NFTCore.sol";
import "./Interfaces/NFTBreedingInterface.sol";
import "./Interfaces/GeneScienceInterface.sol";

contract NFTBase is NFTCore {
    /*** DATA TYPES ***/

    /** @dev The main Kitty struct. Every cat in CryptoKitties is represented by a copy
     * of this structure, so great care was taken to ensure that it fits neatly into
     * exactly two 256-bit words. Note that the order of the members in this structure
     * is important because of the byte-packing rules used by Ethereum.
     *  Ref: http://solidity.readthedocs.io/en/develop/miscellaneous.html
     **/
    struct Kitty {
        // The Kitty's genetic code is packed into these 256-bits, the format is
        // sooper-sekret! A cat's genes never change.
        uint256 genes;
        // The timestamp from the block when this cat came into existence.
        uint64 birthTime;
        // The minimum timestamp after which this cat can engage in breeding
        // activities again. This same timestamp is used for the pregnancy
        // timer (for matrons) as well as the siring cooldown.
        uint64 cooldownEndBlock;
        // The ID of the parents of this kitty, set to 0 for gen0 cats.
        // Note that using 32-bit unsigned integers limits us to a "mere"
        // 4 billion cats. This number might seem small until you realize
        // that Ethereum currently has a limit of about 500 million
        // transactions per year! So, this definitely won't be a problem
        // for several years (even as Ethereum learns to scale).
        uint32 matronId;
        uint32 sireId;
        // Set to the ID of the sire cat for matrons that are pregnant,
        // zero otherwise. A non-zero value here is how we know a cat
        // is pregnant. Used to retrieve the genetic material for the new
        // kitten when the birth transpires.
        uint32 siringWithId;
        // Set to the index in the cooldown array (see below) that represents
        // the current cooldown duration for this Kitty. This starts at zero
        // for gen0 cats, and is initialized to floor(generation/2) for others.
        // Incremented by one for each successful breeding action, regardless
        // of whether this cat is acting as matron or sire.
        uint16 cooldownIndex;
        // The "generation number" of this cat. Cats minted by the CK contract
        // for sale are called "gen0" and have a generation number of 0. The
        // generation number of all other cats is the larger of the two generation
        // numbers of their parents, plus one.
        // (i.e. max(matron.generation, sire.generation) + 1)
        uint16 generation;
    }

    /*** CONSTANTS ***/

    /** @dev A lookup table indicating the cooldown duration after any successful
     *  breeding action, called "pregnancy time" for matrons and "siring cooldown"
     *  for sires. Designed such that the cooldown roughly doubles each time a cat
     *  is bred, encouraging owners not to just keep breeding the same cat over
     *  and over again. Caps out at one week (a cat can breed an unbounded number
     *  of times, and the maximum cooldown is always seven days).
     */
    uint32[14] public cooldowns = [
        uint32(1 minutes),
        uint32(2 minutes),
        uint32(5 minutes),
        uint32(10 minutes),
        uint32(30 minutes),
        uint32(1 hours),
        uint32(2 hours),
        uint32(4 hours),
        uint32(8 hours),
        uint32(16 hours),
        uint32(1 days),
        uint32(2 days),
        uint32(4 days),
        uint32(7 days)
    ];

    // An approximation of currently how many seconds are in between blocks.
    uint256 public secondsPerBlock = 15;

    /*** STORAGE ***/

    /**  @dev An array containing the Kitty struct for all Kitties in existence. The ID
     * of each cat is actually an index into this array. Note that ID 0 is a negacat,
     *  the unKitty, the mythical beast that is the parent of all gen0 cats. A bizarre
     *  creature that is both matron and sire... to itself! Has an invalid genetic code.
     *  In other words, cat ID 0 is invalid... ;-)
     */
    Kitty[] internal kitties;

    /**  @dev A mapping from KittyIDs to an address that has been approved to use
     * this Kitty for siring via breedWith(). Each Kitty can only have one approved
     *  address for siring at any time. A zero value means no approval is outstanding.
     */
    mapping(uint256 => address) public sireAllowedToAddress;

    /** @dev The Birth event is fired whenever a new kitten comes into existence. This obviously
     *  includes any time a cat is created through the giveBirth method, but it is also called
     *  when a new gen0 cat is created.
     */
    event Birth(
        address owner,
        uint256 kittyId,
        uint256 matronId,
        uint256 sireId,
        uint256 genes
    );

    constructor(
        string memory name,
        string memory symbol,
        address accessControl
    ) NFTCore(name, symbol, accessControl) {}

    /**
     *@notice Any C-level can fix how many seconds per blocks are currently observed.
     *@dev only COO will be able to call
     *@param secs new seconds to be set
     **/
    function setSecondsPerBlock(uint256 secs) external onlyRole(COO_ROLE) {
        require(secs < cooldowns[0], "Less than first cooldown period");
        secondsPerBlock = secs;
    }

    /**
     *@dev An internal method that creates a new kitty and stores it. This
     *method doesn't do any checking and should only be called when the
     *input data is known to be valid. Will generate both a Birth event
     *and a Transfer event.
     *@param _matronId The kitty ID of the matron of this cat (zero for gen0)
     *@param _sireId The kitty ID of the sire of this cat (zero for gen0)
     *@param _generation The generation number of this cat, must be computed by caller.
     *@param _genes The kitty's genetic code.
     *@param _owner The inital owner of this cat, must be non-zero (except for the unKitty, ID 0)
     */
    function _createKitty(
        uint256 _matronId,
        uint256 _sireId,
        uint256 _generation,
        uint256 _genes,
        address _owner
    ) internal returns (uint256) {
        // These requires are not strictly necessary, our calling code should make
        // sure that these conditions are never broken. However! _createKitty() is already
        // an expensive call (for storage), and it doesn't hurt to be especially careful
        // to ensure our data structures are always valid.
        require(
            _matronId == uint256(uint32(_matronId)),
            "MatronId typecasting failed"
        );
        require(
            _sireId == uint256(uint32(_sireId)),
            "SironId typecasting failed"
        );
        require(
            _generation == uint256(uint16(_generation)),
            "Generation typecasting failed"
        );

        // New kitty starts with the same cooldown as parent gen/2
        uint16 cooldownIndex = uint16(_generation / 2);
        if (cooldownIndex > 13) {
            cooldownIndex = 13;
        }

        Kitty memory _kitty = Kitty({
            genes: _genes,
            birthTime: uint64(block.timestamp),
            cooldownEndBlock: 0,
            matronId: uint32(_matronId),
            sireId: uint32(_sireId),
            siringWithId: 0,
            cooldownIndex: cooldownIndex,
            generation: uint16(_generation)
        });
        kitties.push(_kitty);
        uint256 newKittenId = kitties.length - 1;

        // It's probably never going to happen, 4 billion cats is A LOT, but
        // let's just be 100% sure we never let this happen.
        require(
            newKittenId == uint256(uint32(newKittenId)),
            "Kitties limit exceeded"
        );

        // emit the birth event
        emit Birth(
            _owner,
            newKittenId,
            uint256(_kitty.matronId),
            uint256(_kitty.sireId),
            _kitty.genes
        );

        // This will assign ownership, and also emit the Transfer event as
        // per ERC721 draft
        _safeMint(_owner, newKittenId);

        return newKittenId;
    }
}
