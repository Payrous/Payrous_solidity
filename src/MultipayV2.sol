// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//A contract to handle the payment of multiple employees
// A factory contract will be used to deploy this contract for an organization or client
// upon deployment, the organization will add tye organization name to the constructor
// after deployment, the organization will add the parties to the contract
// the organization will then add the amount to be paid to each party
// the organization will then call the payParties function to pay the parties 
// organization can create an automated system for payment of parties by setting date for payment, we can use chainliink to trigger the payment when the date is due


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract MultipayV2{

    address owner;
    string public organizationName;
    uint256 public lastIndex;

    error Unauthorized();
    error InvalidAmount();
    error InvalidLength();
    error InsufficientBalance();
    error EmployeeNotFound();
    error EmployeeAlreadyExist();
    error InvalidAddress();
    error ExceedsLimit();


    event ERC20Transfer(address indexed token, address indexed from, address indexed to, uint256 amount);
    event NativeTransfer(address indexed from, address indexed to, uint256 amount);


    struct OrganizationDetails{
        string organizationName;
        address organizationAddress;
        address tokenAddress;
        address[] employees;
        uint256[] amountToBePaid;
        uint256 paymentInterval;
        uint256 startTime;
        bool isPaymentActive;
    }

    struct EmployeeDetails{
        address employee;
        uint256 amountToBePaid;
        uint256 lastPaymentDate;
        uint256 nextPaymentDate;
        uint256 totalAmountPaid;
    }

    OrganizationDetails organizationDetails;
    EmployeeDetails[] employeeDetails;

    mapping(address => uint256) public amountPaid;
    mapping(address => uint256) public employeeIndex;
    mapping(address => bool) public employeeExists;


    modifier onlyOwner(){
        require(msg.sender == owner, "!OWNER");
        _;
    }

    constructor(string memory _organizationName){
        owner = msg.sender;
        organizationDetails.organizationName = _organizationName;
        organizationDetails.organizationAddress = msg.sender;
    }

    function setupPaymentMethod(address _tokenAddress, uint256 _paymentInterval, uint256 _startTime) public onlyOwner{
        organizationDetails.tokenAddress = _tokenAddress;
        organizationDetails.paymentInterval = _paymentInterval;
        organizationDetails.startTime = _startTime;
    }

    function addMultipleEmployees(address[] memory _employees, uint256[] memory _amounts) public onlyOwner{
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
            employeeExists[_employees[i]] = true;
            employeeIndex[_employees[i]] = lastIndex;

            EmployeeDetails memory employee;
            employee.employee = _employees[i];
            employee.amountToBePaid = _amounts[i];
            employeeDetails.push(employee);

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

        organizationDetails.employees.push(_employee);
        organizationDetails.amountToBePaid.push(_amount);
        employeeExists[_employee] = true;
        employeeIndex[_employee] = lastIndex;

        EmployeeDetails memory employee;
        employee.employee = _employee;
        employee.amountToBePaid = _amount;
        employeeDetails.push(employee);
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
        if(organizationDetails.isPaymentActive == false){
            revert Unauthorized();
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

            EmployeeDetails storage employee = employeeDetails[i];
            employee.totalAmountPaid += _amounts[i];
            employee.lastPaymentDate = block.timestamp;
            employee.nextPaymentDate = block.timestamp + organizationDetails.paymentInterval;
            payable(recipient).transfer(_amounts[i]);
    
            emit NativeTransfer(msg.sender, recipient, _amounts[i]);
            return;
            }
        } else {
            IERC20 token = IERC20(organizationDetails.tokenAddress);

            for (uint256 i; i < _employeesLength; i++) {
            address recipient = _employees[i];

            EmployeeDetails storage employee = employeeDetails[i];
            employee.totalAmountPaid += _amounts[i];
            employee.lastPaymentDate = block.timestamp;
            employee.nextPaymentDate = block.timestamp + organizationDetails.paymentInterval;
        
            token.transferFrom(address(this), recipient, _amounts[i]);

            emit ERC20Transfer(organizationDetails.tokenAddress, msg.sender, recipient, _amounts[i]);
            }
        }
    }


    function batchSend( address[] calldata _recipeints, uint256[] calldata _amounts, address _tokenAddress) external payable {
        if(_recipeints.length != _amounts.length) {
            revert InvalidLength();
        }

        if (_tokenAddress == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            for (uint256 i; i < _recipeints.length; i++) {
            address recipient = _recipeints[i];
            payable(recipient).transfer(_amounts[i]);

            emit NativeTransfer(msg.sender, recipient, _amounts[i]);
            }
        } else {
            IERC20 token = IERC20(_tokenAddress);

            for (uint256 i = 0; i < _recipeints.length; i++) {
            address recipient = _recipeints[i];
            token.transferFrom(msg.sender, recipient, _amounts[i]);

            emit ERC20Transfer(_tokenAddress, msg.sender, recipient, _amounts[i]);
            }
        }
    }



    function getOrganizationDetails() public view returns(OrganizationDetails memory){
        return organizationDetails;
    }

    function getEmployeeDetails(address _employee) public view returns(EmployeeDetails memory){
        if(!employeeExists[_employee]){
            revert EmployeeNotFound();
        }
        uint256 _index = employeeIndex[_employee];
        return employeeDetails[_index];

    }


}
