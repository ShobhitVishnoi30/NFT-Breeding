// SPDX-License-Identifier:UNLICENSED
pragma solidity 0.8.16;

import "./NFTBase.sol";
import "./Interfaces/NFTBreedingInterface.sol";
import "./Interfaces/GeneScienceInterface.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract NFTBreeding is NFTBase, NFTBreedingInterface, Pausable {
    /** @notice The minimum payment required to use breed(). This fee goes towards
     * the gas cost paid by whatever calls giveBirth(), and can be dynamically updated by
     * the COO role as the gas price changes.
     */
    uint256 public autoBirthFee = 2 gwei;

    // Keeps track of number of pregnant kitties.
    uint256 public pregnantKitties;

    /** @dev The address of the sibling contract that is used to implement the sooper-sekret
     * genetic combination algorithm.
     */
    GeneScienceInterface public geneScience;

    /** @dev The Pregnant event is fired when two cats successfully breed and the pregnancy
     *  timer begins for the matron.
     */
    event Pregnant(
        address owner,
        uint256 matronId,
        uint256 sireId,
        uint256 cooldownEndBlock
    );

    constructor(
        string memory name,
        string memory symbol,
        address accessControl
    ) NFTBase(name, symbol, accessControl) {}

    /**
     *@dev used to pause the contract.can only be called by CEO
     */
    function pauseContract() external whenNotPaused onlyRole(CEO_ROLE) {
        _pause();
    }

    /**
     *@dev used to unpause the contract.can only be called by CEO
     */
    function unpauseContract() external whenPaused onlyRole(CEO_ROLE) {
        _unpause();
    }

    /**
     *@dev Update the address of the genetic contract, can only be called by the CEO.
     *@param geneScienceAddress An address of a GeneScience contract instance to be used from this point forward.
     */
    function setGeneScienceAddress(address geneScienceAddress)
        external
        onlyRole(CEO_ROLE)
    {
        GeneScienceInterface candidateContract = GeneScienceInterface(
            geneScienceAddress
        );

        // NOTE: verify that a contract is what we expect - https://github.com/Lunyr/crowdsale-contracts/blob/cfadd15986c30521d8ba7d5b6f57b4fefcc7ac38/contracts/LunyrToken.sol#L117
        require(candidateContract.isGeneScience(), "wrong contract");

        // Set the new contract address
        geneScience = candidateContract;
    }

    /** @dev Updates the minimum payment required for calling giveBirthAuto(). Can only
     * be called by the COO address. (This fee is used to offset the gas cost incurred
     * by the autobirth daemon).
     *@param val new fees amount
     */
    function setAutoBirthFee(uint256 val) external onlyRole(CEO_ROLE) {
        autoBirthFee = val;
    }

    /** @dev Grants approval to another user to sire with one of your Kitties.
     *@param addr The address that will be able to sire with your Kitty. Set to
     * address(0) to clear all siring approvals for this Kitty.
     *@param sireId A Kitty that you own that _addr will now be able to sire with.
     */
    function approveForBreeding(address addr, uint256 sireId)
        external
        override
        whenNotPaused
    {
        require(ownerOf(sireId) == msg.sender, "Not your kitty");
        sireAllowedToAddress[sireId] = addr;
    }

    /** @dev Breed a Kitty you own (as matron) with a sire that you own, or for which you
     * have previously been given Siring approval. Will either make your cat pregnant, or will
     * fail entirely. Requires a pre-payment of the fee given out to the first caller of giveBirth()
     *@param _matronId The ID of the Kitty acting as matron (will end up pregnant if successful)
     *@param _sireId The ID of the Kitty acting as sire (will begin its siring cooldown if successful)
     */
    function breed(uint256 _matronId, uint256 _sireId)
        external
        payable
        override
        whenNotPaused
    {
        // Checks for payment.
        require(msg.value >= autoBirthFee, "not enough payment");

        // Caller must own the matron.
        require(ownerOf(_matronId) == msg.sender, "not owner");

        // Neither sire nor matron are allowed to be on auction during a normal
        // breeding operation, but we don't need to check that explicitly.
        // For matron: The caller of this function can't be the owner of the matron
        //   because the owner of a Kitty on auction is the auction house, and the
        //   auction house will never call breedWith().
        // For sire: Similarly, a sire on auction will be owned by the auction house
        //   and the act of transferring ownership will have cleared any oustanding
        //   siring approval.
        // Thus we don't need to spend gas explicitly checking to see if either cat
        // is on auction.

        // Check that matron and sire are both owned by caller, or that the sire
        // has given siring permission to caller (i.e. matron's owner).
        // Will fail for _sireId = 0
        require(
            _isBreedingPermitted(_sireId, _matronId),
            "breeding not permitted"
        );

        // Grab a reference to the potential matron
        Kitty storage matron = kitties[_matronId];

        // Make sure matron isn't pregnant, or in the middle of a siring cooldown
        require(_isAvailableForBreeding(matron), "matron is not available");

        // Grab a reference to the potential sire
        Kitty storage sire = kitties[_sireId];

        // Make sure sire isn't pregnant, or in the middle of a siring cooldown
        require(_isAvailableForBreeding(sire), "sire not available");

        // Test that these cats are a valid mating pair.
        require(
            _isValidBreedingPair(matron, _matronId, sire, _sireId),
            "Not valid mating pair"
        );

        // All checks passed, kitty gets pregnant!
        _breedWith(_matronId, _sireId);
    }

    /** @notice Have a pregnant Kitty give birth!
     *@dev Looks at a given Kitty and, if pregnant and if the gestation period has passed,
     *combines the genes of the two parents to create a new kitten. The new Kitty is assigned
     *to the current owner of the matron. Upon successful completion, both the matron and the
     *new kitten will be ready to breed again. Note that anyone can call this function (if they
     *are willing to pay the gas!), but the new kitten always goes to the mother's owner.
     *@param _matronId A Kitty ready to give birth.
     *@return The Kitty ID of the new kitten.
     */
    function giveBirth(uint256 _matronId)
        external
        whenNotPaused
        returns (uint256)
    {
        // Grab a reference to the matron in storage.
        Kitty storage matron = kitties[_matronId];

        // Check that the matron is a valid cat.
        require(matron.birthTime != 0, "not valid cat");

        // Check that the matron is pregnant, and that its time has come!
        require(_isReadyToGiveBirth(matron), "not ready to give birth");

        // Grab a reference to the sire in storage.
        uint256 sireId = matron.siringWithId;
        Kitty storage sire = kitties[sireId];

        // Determine the higher generation number of the two parents
        uint16 parentGen = matron.generation;
        if (sire.generation > matron.generation) {
            parentGen = sire.generation;
        }

        // Call the sooper-sekret gene mixing operation.
        uint256 childGenes = geneScience.mixGenes(
            matron.genes,
            sire.genes,
            matron.cooldownEndBlock - 1
        );

        // Make the new kitten!
        address owner = ownerOf(_matronId);
        uint256 kittenId = _createKitty(
            _matronId,
            matron.siringWithId,
            parentGen + 1,
            childGenes,
            owner
        );

        // Clear the reference to sire from the matron (REQUIRED! Having siringWithId
        // set is what marks a matron as being pregnant.)
        delete matron.siringWithId;

        // Every time a kitty gives birth counter is decremented.
        pregnantKitties--;

        // Send the balance fee to the person who made birth happen.
        payable(msg.sender).transfer(autoBirthFee);

        // return the new kitten's ID
        return kittenId;
    }

    /** @notice Checks that a given kitten is able to breed (i.e. it is not pregnant or
     * in the middle of a siring cooldown).
     *@param kittyId reference the id of the kitten, any user can inquire about it
     *@return bool true if kitty is available for breeding
     */
    function isAvailableForBreeding(uint256 kittyId)
        external
        view
        override
        returns (bool)
    {
        require(kittyId > 0, "Invalid id");
        Kitty storage kit = kitties[kittyId];
        return _isAvailableForBreeding(kit);
    }

    /**@dev checks if the two kitties are valid breeding pairs or not
     *@param matronId id of the matron
     *@param sireId   id of the sire
     *@return bool return boolean
     */
    function isValidBreedingPair(uint256 matronId, uint256 sireId)
        external
        view
        override
        returns (bool)
    {
        Kitty storage matron = kitties[matronId];
        Kitty storage sire = kitties[sireId];

        return _isValidBreedingPair(matron, matronId, sire, sireId);
    }

    /**@dev checks if the two kitties have permission to breed or not
     *@param matronId id of the matron
     *@param sireId   id of the sire
     *@return bool return boolean
     */
    function isBreedingPermitted(uint256 sireId, uint256 matronId)
        external
        view
        override
        returns (bool)
    {
        return _isBreedingPermitted(sireId, matronId);
    }

    /**@notice Checks to see if two cats can breed together, including checks for
     *ownership and siring approvals. Does NOT check that both cats are ready for
     *breeding (i.e. breedWith could still fail until the cooldowns are finished).
     *TODO: Shouldn't this check pregnancy and cooldowns?!?
     *@param matronId The ID of the proposed matron.
     *@param sireId The ID of the proposed sire.
     *@return bool return true if cats can breed otherwise false
     */
    function canBreed(uint256 matronId, uint256 sireId)
        external
        view
        override
        returns (bool)
    {
        require(matronId > 0, "Invalid matron");
        require(sireId > 0, "Invalid sire");
        Kitty storage matron = kitties[matronId];
        Kitty storage sire = kitties[sireId];
        return
            _isValidBreedingPair(matron, matronId, sire, sireId) &&
            _isBreedingPermitted(sireId, matronId);
    }

    /** @dev Check if a sire has authorized breeding with this matron. true if the sire has given siring permission to
     * the matron's owner (via approveSiring()).
     *@param user user address to whom permission is given
     *@param tokenId cat id
     *@return bool true if the user is approved to use cat
     */
    function isApprovedForBreeding(address user, uint256 tokenId)
        external
        view
        override
        returns (bool)
    {
        // Siring is okay if they have same owner, or if the matron's owner was given
        // permission to breed with this sire.
        return sireAllowedToAddress[tokenId] == user;
    }

    /** @dev Checks whether a kitty is currently pregnant.
     *@param kittyId reference the id of the kitten, any user can inquire about it
     *@return bool true if the kitty is pregnant
     */
    function isPregnant(uint256 kittyId) external view returns (bool) {
        require(kittyId > 0, "Invalid kittyId");
        // A kitty is pregnant if and only if this field is set
        return kitties[kittyId].siringWithId != 0;
    }

    /** @dev Internal utility function to initiate breeding, assumes that all breeding
     * requirements have been checked.
     *@param _matronId matron id
     *@param _sireId sire Id
     */
    function _breedWith(uint256 _matronId, uint256 _sireId) internal {
        // Grab a reference to the Kitties from storage.
        Kitty storage sire = kitties[_sireId];
        Kitty storage matron = kitties[_matronId];

        // Mark the matron as pregnant, keeping track of who the sire is.
        matron.siringWithId = uint32(_sireId);

        // Trigger the cooldown for both parents.
        _triggerCooldown(sire);
        _triggerCooldown(matron);

        // Clear siring permission for both parents. This may not be strictly necessary
        // but it's likely to avoid confusion!
        delete sireAllowedToAddress[_matronId];
        delete sireAllowedToAddress[_sireId];

        // Every time a kitty gets pregnant, counter is incremented.
        pregnantKitties++;

        // Emit the pregnancy event.
        emit Pregnant(
            ownerOf(_matronId),
            _matronId,
            _sireId,
            matron.cooldownEndBlock
        );
    }

    /**@dev Set the cooldownEndTime for the given Kitty, based on its current cooldownIndex.
     *Also increments the cooldownIndex (unless it has hit the cap).
     *@param _kitten A reference to the Kitty in storage which needs its timer started.
     */
    function _triggerCooldown(Kitty storage _kitten) internal {
        // Compute an estimation of the cooldown time in blocks (based on current cooldownIndex).
        _kitten.cooldownEndBlock = uint64(
            (cooldowns[_kitten.cooldownIndex] / secondsPerBlock) + block.number
        );

        // Increment the breeding count, clamping it at 13, which is the length of the
        // cooldowns array. We could check the array size dynamically, but hard-coding
        // this as a constant saves gas. Yay, Solidity!
        if (_kitten.cooldownIndex < 13) {
            _kitten.cooldownIndex += 1;
        }
    }

    /**@dev Checks that a given kitten is able to breed. Requires that the
     *current cooldown is finished (for sires) and also checks that there is
     *no pending pregnancy.
     *@param _kit all the details of the kitty
     *@return bool true if kitty is available to breed
     */
    function _isAvailableForBreeding(Kitty memory _kit)
        internal
        view
        returns (bool)
    {
        // In addition to checking the cooldownEndBlock, we also need to check to see if
        // the cat has a pending birth; there can be some period of time between the end
        // of the pregnacy timer and the birth event.
        return
            (_kit.siringWithId == 0) &&
            (_kit.cooldownEndBlock <= uint64(block.number));
    }

    /**@dev Check if a sire has authorized breeding with this matron. True if both sire
     *and matron have the same owner, or if the sire has given siring permission to
     *the matron's owner (via approveSiring()).
     *@param _sireId sire id
     *@param _matronId matron id
     *@return bool true if breeding is permitted
     */
    function _isBreedingPermitted(uint256 _sireId, uint256 _matronId)
        internal
        view
        returns (bool)
    {
        address matronOwner = ownerOf(_matronId);
        address sireOwner = ownerOf(_sireId);

        // Siring is okay if they have same owner, or if the matron's owner was given
        // permission to breed with this sire.
        return (matronOwner == sireOwner ||
            sireAllowedToAddress[_sireId] == matronOwner);
    }

    /**@dev Internal check to see if a given sire and matron are a valid mating pair. DOES NOT
     *check ownership permissions (that is up to the caller).
     *@param _matron A reference to the Kitty struct of the potential matron.
     *@param _matronId The matron's ID.
     *@param _sire A reference to the Kitty struct of the potential sire.
     *@param _sireId The sire's ID
     *@return bool true if the breeding pairs are valid
     */
    function _isValidBreedingPair(
        Kitty storage _matron,
        uint256 _matronId,
        Kitty storage _sire,
        uint256 _sireId
    ) private view returns (bool) {
        // A Kitty can't breed with itself!
        if (_matronId == _sireId) {
            return false;
        }

        // Kitties can't breed with their parents.
        if (_matron.matronId == _sireId || _matron.sireId == _sireId) {
            return false;
        }
        if (_sire.matronId == _matronId || _sire.sireId == _matronId) {
            return false;
        }

        // We can short circuit the sibling check (below) if either cat is
        // gen zero (has a matron ID of zero).
        if (_sire.matronId == 0 || _matron.matronId == 0) {
            return true;
        }

        // Kitties can't breed with full or half siblings.
        if (
            _sire.matronId == _matron.matronId ||
            _sire.matronId == _matron.sireId
        ) {
            return false;
        }
        if (
            _sire.sireId == _matron.matronId || _sire.sireId == _matron.sireId
        ) {
            return false;
        }

        // Everything seems cool! Let's get DTF.
        return true;
    }

    /**@dev Checks to see if a given Kitty is pregnant and (if so) if the gestation
     * period has passed.
     *@param _matron matron information
     *@return bool of matron is ready to give birth
     */
    function _isReadyToGiveBirth(Kitty memory _matron)
        private
        view
        returns (bool)
    {
        return
            (_matron.siringWithId != 0) &&
            (_matron.cooldownEndBlock <= uint64(block.number));
    }
}
