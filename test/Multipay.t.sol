// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Multipay.sol";
import "../src/MultipayFactory.sol";

contract MultipayTest is Test {
    Multipay public implementation;
    MinimalProxy public factory;
    address public owner;
    address public platformFeeRecipient;
    address public employee1;
    address public employee2;
    uint256 _paymentInterval = 30 days;
    //weeks in year
    uint256 _endtime = 52 weeks; //1 year

    // Test ERC20 token
    ERC20Mock public testToken;

    event ContractCreated(address indexed newMultisig, uint256 position);
    event ERC20Transfer(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event NativeTransfer(
        address indexed from,
        address indexed to,
        uint256 amount
    );

    function setUp() public {
        owner = makeAddr("owner");
        platformFeeRecipient = makeAddr("feeRecipient");
        employee1 = makeAddr("employee1");
        employee2 = makeAddr("employee2");

        // Deploy implementation and factory
        implementation = new Multipay();
        factory = new MinimalProxy();

        // Deploy test token
        testToken = new ERC20Mock("Test Token", "TEST");

        vm.label(address(implementation), "Implementation");
        vm.label(address(factory), "Factory");
        vm.label(address(testToken), "TestToken");
    }

    function testDeployClone() public {
        vm.startPrank(owner);

        address cloneAddress = factory.createClone(
            address(implementation),
            "TestOrg",
            address(testToken),
            owner,
            platformFeeRecipient
        );

        Multipay clone = Multipay(cloneAddress);

        assertEq(clone.owner(), owner);
        assertEq(clone.platformFeeRecipient(), platformFeeRecipient);
        assertEq(clone.getOrganizationDetails().organizationName, "TestOrg");

        vm.stopPrank();
    }

    function testPublicSendWithFee() public {
        // Deploy clone
        vm.prank(owner);
        address cloneAddress = factory.createClone(
            address(implementation),
            "TestOrg",
            address(testToken),
            owner,
            platformFeeRecipient
        );
        Multipay clone = Multipay(cloneAddress);

        // Test ERC20 transfers
        address[] memory recipients = new address[](2);
        recipients[0] = employee1;
        recipients[1] = employee2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        // Mint tokens to sender and approve clone
        address sender = makeAddr("sender");
        testToken.mint(sender, 1000e18);

        vm.startPrank(sender);
        testToken.approve(cloneAddress, type(uint256).max);

        // Calculate expected platform fee
        uint256 totalAmount = 200e18; // 100e18 * 2
        uint256 expectedPlatformFee = (totalAmount * 5) / 100; // 5% of 200e18

        // Expect events
        vm.expectEmit(true, true, true, true);
        emit ERC20Transfer(
            address(testToken),
            sender,
            platformFeeRecipient,
            expectedPlatformFee
        );

        vm.expectEmit(true, true, true, true);
        emit ERC20Transfer(address(testToken), sender, employee1, 100e18);

        vm.expectEmit(true, true, true, true);
        emit ERC20Transfer(address(testToken), sender, employee2, 100e18);

        // Execute public send
        clone.publicSend(recipients, amounts, address(testToken));

        // Verify balances
        assertEq(testToken.balanceOf(employee1), 100e18);
        assertEq(testToken.balanceOf(employee2), 100e18);
        assertEq(
            testToken.balanceOf(platformFeeRecipient),
            expectedPlatformFee
        );

        vm.stopPrank();
    }

    function testPublicSendWithNativeToken() public {
        // Deploy clone
        vm.prank(owner);
        address cloneAddress = factory.createClone(
            address(implementation),
            "TestOrg",
            address(testToken),
            owner,
            platformFeeRecipient
        );
        Multipay clone = Multipay(cloneAddress);

        address[] memory recipients = new address[](2);
        recipients[0] = employee1;
        recipients[1] = employee2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 1 ether;

        address sender = makeAddr("sender");
        vm.deal(sender, 10 ether);

        uint256 totalAmount = 2 ether;
        uint256 expectedPlatformFee = (totalAmount * 5) / 100; // 5% of 2 ether

        uint256 totalRequired = totalAmount + expectedPlatformFee;

        vm.startPrank(sender);
        // Expect events
        vm.expectEmit(true, true, true, true);
        emit NativeTransfer(sender, platformFeeRecipient, expectedPlatformFee);

        vm.expectEmit(true, true, true, true);
        emit NativeTransfer(sender, employee1, 1 ether);

        vm.expectEmit(true, true, true, true);
        emit NativeTransfer(sender, employee2, 1 ether);

        // Execute public send with native token
        clone.publicSend{value: totalRequired}(
            recipients,
            amounts,
            0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
        );

        // Verify balances
        assertEq(employee1.balance, 1 ether);
        assertEq(employee2.balance, 1 ether);
        assertEq(platformFeeRecipient.balance, expectedPlatformFee);

        vm.stopPrank();
    }

    function testGetAllProxiesByDeployer() public {
        vm.startPrank(owner);

        // Deploy multiple clones
        address clone1 = factory.createClone(
            address(implementation),
            "TestOrg1",
            address(testToken),
            owner,
            platformFeeRecipient
        );

        address clone2 = factory.createClone(
            address(implementation),
            "TestOrg2",
            address(testToken),
            owner,
            platformFeeRecipient
        );

        // Get all proxies by deployer
        address[] memory proxies = factory.getAllProxiesByDeployer(owner);

        // Verify
        assertEq(proxies.length, 2);
        assertEq(proxies[0], clone1);
        assertEq(proxies[1], clone2);

        vm.stopPrank();
    }

    function testCannotInitializeTwice() public {
        vm.startPrank(owner);

        address cloneAddress = factory.createClone(
            address(implementation),
            "TestOrg",
            address(testToken),
            owner,
            platformFeeRecipient
        );

        Multipay clone = Multipay(cloneAddress);

        // Try to initialize again
        vm.expectRevert(Multipay.AlreadyInitialized.selector);
        clone.initialize(
            "TestOrg2",
            address(testToken),
            owner,
            platformFeeRecipient
        );

        vm.stopPrank();
    }

    function testAddEmployee() public {
        vm.startPrank(owner);

        Multipay clone = deployClone();

        clone.addEmployee(employee1, 100 * 10 ** 18);
        assertTrue(clone.employeeExists(employee1));
        assertEq(clone.getEmployeeCount(), 1);

        vm.stopPrank();
    }

    function testRemoveEmployee() public {
        vm.startPrank(owner);

        Multipay clone = deployClone();

        clone.addEmployee(employee1, 100 * 10 ** 18);
        clone.removeEmployee(employee1);
        assertFalse(clone.employeeExists(employee1));
        assertEq(clone.getEmployeeCount(), 0);

        vm.stopPrank();
    }

    function testSendToEmployee() public {
        vm.startPrank(owner);

        Multipay clone = deployClone();

        testToken.mint(address(clone), 50 * 1e18);

        clone.setupReoccuringPayment(
            _paymentInterval,
            block.timestamp,
            _endtime
        );
        clone.addEmployee(employee1, 1 * 1e18);

        vm.warp(block.timestamp + _paymentInterval);

        uint256 balanceBefore = testToken.balanceOf(address(clone));
        clone.sendToEmployee();
        uint256 balanceAfter = testToken.balanceOf(address(clone));

        assertEq(balanceBefore - balanceAfter, 1 * 1e18);

        vm.stopPrank();
    }

    function sendToEmployeeNativeToken() public {
        vm.startPrank(owner);

        Multipay clone = deployClone();

        clone.setupReoccuringPayment(
            _paymentInterval,
            block.timestamp,
            _endtime
        );
        clone.addEmployee(employee1, 1 * 10 ** 18);

        vm.warp(block.timestamp + _endtime);

        clone.sendToEmployee{value: 777}();
        uint256 balanceAfter = address(clone).balance;

        assertEq(balanceAfter, 777 - 1);

        vm.startPrank(owner);
    }

    //test max public send with native token
    function testMaxBatchTransferLimit() public {
        // Deploy clone
        vm.prank(owner);
        address cloneAddress = factory.createClone(
            address(implementation),
            "TestOrg",
            address(testToken),
            owner,
            platformFeeRecipient
        );
        Multipay clone = Multipay(cloneAddress);

        // Create a sender with enough funds
        address sender = makeAddr("sender");
        vm.deal(sender, 1000 ether);

        // Test different batch sizes
        uint256[] memory batchSizes = new uint256[](6);
        batchSizes[0] = 500;
        batchSizes[1] = 700;
        batchSizes[2] = 800;
        batchSizes[3] = 900;
        batchSizes[4] = 1000;
        batchSizes[5] = 1400; // Testing beyond MAX_EMPLOYEES

        for (uint256 i = 0; i < batchSizes.length; i++) {
            uint256 batchSize = batchSizes[i];
            console.log("\nTesting batch size:", batchSize);

            // Create recipients and amounts arrays
            address[] memory recipients = new address[](batchSize);
            uint256[] memory amounts = new uint256[](batchSize);

            uint256 totalAmount = 0;

            // Initialize arrays
            for (uint256 j = 0; j < batchSize; j++) {
                recipients[j] = makeAddr(
                    string.concat("recipient", vm.toString(j))
                );
                amounts[j] = 0.01 ether;
                totalAmount += 0.01 ether;
            }

            uint256 platformFee = (totalAmount * clone.PLATFORM_FEE()) / 100;
            uint256 totalRequired = totalAmount + platformFee;

            // Start measuring gas
            uint256 startGas = gasleft();

            vm.prank(sender);
            try
                clone.publicSend{value: totalRequired}(
                    recipients,
                    amounts,
                    0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
                )
            {
                uint256 gasUsed = startGas - gasleft();
                console.log("Successful transfer with batch size:", batchSize);
                console.log("Gas used:", gasUsed);
                console.log("Gas per transfer:", gasUsed / batchSize);
            } catch Error(string memory reason) {
                console.log("Failed at batch size:", batchSize);
                console.log("Error:", reason);
            } catch {
                console.log("Failed at batch size:", batchSize);
                console.log("Unknown error");
            }
        }
    }

    // Test max employee transfer limit
    function testMaxEmployeeTransferLimit() public {
        // Deploy clone
        vm.prank(owner);
        address cloneAddress = factory.createClone(
            address(implementation),
            "TestOrg",
            address(testToken),
            owner,
            platformFeeRecipient
        );
        Multipay clone = Multipay(cloneAddress);

        // Fund the contract
        vm.deal(address(clone), 1000 ether);

        // Test different employee counts
        uint256[] memory employeeCounts = new uint256[](4);
        employeeCounts[0] = 320;
        employeeCounts[1] = 330;
        employeeCounts[2] = 340;
        employeeCounts[3] = 350;


        for (uint256 i = 0; i < employeeCounts.length; i++) {
            uint256 employeeCount = employeeCounts[i];
            console.log("\nTesting employee count:", employeeCount);

            // Reset contract for each test
            vm.prank(owner);
            address newCloneAddress = factory.createClone(
                address(implementation),
                "TestOrg",
                0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
                owner,
                platformFeeRecipient
            );
            Multipay newClone = Multipay(newCloneAddress);
            vm.deal(address(newClone), 1000 ether);

            // Create employee arrays
            address[] memory employees = new address[](employeeCount);
            uint256[] memory amounts = new uint256[](employeeCount);

            // Initialize arrays
            for (uint256 j = 0; j < employeeCount; j++) {
                employees[j] = makeAddr(
                    string.concat("employee", vm.toString(j))
                );
                amounts[j] = 0.01 ether;
            }

            // Setup payment details
            vm.startPrank(owner);
            try newClone.addMultipleEmployees(employees, amounts) {
                newClone.setupReoccuringPayment(
                    1 days,
                    block.timestamp + 1,
                    block.timestamp + 30 days
                );
                vm.stopPrank();

                // Warp to start time
                vm.warp(block.timestamp + 2);

                // Start measuring gas
                uint256 startGas = gasleft();

                vm.prank(owner);
                try newClone.sendToEmployee() {
                    uint256 gasUsed = startGas - gasleft();
                    console.log(
                        "Successful transfer with employee count:",
                        employeeCount
                    );
                    console.log("Total gas used:", gasUsed);
                    console.log("Gas per employee:", gasUsed / employeeCount);
                    console.log(
                        "Approximate cost in ETH (@ 50 gwei):",
                        (gasUsed * 50 * 1e9) / 1e18
                    );
                } catch Error(string memory reason) {
                    console.log("Failed at employee count:", employeeCount);
                    console.log("Error:", reason);
                    break;
                } catch {
                    console.log("Failed at employee count:", employeeCount);
                    console.log("Unknown error");
                    break;
                }
            } catch Error(string memory reason) {
                console.log("Failed to add employees:", employeeCount);
                console.log("Error:", reason);
                break;
            } catch {
                console.log("Failed to add employees:", employeeCount);
                console.log("Unknown error");
                break;
            }
        }
    }

    function deployClone() internal returns (Multipay) {
        address cloneAddress = factory.createClone(
            address(implementation),
            "TestOrg",
            address(testToken),
            owner,
            platformFeeRecipient
        );

        return Multipay(cloneAddress);
    }
}

// Mock ERC20 token for testing
contract ERC20Mock {
    string public name;
    string public symbol;
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        require(
            allowance[from][msg.sender] >= amount,
            "Insufficient allowance"
        );
        require(balanceOf[from] >= amount, "Insufficient balance");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
