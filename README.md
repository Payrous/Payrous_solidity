# MultipayV2 Smart Contract Documentation

## Project Overview
MultipayV2 is a blockchain-based payroll management system implemented as a smart contract that enables organizations to efficiently handle payments to multiple employees using both native cryptocurrency and ERC20 tokens. The contract is designed to be deployed through a factory pattern, allowing each organization to have its own instance of the payment system.

## Key Benefits
1. **Automated Payments**: Organizations can set up automated recurring payments with customizable intervals
2. **Flexibility**: Supports both native cryptocurrency and ERC20 token payments
3. **Scalability**: Can handle multiple employees (up to 20 per contract)
4. **Transparency**: All payment transactions are recorded on the blockchain
5. **Employee Management**: Easy addition and removal of employees
6. **Payment Tracking**: Maintains detailed payment history for each employee

## Problems Solved
1. **Manual Payment Overhead**: Eliminates the need for manual processing of multiple individual transactions
2. **Payment Delays**: Automated scheduling ensures timely payments
3. **Record Keeping**: Automatic tracking of payment history and employee details
4. **Payment Verification**: Transparent verification of payments through blockchain
5. **Multi-Currency Support**: Flexibility to pay in different tokens without multiple systems

## Technical Features
- Automated payment scheduling
- Support for both native cryptocurrency and ERC20 tokens
- Employee management system
- Batch payment processing
- Detailed payment tracking and history
- Role-based access control
- Event logging for payments

## Contract Architecture

### Key Structures
1. **OrganizationDetails**
   - Organization name and address
   - Token address for payments
   - List of employees and payment amounts
   - Payment interval and timing settings

2. **EmployeeDetails**
   - Employee address
   - Payment amount
   - Payment history tracking
   - Next payment date

## User Workflow

### Organization Setup
1. Deploy contract with organization name
```solidity
constructor(string memory _organizationName)
```

2. Configure payment method
```solidity
function setupPaymentMethod(
    address _tokenAddress,
    uint256 _paymentInterval,
    uint256 _startTime
)
```

### Employee Management
1. Add single employee
```solidity
function addEmployee(address _employee, uint256 _amount)
```

2. Add multiple employees
```solidity
function addMultipleEmployees(
    address[] memory _employees,
    uint256[] memory _amounts
)
```

3. Remove employee
```solidity
function removeEmployee(address _employee)
```

### Payment Processing
1. Regular employee payments
```solidity
function sendToEmployee()
```

2. Batch payments (for one-time transactions)
```solidity
function batchSend(
    address[] calldata _recipients,
    uint256[] calldata _amounts,
    address _tokenAddress
)
```

## Implementation Guide

### 1. Initial Setup
1. Deploy the contract with organization name
2. Set up payment method by specifying:
   - Token address (use `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE` for native currency)
   - Payment interval (in seconds)
   - Start time (unix timestamp)

### 2. Employee Registration
1. Add employees individually or in batches
2. For each employee, specify:
   - Wallet address
   - Payment amount

### 3. Payment Execution
1. Ensure sufficient balance in contract
2. For ERC20 tokens, approve contract for token spending
3. Execute payments through `sendToEmployee()` function
4. Monitor events for payment confirmation

## Security Considerations
1. Only owner can modify employee details
2. Maximum limit of 20 employees per contract
3. Input validation for addresses and amounts
4. Checks for duplicate employee entries
5. Protection against zero-address entries

## Events
1. `ERC20Transfer`: Logs token transfer details
2. `NativeTransfer`: Logs native currency transfer details

## Error Handling
The contract includes custom errors for common scenarios:
- `Unauthorized`: Access control violation
- `InvalidAmount`: Zero or invalid payment amount
- `InvalidLength`: Array length mismatch
- `InsufficientBalance`: Inadequate funds
- `EmployeeNotFound`: Invalid employee address
- `EmployeeAlreadyExist`: Duplicate employee
- `InvalidAddress`: Zero address entry
- `ExceedsLimit`: Employee limit exceeded

## Limitations
1. Maximum 20 employees per contract instance
2. Requires manual triggering of payments (can be automated with Chainlink)

## Future Improvements
1. Integration with Chainlink for automated payments
2. Dynamic employee limits
3. Multi-signature support for payment approval
4. Payment amount modification functionality
5. Support for multiple tokens per organization
6. Enhanced reporting and analytics features

## Gas Optimization Notes
- Batch operations for multiple employees
- Efficient storage usage with mappings
- Minimal state changes
- Optimized loops and array operations