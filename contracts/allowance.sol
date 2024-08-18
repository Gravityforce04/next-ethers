// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract AllowanceClaim is AccessControl {
    // Define a constant for the reviewer role using a hashed string identifier
    bytes32 private constant REVIEWER_ROLE = keccak256("REVIEWER_ROLE");

    // Structure to store application data
    struct Application {
        address applicant;     // Address of the user who submitted the application
        string ic;              // Application data provided by the user (e.g., personal info)
        uint256 amount;         // Amount to claim
        bool verified   ;         // Boolean flag indicating if the application has been verified
        uint8 approvals;       // Number of approvals the application has received
        bool approved;         // Boolean flag indicating if the application has been approved
        bool rejected;         // Boolean flag indicating if the application has been rejected
        bool claimed;          // Boolean flag indicating if the allowance has been claimed
    }
    
    uint256 public applicationCount;              // Tracks the total number of applications submitted
    uint8 public requiredApprovals;               // The number of approvals required for an application to be approved
    mapping(uint256 => Application) public applications; // Mapping from application ID to Application struct (applications first application is starts from 1 instead of 0)
    mapping(uint256 => mapping(address => bool)) public approvals; // Nested mapping to track approvals by reviewers

    // Events to log significant actions within the contract
    event ApplicationSubmitted(uint256 applicationId, address applicant, uint256 amount);
    event ApplicationVerified(uint256 applicationId);
    event ApplicationSigned(uint256 applicationId, address signer);
    event ApplicationApproved(uint256 applicationId);
    event AllowanceClaimed(uint256 applicationId, address claimant, uint256 amount);
    event Funded(address indexed funder, uint256 amount);

    // Constructor to initialize the contract with the required number of approvals
    constructor(uint8 _requiredApprovals) {
        requiredApprovals = _requiredApprovals;

        // Assign the deployer the default admin role, which has permission to manage roles such as Reviewer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // Granting deployer reviewer role to ease testing 
        grantRole(REVIEWER_ROLE, msg.sender);
    }

    // Function to check contract balance
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // Function to fund the contract, only accessible by the owner (amount is in wei)
    function fundContract(uint256 amount) external payable onlyRole(DEFAULT_ADMIN_ROLE) {
        // To pay the contract msg.value needs to be set from the tab in remix
        require(amount > 0, "Amount must be greater than zero");
        require(msg.value > 0, "Must send Ether to fund");
        require(msg.value == amount, "Sent value does not match the specified amount");
        emit Funded(msg.sender, msg.value);
    }

    // Function to withdraw all funds in the contract and send to caller
    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(this).balance > 0, "No funds available");
        uint256 amount = address(this).balance;
        payable(msg.sender).transfer(amount);
    }

    // Check if an address has the reviewer role
    function isReviewer(address account) public view returns (bool) {
        return hasRole(REVIEWER_ROLE, account);
    }

    // Grant the reviewer role to a specific address
    function grantReviewerRole(address account) external {
        grantRole(REVIEWER_ROLE, account);
    }

    // Function for users to submit their application (amount is in wei)
    function submitApplication(string memory _ic, uint256 _amount) public returns (uint256) {
        applicationCount++; // Increment the application count

        // Create a new application and store it in the applications mapping
        applications[applicationCount] = Application({
            applicant: msg.sender,
            ic: _ic,
            amount: _amount, // amount is always in wei
            verified: false,
            approvals: 0,
            approved: false,
            rejected: false,
            claimed: false
        });

        // Emit an event to log the submission of the application
        emit ApplicationSubmitted(applicationCount, msg.sender, _amount);
        // Let the applicant know their application number
        return applicationCount;
    }

    // Function for reviewers to verify an application
    function verifyApplication(uint256 applicationId) public onlyRole(REVIEWER_ROLE) {
        applications[applicationId].verified = true; // Mark the application as verified (Verification lies on government body KYC)

        // Emit an event to log the verification of the application
        emit ApplicationVerified(applicationId);
    }

    // Function for reviewers to sign (approve) an application
    function signApplication(uint256 applicationId) public onlyRole(REVIEWER_ROLE) {
        // Ensure the application has been verified before it can be signed
        require(applications[applicationId].verified, "Application not verified yet");

        // Ensure the reviewer has not already signed this application
        require(!approvals[applicationId][msg.sender], "Already signed");
        
        // Mark this application as approved by the caller
        approvals[applicationId][msg.sender] = true;
        applications[applicationId].approvals++; // Increment the approval count
        
        // Emit an event to log the signing of the application
        emit ApplicationSigned(applicationId, msg.sender);

        // If the required number of approvals is reached, mark the application as approved
        if (applications[applicationId].approvals >= requiredApprovals) {
            applications[applicationId].approved = true;
            
            // Emit an event to log the approval of the application
            emit ApplicationApproved(applicationId);
        }
    }

    // Function for users to claim their allowance after approval
    function claimAllowance(uint256 applicationId) public {
        // Temp obtain application for ease of access
        Application memory application = applications[applicationId];
        // if true for require() condition code continues, if false error msg is thrown
        // Ensure only the one who submit the application can claim it
        require(application.applicant == msg.sender, "Only wallet that submitted the application can claim");

        // Ensure the application has been approved before claiming
        require(application.approved, "Application not approved");

        // Ensure the allowance has not already been claimed
        require(!application.claimed, "Allowance already claimed");

        
        // Implement payment logic here (e.g., transfer tokens to the applicant)
        // Check if contract have sufficient funds
        require(address(this).balance >= application.amount, "Insufficient funds");

        // Mark the allowance as claimed to prevent double claiming
        application.claimed = true;
        // Pay the person calling the function the amount
        payable(msg.sender).transfer(application.amount);
        // Emit an event to log the allowance claim
        emit AllowanceClaimed(applicationId, msg.sender, application.amount);
    }
}