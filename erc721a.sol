// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Billionaire is Ownable, PaymentSplitter, ERC721A("WooB", "WB") {
  //To concatenate the URL of an NFT
  using Strings for uint256;

  //To check the addresses in the whitelist
  bytes32 public merkleRoot;

  //Id of the next NFT to mint

  //Number of NFTs in the collection
  uint256 public constant MAX_SUPPLY = 10;
  //Maximum number of NFTs an address can mint
  uint256 public max_mint_allowed_presale = 3;
  uint256 public max_mint_allowed_public = 2;

  //Price of one NFT in presale
  uint256 public pricePresale = 0.00025 ether;
  //Price of one NFT in sale
  uint256 public priceSale = 0.0003 ether;
  //URI of the NFTs when revealed
  string public baseURI;
  //URI of the NFTs when not revealed
  string public notRevealedURI;
  //The extension of the file containing the Metadatas of the NFTs
  string public baseExtension = ".json";

  //Are the NFTs revealed yet ?
  bool public revealed = false;

  //Is the contract paused ?
  bool public paused = false;

  //The different stages of selling the collection
  enum Steps {
    Before,
    Presale,
    Sale,
    SoldOut
  }

  Steps public sellingStep;

  //Owner of the smart contract
  address private _owner;

  //Keep a track of the number of tokens per address
  mapping(address => uint256) nftsPerWallet;
  mapping(address => uint256) nftsPerWalletSale;

  //Addresses of all the members of the team
  address[] private _team = [
    0xd62Ae55B25d19ff0fD289AAF7bdaDcb3b51F446b,
    0x896e244EB6D3f38D112b28EB024191bB6EfEaA76
  ];

  //Shares of all the members of the team
  uint256[] private _teamShares = [80, 20];

  //Constructor of the collection
  constructor(
    string memory _theBaseURI,
    string memory _notRevealedURI,
    bytes32 _merkleRoot
  ) PaymentSplitter(_team, _teamShares) {
    transferOwnership(msg.sender);
    sellingStep = Steps.Presale;
    baseURI = _theBaseURI;
    notRevealedURI = _notRevealedURI;
    merkleRoot = _merkleRoot;
    _safeMint(msg.sender, 1); 
  }

  /**
   * @notice Edit the Merkle Root
   *
   * @param _newMerkleRoot The new Merkle Root
   **/
  function changeMerkleRoot(bytes32 _newMerkleRoot) external onlyOwner {
    merkleRoot = _newMerkleRoot;
  }

  /**
   * @notice Set pause to true or false
   *
   * @param _paused True or false if you want the contract to be paused or not
   **/
  function setPaused(bool _paused) external onlyOwner {
    paused = _paused;
  }

  /**
   * @notice Change the number of NFTs that an address can mint
   *
   * @param _maxMintAllowed The number of NFTs that an address can mint
   **/
  function changeMaxMintAllowedPresale(uint256 _maxMintAllowed)
    external
    onlyOwner
  {
    max_mint_allowed_presale = _maxMintAllowed;
  }

  function changeMaxMintAllowedPublicSale(uint256 _maxMintAllowed)
    external
    onlyOwner
  {
    max_mint_allowed_public = _maxMintAllowed;
  }

  /**
   * @notice Change the price of one NFT for the presale
   *
   * @param _pricePresale The new price of one NFT for the presale
   **/
  function changePricePresale(uint256 _pricePresale) external onlyOwner {
    pricePresale = _pricePresale;
  }

  /**
   * @notice Change the price of one NFT for the sale
   *
   * @param _priceSale The new price of one NFT for the sale
   **/
  function changePriceSale(uint256 _priceSale) external onlyOwner {
    priceSale = _priceSale;
  }

  /**
   * @notice Change the base URI
   *
   * @param _newBaseURI The new base URI
   **/
  function setBaseUri(string memory _newBaseURI) external onlyOwner {
    baseURI = _newBaseURI;
  }

  /**
   * @notice Change the not revealed URI
   *
   * @param _notRevealedURI The new not revealed URI
   **/
  function setNotRevealURI(string memory _notRevealedURI) external onlyOwner {
    notRevealedURI = _notRevealedURI;
  }

  /**
   * @notice Allows to set the revealed variable to true
   **/
  function reveal() external onlyOwner {
    revealed = true;
  }

  /**
   * @notice Return URI of the NFTs when revealed
   *
   * @return The URI of the NFTs when revealed
   **/
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  /**
   * @notice Allows to change the base extension of the metadatas files
   *
   * @param _baseExtension the new extension of the metadatas files
   **/
  function setBaseExtension(string memory _baseExtension) external onlyOwner {
    baseExtension = _baseExtension;
  }

  /**
   * @notice Allows to change the sellinStep to Presale
   **/
  function setUpPresale() external onlyOwner {
    sellingStep = Steps.Presale;
  }

  /**
   * @notice Allows to change the sellinStep to Sale
   **/
  function setUpSale() external onlyOwner {
    require(
      sellingStep == Steps.Presale,
      "Set up the presale first, then the sale."
    );
    sellingStep = Steps.Sale;
  }

  function presaleMint(bytes32[] calldata _proof, uint256 _ammount)
    external
    payable
  {
    //Is paused?
    require(paused == false, "Presale is Paused");
    //Are we in Presale ?
    require(sellingStep == Steps.Presale, "Presale has not started yet.");
    //Did this account already mint an NFT ?
    require(
      _ammount > 0 &&
        nftsPerWallet[msg.sender] + _ammount <= max_mint_allowed_presale,
      "You can only get many NFT's per Presale"
    );
    //Is this user on the whitelist ?
    require(isWhiteListed(msg.sender, _proof), "Not on the whitelist");
    uint256 numberNftSold = totalSupply();

    require(
      numberNftSold + _ammount <= MAX_SUPPLY,
      "Sale is almost done and we don't have enought NFTs left."
    );

    //Get the price of one NFT during the Presale
    uint256 price = pricePresale;
    //Did the user send enought Ethers ?
    require(msg.value >= price * _ammount, "Not enought funds.");

    // Increment the number of NFTs this user minted
    nftsPerWallet[msg.sender] += _ammount;
    //mint 1
    _safeMint(msg.sender, _ammount);
  }

  /**
   * @notice Allows to mint NFTs
   *
   * @param _ammount The ammount of NFTs the user wants to mint
   **/
  function saleMint(uint256 _ammount) external payable {
    //Get the number of NFT sold
    uint256 numberNftSold = totalSupply();
    //Get the price of one NFT in Sale
    uint256 price = priceSale;
    //If everything has been bought
    require(sellingStep != Steps.SoldOut, "Sorry, no NFTs left.");
    //If Sale didn't start yet

    require(sellingStep == Steps.Sale, "Sorry, sale has not started yet.");
    //Did the user then enought Ethers to buy ammount NFTs ? //FIX THIS
    require(msg.value >= price * _ammount, "Not enought funds.");
    require(paused == false, "Sale is Paused");
    require(
      _ammount > 0 &&
        nftsPerWalletSale[msg.sender] + _ammount <= max_mint_allowed_public,
      "You can only get many per Sale"
    );
    //If the user try to mint any non-existent token
    require(
      numberNftSold + _ammount <= MAX_SUPPLY,
      "Sale is almost done and we don't have enought NFTs left."
    );
    //Add the ammount of NFTs minted by the user to the total he minted
    nftsPerWalletSale[msg.sender] += _ammount;
    //If this account minted the last NFTs available
    if (numberNftSold + _ammount == MAX_SUPPLY) {
      sellingStep = Steps.SoldOut;
    }
    _safeMint(msg.sender, _ammount);
  }

  /**
   * @notice Allows to gift one NFT to an address
   *Make it so everyone muint a git not only the owner
   * @param _account The account of the happy new owner of one NFT
   **/
  function gift(address _account) external onlyOwner {
    uint256 supply = totalSupply();
    require(supply + 1 <= MAX_SUPPLY, "Sold out");
    _safeMint(_account, 1);
  }

  /**
   * @notice Return true or false if the account is whitelisted or not
   *
   * @param account The account of the user
   * @param proof The Merkle Proof
   *
   * @return true or false if the account is whitelisted or not
   **/
  function isWhiteListed(address account, bytes32[] calldata proof)
    internal
    view
    returns (bool)
  {
    return _verify(_leaf(account), proof);
  }

  /**
   * @notice Return the account hashed
   *
   * @param account The account to hash
   *
   * @return The account hashed
   **/
  function _leaf(address account) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(account));
  }

  /**
   * @notice Returns true if a leaf can be proved to be a part of a Merkle tree defined by root
   *
   * @param leaf The leaf
   * @param proof The Merkle Proof
   *
   * @return True if a leaf can be provded to be a part of a Merkle tree defined by root
   **/
  function _verify(bytes32 leaf, bytes32[] memory proof)
    internal
    view
    returns (bool)
  {
    return MerkleProof.verify(proof, merkleRoot, leaf);
  }

  function tokenURI(uint256 _nftId)
    public
    view
    override
    returns (string memory)
  {
    require(_exists(_nftId), "This NFT doesn't exist.");
    if (revealed == false) {
      return notRevealedURI;
    }

    string memory currentBaseURI = _baseURI();
    return
      bytes(currentBaseURI).length > 0
        ? string(
          abi.encodePacked(currentBaseURI, _nftId.toString(), baseExtension)
        )
        : "";
  }
}
