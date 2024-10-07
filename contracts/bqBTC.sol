// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract bqBTC is ERC20, Ownable {
    uint8 private _customDecimals;
    address public poolAddress;
    address public coverAddress;
    address public initialOwner;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 initialSupply,
        address _initialOwner
    ) ERC20(name, symbol) Ownable(_initialOwner) {
        _customDecimals = decimals_;
        _mint(msg.sender, initialSupply);
        initialOwner = _initialOwner;
    }

    function decimals() public view virtual override returns (uint8) {
        return _customDecimals;
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        require(
            msg.sender == initialOwner ||
                msg.sender == poolAddress ||
                msg.sender == coverAddress,
            "not authorized to call he function"
        );
        _burn(account, amount);
    }

    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return super.balanceOf(account);
    }

    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
        return super.approve(spender, amount);
    }

    function setPoolandCover(address pool, address cover) public onlyOwner {
        require(
            pool != address(0) && cover != address(0),
            "Address cant be empty"
        );
        require(
            poolAddress == address(0) && coverAddress == address(0),
            "Pool address already set"
        );

        coverAddress = cover;
        poolAddress = pool;
    }
}
