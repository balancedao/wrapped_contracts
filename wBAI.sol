// SPDX-License-Identifier: MIT

/*


██████╗  █████╗ ██╗      █████╗ ███╗   ██╗ ██████╗███████╗     █████╗ ██╗    
██╔══██╗██╔══██╗██║     ██╔══██╗████╗  ██║██╔════╝██╔════╝    ██╔══██╗██║    
██████╔╝███████║██║     ███████║██╔██╗ ██║██║     █████╗      ███████║██║    
██╔══██╗██╔══██║██║     ██╔══██║██║╚██╗██║██║     ██╔══╝      ██╔══██║██║    
██████╔╝██║  ██║███████╗██║  ██║██║ ╚████║╚██████╗███████╗    ██║  ██║██║    
╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝    ╚═╝  ╚═╝╚═╝    
                                                                             
WWW: https://www.balancedao.io/
Twitter: https://twitter.com/Balance_AI
Telegram: https://t.me/Balance_AI
Discord: https://discord.gg/PgPkJPqXGG
Medium: https://balancedao.medium.com/


*/

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract wBAI is ERC20, Ownable, AccessControl {
    using SafeMath for uint256;

    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    uint256 public BALANCE_FEE = 123000321; // 0.123 wBAI

    uint256 public _nonce = 0;

    uint256 public cumulative_bridged = 0;
    uint256 public cumulative_bridged_back = 0;

    bool public bridge_back_active = false;

    event Mint(address indexed to, uint256 amount);
    event BridgedTo(string from, address indexed to, uint256 amount, uint256 nonce);
    event BridgedBack(address indexed from, uint256 amount, string to, uint256 nonce);
    event BridgeSet(address indexed bridge);
    

    constructor() ERC20("Wrapped Balance AI", "wBAI") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    function setBridge(address _bridge) external onlyOwner returns(bool) {
        _setupRole(BRIDGE_ROLE, _bridge);
        return true;
    }

    function enableBridgeBack() external onlyOwner returns(bool) {
        bridge_back_active = true;
        return true;
    }

    function adjustFee(uint256 _fee) external onlyOwner returns(bool) {
        require(_fee < 123000321, "Fee can not be higher then initial setup.");
        BALANCE_FEE = _fee;
        return true;
    }

    function bridgedTo(string[] memory _froms, address[] memory _tos, uint256[] memory _amounts) public returns(bool) {
        require(hasRole(BRIDGE_ROLE, _msgSender()), "Caller is not the bridge");
        // require all arrays are the same length
        require(_froms.length == _tos.length && _froms.length == _amounts.length, "Arrays are not the same length");
        // loop through arrays and mint
        for (uint256 i = 0; i < _froms.length; i++) {
            _mint(_tos[i], _amounts[i]);
            cumulative_bridged = cumulative_bridged.add(_amounts[i]);
            emit BridgedTo(_froms[i], _tos[i], _amounts[i], _nonce);
            _nonce++;
        }
        return true;
    }

    function bridgeBack(uint256 _amount, string memory _to) public returns(bool) {
        require(bridge_back_active, "Bridge back is not active yet.");
        require(_amount <= balanceOf(_msgSender()), "Not enough balance");
        // require greater than 0.123000321 wBAI for gas purposes.
        require(_amount > BALANCE_FEE, "Does not meet minimum amount for gas (0.123000321 wBAI)");
        _burn(msg.sender, _amount);
        _nonce++;
        cumulative_bridged_back = cumulative_bridged_back.add(_amount);
        emit BridgedBack(_msgSender(), _amount, _to, _nonce);
        return true;
    }

    function deployer() public view returns (address) {
        return owner();
    }

    // reclaim stuck sent tokens
    function reclaimToken(address _token) public onlyOwner {
        ERC20 token = ERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(owner(), balance);
        payable(owner()).transfer(address(this).balance);
    }



}
