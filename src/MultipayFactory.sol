// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "./Multipay.sol";

//deploys clone of Multipay contract

contract MultipayFactory{
    address[] clone;
    address owner;


    constructor(){
        owner = msg.sender;
    }


    function deployClone() external{

    }




}