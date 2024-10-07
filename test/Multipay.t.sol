// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Multipay.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract MultipayTest is Test {
    Multipay public multipay;
    MockERC20 public mockToken;
    address public owner;
    address public employee1;
    address public employee2;

    function setUp() public {
        owner = address(this);
        employee1 = address(0x1);
        employee2 = address(0x2);

        multipay = new Multipay("TestOrg");
        mockToken = new MockERC20();

        vm.deal(owner, 100 ether);
        mockToken.transfer(address(multipay), 1000 * 10**18);
    }

    function testSetupPaymentMethod() public {
        multipay.setupPaymentMethod(address(mockToken), 30 days, block.timestamp + 1 days);
        
        (Multipay.OrganizationDetails memory orgdetails ) = multipay.getOrganizationDetails();
        assertEq(orgdetails.tokenAddress, address(mockToken));
        assertEq(orgdetails.paymentInterval, 30 days);
        assertEq(orgdetails.startTime, block.timestamp + 1 days);
    }

    function testAddEmployee() public {
        multipay.addEmployee(employee1, 100 * 10**18);
        assertTrue(multipay.employeeExists(employee1));
        assertEq(multipay.getEmployeeCount(), 1);
    }

    function testRemoveEmployee() public {
        multipay.addEmployee(employee1, 100 * 10**18);
        multipay.removeEmployee(employee1);
        assertFalse(multipay.employeeExists(employee1));
        assertEq(multipay.getEmployeeCount(), 0);
    }

    function testSendToEmployee() public {
        multipay.setupPaymentMethod(address(mockToken), 30 days, block.timestamp);
        multipay.addEmployee(employee1, 100 * 10**18);
        
        vm.warp(block.timestamp + 30 days);
        
        uint256 balanceBefore = mockToken.balanceOf(employee1);
        multipay.sendToEmployee();
        uint256 balanceAfter = mockToken.balanceOf(employee1);
        
        assertEq(balanceAfter - balanceBefore, 100 * 10**18);
    }

    function testPublicSend() public {
        address[] memory recipients = new address[](2);
        recipients[0] = employee1;
        recipients[1] = employee2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 50 * 10**18;
        amounts[1] = 75 * 10**18;

        mockToken.approve(address(multipay), 125 * 10**18);

        uint256 balance1Before = mockToken.balanceOf(employee1);
        uint256 balance2Before = mockToken.balanceOf(employee2);

        multipay.publicSend(recipients, amounts, address(mockToken));

        uint256 balance1After = mockToken.balanceOf(employee1);
        uint256 balance2After = mockToken.balanceOf(employee2);

        assertEq(balance1After - balance1Before, 50 * 10**18);
        assertEq(balance2After - balance2Before, 75 * 10**18);
    }
}