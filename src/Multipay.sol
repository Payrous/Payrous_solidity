// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Multipay {
    address public owner;
    address public platformFeeRecipient;
    uint256 public lastIndex;
    uint256 public constant MAX_EMPLOYEES = 100;
    
    bool private initialized;

    error Unauthorized();
    error InvalidAmount();
    error InvalidLength();
    error InsufficientBalance();
    error EmployeeNotFound();
    error EmployeeAlreadyExist();
    error InvalidAddress();
    error ExceedsLimit();
    error MaxEmployee();
    error InvalidTime();
    error AlreadyInitialized();

    event ERC20Transfer(address indexed token, address indexed from, address indexed to, uint256 amount);
    event NativeTransfer(address indexed from, address indexed to, uint256 amount);

    struct OrganizationDetails {
        string organizationName;
        address organizationAddress;
        address tokenAddress;
        address[] employees;
        uint256[] amountToBePaid;
        uint256 paymentInterval;
        uint256 startTime;
        bool isPaymentActive;
    }

    OrganizationDetails organizationDetails;

    mapping(address => uint256) public employeeIndex;
    mapping(address => bool) public employeeExists;

    modifier onlyOwner() {
        require(msg.sender == owner, "!OWNER");
        _;
    }

    // Remove the constructor and replace with an initialize function
    function initialize(
        string memory _organizationName,
        address _owner,
        address _platformFeeRecipient
    ) external {
        if (initialized) {
            revert AlreadyInitialized();
        }
        owner = _owner;
        organizationDetails.organizationName = _organizationName;
        organizationDetails.organizationAddress = _owner;
        platformFeeRecipient = _platformFeeRecipient;
        initialized = true;
    }

    function setupPaymentMethod(address _tokenAddress, uint256 _paymentInterval, uint256 _startTime) public onlyOwner{
        if(_tokenAddress == address(0)){
            revert InvalidAddress();
        }
        if(_paymentInterval == 0){
            revert InvalidAmount();
        }
        if(_startTime < block.timestamp){
            revert InvalidTime();
        }

        organizationDetails.tokenAddress = _tokenAddress;
        organizationDetails.paymentInterval = _paymentInterval;
        organizationDetails.startTime = _startTime;
    }

    function addMultipleEmployees(address[] memory _employees, uint256[] memory _amounts) public onlyOwner{
        if(_employees.length >= MAX_EMPLOYEES){
            revert MaxEmployee();
        }
        if(_employees.length != _amounts.length){
            revert InvalidLength();
        }
        if(_employees.length >= 20){
            revert ExceedsLimit();
        }

        for(uint256 i; i < _employees.length; i++){
            if(_employees[i] == address(0) || employeeExists[_employees[i]]){
                revert InvalidAddress();
            }
            organizationDetails.employees.push(_employees[i]);
            organizationDetails.amountToBePaid.push(_amounts[i]);
            employeeIndex[_employees[i]] = lastIndex;
            employeeExists[_employees[i]] = true;
            lastIndex++;
     }

    }

    function addEmployee(address _employee, uint256 _amount) public onlyOwner{
        if(_employee == address(0)){
            revert InvalidAddress();
        }
        if(_amount == 0){
            revert InvalidAmount();
        }
        if(employeeExists[_employee]){
            revert EmployeeAlreadyExist();
        }

        organizationDetails.employees.push(_employee);
        organizationDetails.amountToBePaid.push(_amount);
        employeeIndex[_employee] = lastIndex;
        employeeExists[_employee] = true;
        lastIndex++;
    }

    function removeEmployee(address _employee) public onlyOwner{
        if(!employeeExists[_employee]){
            revert EmployeeNotFound();
        }
        uint256 _index = employeeIndex[_employee];
        organizationDetails.employees[_index] = organizationDetails.employees[organizationDetails.employees.length - 1];
        organizationDetails.amountToBePaid[_index] = organizationDetails.amountToBePaid[organizationDetails.amountToBePaid.length - 1];
        organizationDetails.employees.pop();
        organizationDetails.amountToBePaid.pop();
        employeeExists[_employee] = false;

    }


    function sendToEmployee( ) external payable { 
        // if(organizationDetails.isPaymentActive == false){
        //     revert InvalidTime();
        // }
        if(block.timestamp < organizationDetails.startTime){
            revert Unauthorized();
        }else{
            organizationDetails.startTime += organizationDetails.paymentInterval;
            organizationDetails.isPaymentActive = true;
        }


        if(organizationDetails.employees.length == 0){
            revert EmployeeNotFound();
        }
        uint256 _employeesLength = organizationDetails.employees.length;
        address[] memory _employees = organizationDetails.employees;
        uint256[] memory  _amounts = organizationDetails.amountToBePaid;

        if (organizationDetails.tokenAddress == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            for (uint256 i; i < _employeesLength; i++) {
            address recipient = _employees[i];
            payable(recipient).transfer(_amounts[i]);

            emit NativeTransfer(msg.sender, recipient, _amounts[i]);
            }
        } else {
            IERC20 token = IERC20(organizationDetails.tokenAddress);

            for (uint256 i; i < _employeesLength; i++) {
            address recipient = _employees[i];
            token.transfer( recipient, _amounts[i]);

            emit ERC20Transfer(organizationDetails.tokenAddress, msg.sender, recipient, _amounts[i]);
            }
        }
    }


   function publicSend(address[] calldata _recipients, uint256[] calldata _amounts, address _tokenAddress) external payable {
        if(_recipients.length != _amounts.length) {
            revert InvalidLength();
        }

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }
        
        uint256 platformFee = (totalAmount * 5) / 100; 

        if (_tokenAddress == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            // Amount check
            uint256 requiredAmount = totalAmount + platformFee;
            if (msg.value < requiredAmount) {
                revert InsufficientBalance();
            }

            // Transfer platform fee
            payable(platformFeeRecipient).transfer(platformFee);
            emit NativeTransfer(msg.sender, platformFeeRecipient, platformFee);

            // Transfer to recipients
            for (uint256 i = 0; i < _recipients.length; i++) {
                address recipient = _recipients[i];
                payable(recipient).transfer(_amounts[i]);
                emit NativeTransfer(msg.sender, recipient, _amounts[i]);
            }

            // Refund excess if any
            uint256 excess = msg.value - requiredAmount;
            if (excess > 0) {
                payable(msg.sender).transfer(excess);
            }
        } else {
            // ERC20 token transfer
            IERC20 token = IERC20(_tokenAddress);
            
            // Transfer platform fee
            token.transferFrom(msg.sender, platformFeeRecipient, platformFee);
            emit ERC20Transfer(_tokenAddress, msg.sender, platformFeeRecipient, platformFee);

            // Transfer to recipients
            for (uint256 i = 0; i < _recipients.length; i++) {
                address recipient = _recipients[i];
                token.transferFrom(msg.sender, recipient, _amounts[i]);
                emit ERC20Transfer(_tokenAddress, msg.sender, recipient, _amounts[i]);
            }
        }
    }

    function withrawLockfunds(address _tokenAddress) external onlyOwner{
        IERC20(_tokenAddress).transfer(owner, IERC20(_tokenAddress).balanceOf(address(this)));
    }

    function transferNativeFunds() external onlyOwner{
        payable(owner).transfer(address(this).balance);
    }


    function getOrganizationDetails() public view returns(OrganizationDetails memory){
        return organizationDetails;
    }

    function getEmployeeDetails(address _employee) public view returns(uint256, uint256, uint256){
        uint256 _index = employeeIndex[_employee];
        return (organizationDetails.amountToBePaid[_index], organizationDetails.startTime, organizationDetails.paymentInterval);
    }

    function getEmployeeCount() public view returns(uint256){
        return organizationDetails.employees.length;
    }

    function getEmployeeBalance(address _employee) public view returns(uint256){
        uint256 _index = employeeIndex[_employee];
        return organizationDetails.amountToBePaid[_index];
    }




}
