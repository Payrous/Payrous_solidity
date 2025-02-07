// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


    // NOTE:--->     //pAy recipient individually 
    // NOTE:=--->    // check if it's posssibel to get all recurring payment details for all organizattion in one function call or not
    // hanlde backlisted address
    //@audit ----->

    // try catch continue to handle a revert in a loop so that other transactions are not affected
    // platform fee check ?
    // GRIEFING EFFECT: RECEIVE FUNCTION of the recipient might make unecessary calls that waste gas ang cause the transaction to block gas limit
    //and this will cause a revert in the contract. gas wsted and this function will not be able to work well.
    // simulate transaction on the frontend to check if the call is going to be succesful before making the actuall call.

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Multipay {
    address public owner;
    address public platformFeeRecipient;
    uint256 public lastIndex;
    uint256 public MAX_EMPLOYEES;
    uint256 public PLATFORM_FEE;
    
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
        uint256 endTime;
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
        address _tokenAddress,
        address _owner,
        address _platformFeeRecipient
    ) external {
        if (initialized) {
            revert AlreadyInitialized();
        }

        if(_tokenAddress == address(0)){
            revert InvalidAddress();
        }
        owner = _owner;
        organizationDetails.organizationName = _organizationName;
        organizationDetails.organizationAddress = _owner;
        organizationDetails.tokenAddress = _tokenAddress;
        platformFeeRecipient = _platformFeeRecipient;
        MAX_EMPLOYEES = 1500;
        PLATFORM_FEE = 5;

        initialized = true;
    }

    function setupReoccuringPayment(uint256 _paymentInterval, uint256 _startTime, uint256 _endtime) public onlyOwner{

        if(_paymentInterval == 0){
            revert InvalidAmount();
        }
        if(_startTime < block.timestamp){
            revert InvalidTime();
        }

        organizationDetails.paymentInterval = _paymentInterval;
        organizationDetails.startTime = _startTime;
        organizationDetails.endTime = _endtime;
    }

    function addMultipleEmployees(address[] memory _employees, uint256[] memory _amounts) public onlyOwner{
        if(_employees.length >= MAX_EMPLOYEES){
            revert MaxEmployee();
        }
        if(_employees.length != _amounts.length){
            revert InvalidLength();
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
            uint256 index = employeeIndex[_employee];
            organizationDetails.amountToBePaid[index] = _amount;
            return;
        }

        if(organizationDetails.employees.length + 1 > MAX_EMPLOYEES){
            revert MaxEmployee();
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

        // if endate is 0 then payment is indefinite else payment stops after enddate
        if(organizationDetails.endTime != 0 && block.timestamp >= organizationDetails.endTime){
            revert InvalidTime();
        }

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

        uint256 totalAmount;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }        
        uint256 platformFee = (totalAmount * PLATFORM_FEE) / 100; 
        require(platformFee > 0, "Invalid platform fee");

        if (_tokenAddress == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            // Amount check
            uint256 requiredAmount = totalAmount + platformFee;
            if (msg.value < requiredAmount) {
                revert InsufficientBalance();
            }

            // Transfer platform fee
            (bool success, ) = platformFeeRecipient.call{value: platformFee}("");
            require(success, "Transfer failed.");
            emit NativeTransfer(msg.sender, platformFeeRecipient, platformFee);

            // Transfer to recipients
            for (uint256 i = 0; i < _recipients.length; i++) {
                address recipient = _recipients[i];
                (bool _success, ) = recipient.call{value: _amounts[i]}("");
                require(_success, "Transfer failed.");
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

    function deposit(uint256 _amount) external payable {
        if(_amount == 0){
            revert InvalidAmount();
        }

        if (organizationDetails.tokenAddress == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            if (msg.value < _amount) {
                revert InsufficientBalance();
            }
        } else {
            IERC20 token = IERC20(organizationDetails.tokenAddress);
            token.transferFrom(msg.sender, address(this), _amount);
        }
    }

    function updatePaymentToken(address _tokenAddress) external onlyOwner{
        if(_tokenAddress == address(0)){
            revert InvalidAddress();
        }
        organizationDetails.tokenAddress = _tokenAddress;
    }

    function withrawLockedfunds(address _tokenAddress) external onlyOwner{
        IERC20(_tokenAddress).transfer(owner, IERC20(_tokenAddress).balanceOf(address(this)));
    }

    function updatePlatformFee(uint256 _platformFee) external onlyOwner{
        if(_platformFee < 0 || _platformFee > 10){
            revert InvalidAmount();
        }
        PLATFORM_FEE = _platformFee;
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

    function getAllEmployeeAddress() public view returns(address[] memory){
        return organizationDetails.employees;
    }

    function getEmployeeCount() public view returns(uint256){
        return organizationDetails.employees.length;
    }

    function getEmployeeBalance(address _employee) public view returns(uint256){
        uint256 _index = employeeIndex[_employee];
        return organizationDetails.amountToBePaid[_index];
    }

    function getContractBalance() public view returns(uint256){
        if(organizationDetails.tokenAddress == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE){
            return address(this).balance;
        }else{
            return IERC20(organizationDetails.tokenAddress).balanceOf(address(this));
        }
    }


}


