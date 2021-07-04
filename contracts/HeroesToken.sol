// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/finance/PaymentSplitter.sol';

contract HeroesToken is ERC721Enumerable, PaymentSplitter, Ownable
{
  uint256 private constant LEGENDARY_SEED_MASK = 0xffff_fffc;
  uint256 private constant OTHERS_SEED_MASK = 0xffff_fffb;
  uint32 private constant CHARACTER_MASK = 0x07f8;
  uint32 private constant CHARACTER_INVERSE_MASK = 0xffff_f807;
  uint32 private constant RARITY_MASK = 0x03;
  uint256 private seed;
  uint256 private nonce;

  // Over 9000 characters !
  uint32 public numberOfCharacters;

  // Maximum 256 generations
  uint8 public currentGeneration;
  uint256 public generationSaleStart = 1625335200;

  // Excluding legendary, there will be: common, uncommon, rare, epic types
  // There will be 1000 legendary heroes
  uint256 private constant RARITY = 4;
  uint256 private constant LEGENDARY = 1000;
  uint256 private legendaryCount;
  uint256 public nextTokenId;
  string public baseURI;

  // Supply limit for each rarity type for normal distribution
  uint256[RARITY] private raritySupplyLimit;
  uint256[RARITY] private rarityCurrentAmount;
  uint256[RARITY] private raritySupplyIncreaseAmount;

  // Two bundles at first
  // Each bundle holds character count
  uint8 internal constant MAX_BUNDLES = 5;
  uint8 internal BUNDLE = 2;
  uint8[MAX_BUNDLES] public bundles;
  uint256[MAX_BUNDLES] public prices;
  
  /**
   * Character data
   */
  struct Character
  {
    uint8 generation;
    uint8 rarity;
    uint256 randomNumber;
    bytes32 randomHash;
  }
  Character[] private characters;
  mapping(uint32 => bool) private seedExists;

  /// @dev Emitted when `tokens` are purchased by `purchaser`.
  event BundlePurchased(uint256 amount, address indexed purchaser, uint256[] tokens);
  /// @dev Emitted when a new bundle created.
  event BundleAdded(uint8 _bundle, uint8 _characterCount, uint256 _price);
  /// @dev Emitted when bundle price is changed.
  event BundlePriceChanged(uint8 _bundle, uint256 _price);
  /// @dev Emitted when base URI is changed.
  event BaseURIChanged(string _baseURI);
  /// @dev Emitted when a new legendary character is summoned.
  event LegendaryCharacterMinted(uint256 _token);
  /// @dev Emitted when a new generation is started.
  event NewGeneration(uint256 _newGeneration);
  
  // Modifier to check single/bundle character payment
  modifier costs(uint8 _bundle_type)
  {
    require(
      msg.value == prices[_bundle_type],
      "Invalid payment !"
    );
    _;
  }

  // Modifier to check bundle
  modifier bundleAvailable(uint8 _bundle_type)
  {
    require( 
      _bundle_type < BUNDLE,
      "Bundle type must be exist !"
    );
    _;
  }

  // Modifier to check rarity
  modifier rarityAvailable(uint8 _rarity)
  {
    require(
      _rarity < RARITY,
      "Rarity type must be exist !"
    );
    _;
  }

  /**
   * @dev 
   * @param payees payment receiving addresses
   * @param shares_ shares of addresses
   */
  constructor(address[] memory payees, uint256[] memory shares_)
  ERC721("HON - Heroes Token", "HRO")
  PaymentSplitter(payees, shares_)
  {
    raritySupplyIncreaseAmount[0] = raritySupplyLimit[0] = 100;
    raritySupplyIncreaseAmount[1] = raritySupplyLimit[1] = 80;
    raritySupplyIncreaseAmount[2] = raritySupplyLimit[2] = 40;
    raritySupplyIncreaseAmount[3] = raritySupplyLimit[3] = 20;

    bundles[0] = 1;
    bundles[1] = 5;
    prices[0] = 0.5 ether;
    prices[1] = 2.0 ether;
    
    // Initially 5 different character presets
    numberOfCharacters = 5;
  }

  /**
   * @dev bundle
   * @param _bundle_type bundle type identifier
   *   0 : single character
   *   1 : five characters
   */
  function purchaseBundle(uint8 _bundle_type)
  public
  payable
  bundleAvailable (_bundle_type)
  costs (_bundle_type)
  {
    require(block.timestamp >= generationSaleStart, "Sale has not started");
    uint8 character_count = bundles[_bundle_type];
    uint256[] memory tokens = new uint256[](character_count);
    for (uint8 i=0; i<character_count; ++i)
    {
      tokens[i] = newCharacter();
    }
    emit BundlePurchased(msg.value, _msgSender(), tokens);
  }

  /**
   * @dev Create a legendary character
   */
  function newLegendaryCharacter()
  private
  {
    require(legendaryCount < LEGENDARY, 'All legendary heroes have been summoned.');
    uint256 token_id = nextTokenId;
    bool is_found;
    uint32 random_seed;
    uint32 character;
    bytes32 rand;
    uint256 random_number;
    
    nextTokenId++;
    legendaryCount++;
    
    // Try for 5 times
    for (uint8 i=0; i<5; i++)
    {
        rand = generateRandomHash();
        random_number = uint256(rand);
        
        random_seed = uint32(random_number & LEGENDARY_SEED_MASK);
        character = ((random_seed & CHARACTER_MASK) >> 3) % numberOfCharacters;
        random_seed = random_seed & CHARACTER_INVERSE_MASK;
        random_seed = random_seed | (character << 3);
        
        if (seedExists[random_seed] == false)
        {
            is_found = true;
            break;
        }
    }
    // If cant found return error
    require(is_found == true, "Legendary one could not be summoned. Try another time.");
    seedExists[random_seed] = true;
    random_number &= (type(uint256).max - 0xffff_ffff);
    random_number |= uint256(random_seed);

    _safeMint(msg.sender, token_id);
    characters.push(Character({
      generation: currentGeneration,
      rarity: 4,
      randomNumber: random_number,
      randomHash: rand
    }));

    emit LegendaryCharacterMinted(token_id);
  }

  /**
   * @dev Create a character with random rarity
   */
  function newCharacter()
  private
  returns (uint256)
  {
    bool is_found;
    uint8 rarity;
    uint32 random_seed;
    uint32 character;
    bytes32 rand;
    uint256 random_number;
    
    uint256 token_id = nextTokenId;
    nextTokenId++;
    
    // If all rarity types are distributed, increase supply limit
    // Guarantee we have always enough quota
    increaseSupplyLimit();
    
    // Try to distribute evenly between the rarity types
    for (uint8 i=0; i<3; i++)
    {
        rand = generateRandomHash();
        random_number = uint256(rand);
        
        random_seed = uint32(random_number & OTHERS_SEED_MASK);
        rarity = uint8(random_seed & RARITY_MASK);
        character = ((random_seed & CHARACTER_MASK) >> 3) % numberOfCharacters;
        random_seed = random_seed & CHARACTER_INVERSE_MASK;
        random_seed = random_seed | (character << 3);
        
        // if the rarity type is not fully distributed
        // and seed does not exist
        if (rarityCurrentAmount[rarity] < raritySupplyLimit[rarity] && 
            seedExists[random_seed] == false)
        {
            is_found = true;
            break;
        }
    }
    
    // If we couldnt find the random number in 5 pass
    // Try sequential method
    if (is_found == false)
    {
        for (uint8 i=0; i<RARITY; i++)
        {
            // Check if rarity quota is full
            if (rarityCurrentAmount[0] ^ raritySupplyLimit[0] != 0)
            {
              rarity = 0;
              random_seed = random_seed & 0xff1f_ffff;
            }
            else if (rarityCurrentAmount[1] ^ raritySupplyLimit[1] != 0)
            {
              rarity = 1;
              random_seed = random_seed & 0xff3f_ffff;
            }
            else if (rarityCurrentAmount[2] ^ raritySupplyLimit[2] != 0)
            {
              rarity = 2;
              random_seed = random_seed & 0xff5f_ffff;
            }
            else if (rarityCurrentAmount[3] ^ raritySupplyLimit[3] != 0)
            {
              rarity = 3;
              random_seed = random_seed & 0xff7f_ffff;
            }
            
            // Check for duplicates
            if (seedExists[random_seed] == false)
            {
              break;
            }
            else
            {
              rand = generateRandomHash();
              random_number = uint256(rand);
              
              random_seed = uint32(random_number & OTHERS_SEED_MASK);
              character = ((random_seed & CHARACTER_MASK) >> 3) % numberOfCharacters;
              random_seed = random_seed & CHARACTER_INVERSE_MASK;
              random_seed = random_seed | (character << 3);
            }
        }
    }
    // Increase current rarity type amount
    rarityCurrentAmount[rarity] ++;
    
    // A new random_seed is found
    seedExists[random_seed] = true;
    random_number &= (type(uint256).max - 0xffff_ffff);
    random_number |= uint256(random_seed);

    _safeMint(msg.sender, token_id);

    characters.push(Character({
      generation: currentGeneration,
      rarity: rarity,
      randomNumber: random_number,
      randomHash: rand
    }));

    return token_id;
  }

  /**
   * @dev Get all tokens of specified owner address
   * Requires ERC721Enumerable extension
   */
  function tokensOfOwner(address _owner)
  public 
  view 
  returns (uint256[] memory)
  {
    uint256 token_count = balanceOf(_owner);

    if (token_count == 0) {
      return new uint256[](0);
    } 
    else {
      uint256[] memory result = new uint256[](token_count);
      for (uint256 i = 0; i < token_count; i++) {
        result[i] = tokenOfOwnerByIndex(_owner, i);
      }
      return result;
    }
  }

  /**
   * @dev Get character rarity and random number
   */
  function getCharacter(uint256 character_id)
  public view 
  returns (uint8 o_generation, uint8 o_rarity, uint256 o_randomNumber, bytes32 o_randomHash)
  {
    o_generation = characters[character_id].generation;
    o_rarity = characters[character_id].rarity;
    o_randomNumber = characters[character_id].randomNumber;
    o_randomHash = characters[character_id].randomHash;
  }
  
  /**
   * @dev Base URI for computing {tokenURI}.
   */
  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }

  /**
   * @dev Character generation helper methods
   */
  function generateRandomHash () private returns(bytes32)
  {
    nonce ++;
    bytes32 rand = keccak256(abi.encodePacked(
      nonce,
      seed,
      block.timestamp,
      tx.gasprice,
      msg.sender
    ));
    return rand;
  }

  // Increase supply limit when it is full
  // by the predefined increase amount
  function increaseSupplyLimit () private
  {
    uint256 supply_limit = raritySupplyLimit[0] + raritySupplyLimit[1] + raritySupplyLimit[2] + raritySupplyLimit[3] - 10;
    uint256 current_supply = rarityCurrentAmount[0] + rarityCurrentAmount[1] + rarityCurrentAmount[2] + rarityCurrentAmount[3];

    if (current_supply > supply_limit)
    {
      raritySupplyLimit[0] += raritySupplyIncreaseAmount[0];
      raritySupplyLimit[1] += raritySupplyIncreaseAmount[1];
      raritySupplyLimit[2] += raritySupplyIncreaseAmount[2];
      raritySupplyLimit[3] += raritySupplyIncreaseAmount[3];
    }
  }

  /**
   * Only Owner methods
   */
  // Add a new bundle
  function addBundle(uint8 characterCount, uint256 _price)
  public onlyOwner
  {
    require(_price > 0, "No free bundle as in free beer.");
    require(characterCount > 0, "Character count is required");
    require(characterCount <= 10, "Character count can be maximum 10");
    require(BUNDLE < MAX_BUNDLES, "Maximum 5 bundles allowed !");
    ++BUNDLE;

    bundles[BUNDLE-1] = characterCount;
    prices[BUNDLE-1] = _price;
    emit BundleAdded(BUNDLE-1, characterCount, _price);
  }
  
  /**
   * Set total number of characters
   */
  function setNumberOfCharacters(uint32 _numberOfCharacters)
  public onlyOwner
  {
    require(_numberOfCharacters > numberOfCharacters, "Up Only");
    numberOfCharacters = _numberOfCharacters;
  }

  // Change price of the existing bundle
  function changePriceBundle(uint8 _bundle, uint256 _price)
  public onlyOwner 
  bundleAvailable(_bundle)
  {
    require(_price > 0, "No free bundle as in free beer.");
    prices[_bundle] = _price;
    emit BundlePriceChanged(_bundle, _price);
  }
  
  // Create a legendary character
  function mintLegendary(uint256 numberOfNfts)
  public onlyOwner
  {
    require(numberOfNfts > 0, "numberOfNfts cannot be 0");
    for (uint i = 0; i < numberOfNfts; i++) {
      newLegendaryCharacter();
    }
  }

  // Set random character generation seed
  function setSeed(uint256 _seed)
  public onlyOwner
  {
    seed = _seed;
  }

  // Set the Base URI
  function setBaseURI(string memory uri)
  public onlyOwner
  {
    baseURI = uri;
    emit BaseURIChanged(baseURI);
  }

  // Set amount of characters of a rarity type minted each distribution
  function setRaritySupplyIncreaseAmount(uint8 _rarity, uint256 amount)
  public onlyOwner
  rarityAvailable(_rarity)
  {
    raritySupplyIncreaseAmount[_rarity] = amount;
  }

  // Generation UP only
  function incrementCurrentGeneration()
  public onlyOwner
  {
    currentGeneration ++;
    emit NewGeneration(currentGeneration);
  }

  // Set new generation's sale start timestamp
  function setGenerationSaleStart(uint256 _generationSaleStart)
  public onlyOwner
  {
    require(_generationSaleStart > generationSaleStart, "Invalid timestamp");
    generationSaleStart = _generationSaleStart;
  }
}