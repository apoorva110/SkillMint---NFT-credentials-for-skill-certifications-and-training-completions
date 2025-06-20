// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title SkillMint
 * @dev NFT-based skill certification and training completion system
 * @notice This contract allows authorized institutions to mint skill certificates as NFTs
 */
contract SkillMint is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIdCounter;
    
    // Mapping from institution address to authorization status
    mapping(address => bool) public authorizedInstitutions;
    
    // Mapping from token ID to skill certification data
    mapping(uint256 => SkillCertificate) public certificates;
    
    // Mapping from learner address to their certificate token IDs
    mapping(address => uint256[]) public learnerCertificates;
    
    struct SkillCertificate {
        string skillName;
        string institutionName;
        address learner;
        address issuingInstitution;
        uint256 issueDate;
        uint256 expiryDate;
        string credentialLevel; // "Beginner", "Intermediate", "Advanced", "Expert"
        bool isActive;
    }
    
    // Events
    event InstitutionAuthorized(address indexed institution, string institutionName);
    event InstitutionRevoked(address indexed institution);
    event CertificateMinted(
        uint256 indexed tokenId,
        address indexed learner,
        address indexed institution,
        string skillName
    );
    event CertificateRevoked(uint256 indexed tokenId, string reason);
    
    constructor(address initialOwner) ERC721("SkillMint", "SKILL") Ownable(initialOwner) {}
    
    /**
     * @dev Authorizes an institution to mint skill certificates
     * @param institution Address of the institution
     * @param institutionName Name of the institution
     * @notice Only contract owner can authorize institutions
     */
    function authorizeInstitution(address institution, string memory institutionName) 
        external 
        onlyOwner 
    {
        require(institution != address(0), "Invalid institution address");
        require(!authorizedInstitutions[institution], "Institution already authorized");
        
        authorizedInstitutions[institution] = true;
        emit InstitutionAuthorized(institution, institutionName);
    }
    
    /**
     * @dev Mints a new skill certificate NFT
     * @param learner Address of the learner receiving the certificate
     * @param skillName Name of the skill being certified
     * @param institutionName Name of the issuing institution
     * @param credentialLevel Level of the credential
     * @param validityPeriod Validity period in seconds from current time
     * @param tokenURI Metadata URI for the NFT
     * @return tokenId The ID of the newly minted certificate
     */
    function mintCertificate(
        address learner,
        string memory skillName,
        string memory institutionName,
        string memory credentialLevel,
        uint256 validityPeriod,
        string memory tokenURI
    ) external returns (uint256) {
        require(authorizedInstitutions[msg.sender], "Not an authorized institution");
        require(learner != address(0), "Invalid learner address");
        require(bytes(skillName).length > 0, "Skill name cannot be empty");
        require(validityPeriod > 0, "Validity period must be greater than 0");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        uint256 currentTime = block.timestamp;
        uint256 expiryDate = currentTime + validityPeriod;
        
        // Create certificate data
        certificates[tokenId] = SkillCertificate({
            skillName: skillName,
            institutionName: institutionName,
            learner: learner,
            issuingInstitution: msg.sender,
            issueDate: currentTime,
            expiryDate: expiryDate,
            credentialLevel: credentialLevel,
            isActive: true
        });
        
        // Add to learner's certificate list
        learnerCertificates[learner].push(tokenId);
        
        // Mint the NFT
        _safeMint(learner, tokenId);
        _setTokenURI(tokenId, tokenURI);
        
        emit CertificateMinted(tokenId, learner, msg.sender, skillName);
        
        return tokenId;
    }
    
    /**
     * @dev Verifies if a certificate is valid and active
     * @param tokenId ID of the certificate to verify
     * @return isValid Whether the certificate is valid
     * @return certificate The certificate data
     */
    function verifyCertificate(uint256 tokenId) 
        external 
        view 
        returns (bool isValid, SkillCertificate memory certificate) 
    {
        require(_exists(tokenId), "Certificate does not exist");
        
        certificate = certificates[tokenId];
        isValid = certificate.isActive && 
                 block.timestamp <= certificate.expiryDate &&
                 authorizedInstitutions[certificate.issuingInstitution];
        
        return (isValid, certificate);
    }
    
    /**
     * @dev Revokes a certificate (marks as inactive)
     * @param tokenId ID of the certificate to revoke
     * @param reason Reason for revocation
     */
    function revokeCertificate(uint256 tokenId, string memory reason) external {
        require(_exists(tokenId), "Certificate does not exist");
        SkillCertificate storage cert = certificates[tokenId];
        require(
            msg.sender == cert.issuingInstitution || msg.sender == owner(),
            "Not authorized to revoke this certificate"
        );
        require(cert.isActive, "Certificate already revoked");
        
        cert.isActive = false;
        emit CertificateRevoked(tokenId, reason);
    }
    
    /**
     * @dev Gets all certificate IDs owned by a learner
     * @param learner Address of the learner
     * @return Array of certificate token IDs
     */
    function getLearnerCertificates(address learner) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return learnerCertificates[learner];
    }
    
    /**
     * @dev Revokes authorization for an institution
     * @param institution Address of the institution to revoke
     */
    function revokeInstitution(address institution) external onlyOwner {
        require(authorizedInstitutions[institution], "Institution not authorized");
        authorizedInstitutions[institution] = false;
        emit InstitutionRevoked(institution);
    }
    
    /**
     * @dev Checks if a certificate is expired
     * @param tokenId ID of the certificate
     * @return Whether the certificate is expired
     */
    function isCertificateExpired(uint256 tokenId) external view returns (bool) {
        require(_exists(tokenId), "Certificate does not exist");
        return block.timestamp > certificates[tokenId].expiryDate;
    }
    
    // Override required functions
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
