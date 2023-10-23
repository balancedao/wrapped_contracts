// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./WOTB.sol";

contract Presale is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // ERC20 tokens
  IERC20 public wotb;
  IERC20 public usd;

  // Structure of each vest
  struct Vest {
    uint256 amount; // the amount of WOTB the beneficiary will recieve
    uint256 released; // the amount of WOTB released to the beneficiary
    bool usdTransferred; // whether the beneficiary has transferred the eth into the contract
  }

  // All vested tokens in the contract
  uint256 public allVestedAmount;

  // The mapping of vested beneficiary (beneficiary address => Vest)
  mapping(address => Vest) public vestedBeneficiaries;

  // beneficiary => usd deposited
  mapping(address => uint256) public usdDeposits;

  // Array of beneficiaries
  address[] public beneficiaries;

  // No. of beneficiaries
  uint256 public noOfBeneficiaries;

  // Whether the contract has been bootstrapped with the WOTB
  bool public bootstrapped;

  // Start time of the the vesting
  uint256 public startTime;

  // The duration of the vesting
  uint256 public duration;

  // Price of each OTB token in usd (1e8 precision)
  uint256 public otbPrice;



  constructor(uint256 _otbPrice) {
    require(_otbPrice > 0, 'OTB price has to be higher than 0');

    otbPrice = _otbPrice;
    
  }

  /*---- EXTERNAL FUNCTIONS FOR OWNER ----*/

  /**
   * @notice Bootstraps the presale contract 
   * @param _duration duration in seconds of the period in which the tokens will vest
   * @param _otbAddress address of dpx erc20 token
   * @param _stableAddress addres of usd stable
   */
  function bootstrap(
    uint256 _duration,
    address _otbAddress, 
    address _stableAddress
  ) external onlyOwner returns (bool) {
    require(_otbAddress != address(0), 'OTB address is 0');
    require(_duration > 0, 'Duration passed cannot be 0');
    
    duration = _duration;

    wotb = wOTB(_otbAddress);
    usd = IERC20(_stableAddress);

    uint256 totalOTBRequired;

    for (uint256 i = 0; i < beneficiaries.length; i = i + 1) {
        totalOTBRequired = totalOTBRequired.add(vestedBeneficiaries[beneficiaries[i]].amount);
    }

    require(totalOTBRequired > 0, 'Total OTB required cannot be 0');

    wotb.safeTransferFrom(msg.sender, address(this), totalOTBRequired*10**9); 

    bootstrapped = true;

    emit Bootstrap(totalOTBRequired);

    return bootstrapped;
  }

  /**
  * @notice Sets the vesting start. Only owner can call this.
  * @param _startTime the time (as Unix time) at which point vesting starts
  */

  function setStartTime(uint256 _startTime) public onlyOwner returns (bool) {
    require(_startTime >= block.timestamp, 'Start time cannot be before current time');
    startTime = _startTime;

    return true;
  }

  /**
   * @notice Adds a beneficiary to the contract. Only owner can call this.
   * @param _beneficiary the address of the beneficiary
   * @param _amount amount of OTB to be vested for the beneficiary
   */
  function addBeneficiary(address _beneficiary, uint256 _amount) public onlyOwner returns (bool) {
    require(_beneficiary != address(0), 'Beneficiary cannot be a 0 address');
    require(_amount > 0, 'Amount should be larger than 0');
    require(!bootstrapped, 'Cannot add beneficiary as contract has been bootstrapped');
    require(vestedBeneficiaries[_beneficiary].amount == 0, 'Cannot add the same beneficiary again');

    beneficiaries.push(_beneficiary);

    vestedBeneficiaries[_beneficiary].amount = _amount;

    allVestedAmount = allVestedAmount + _amount;

    noOfBeneficiaries = noOfBeneficiaries.add(1);

    emit AddBeneficiary(_beneficiary, _amount);

    return true;
  }

  /**
   * @notice Updates beneficiary amount. Only owner can call this.
   * @param _beneficiary the address of the beneficiary
   * @param _amount amount of OTB to be vested for the beneficiary
   */
  function updateBeneficiary(address _beneficiary, uint256 _amount) external onlyOwner {
    require(_beneficiary != address(0), 'Beneficiary cannot be a 0 address');
    require(!bootstrapped, 'Cannot update beneficiary as contract has been bootstrapped');
    require(
      vestedBeneficiaries[_beneficiary].amount != _amount,
      'New amount cannot be the same as old amount'
    );
    require(
      !vestedBeneficiaries[_beneficiary].usdTransferred,
      'Beneficiary should have not transferred USD'
    );
    require(_amount > 0, 'Amount cannot be smaller or equal to 0');
    require(vestedBeneficiaries[_beneficiary].amount != 0, 'Beneficiary has not been added');

    vestedBeneficiaries[_beneficiary].amount = _amount;

    emit UpdateBeneficiary(_beneficiary, _amount);
  }

  /**
   * @notice Removes a beneficiary from the contract. Only owner can call this.
   * @param _beneficiary the address of the beneficiary
   * @return whether beneficiary was deleted
   */
  function removeBeneficiary(address payable _beneficiary) external onlyOwner returns (bool) {
    require(_beneficiary != address(0), 'Beneficiary cannot be a 0 address');
    require(!bootstrapped, 'Cannot remove beneficiary as contract has been bootstrapped');
    if (vestedBeneficiaries[_beneficiary].usdTransferred) {
      _beneficiary.transfer(usdDeposits[_beneficiary]);
    }
    for (uint256 i = 0; i < beneficiaries.length; i = i + 1) {
      if (beneficiaries[i] == _beneficiary) {
        noOfBeneficiaries = noOfBeneficiaries.sub(1);

        delete beneficiaries[i];
        delete vestedBeneficiaries[_beneficiary];

        emit RemoveBeneficiary(_beneficiary);

        return true;
      }
    }
    return false;
  }

  /**
   * @notice Withdraws USD tokens deposited into the contract. Only owner can call this.
   */
  function withdraw() external onlyOwner {
    uint256 usdBalance = usd.balanceOf(address(this));
    usd.safeTransfer(msg.sender, usdBalance);
    

    emit WithdrawUsd(usdBalance);
  }

  /*---- EXTERNAL FUNCTIONS ----*/

  /**
   * @notice Transfers usd from beneficiary to the contract.
   */
  function transferUsd() external  {
    require(
      !vestedBeneficiaries[msg.sender].usdTransferred,
      'Beneficiary has already transferred USD'
    );
    require(vestedBeneficiaries[msg.sender].amount > 0, 'Sender is not a beneficiary');

    uint256 usdAmount = vestedBeneficiaries[msg.sender].amount.mul(otbPrice);

    usd.safeTransferFrom(msg.sender, address(this), usdAmount);

    usdDeposits[msg.sender] = usdAmount;

    vestedBeneficiaries[msg.sender].usdTransferred = true;

    emit TransferredUsd(msg.sender, usdAmount);
  }

  /**
   * @notice Transfers vested tokens to beneficiary.
   */
  function release() external returns (uint256 unreleased) {
    require(bootstrapped, 'Contract has not been bootstrapped');
    require(startTime > 0, 'Start time is not set yet');
    require(vestedBeneficiaries[msg.sender].usdTransferred, 'Beneficiary has not transferred funds');
    unreleased = releasableAmount(msg.sender);

    require(unreleased > 0, 'No releasable amount');

    vestedBeneficiaries[msg.sender].released = vestedBeneficiaries[msg.sender].released.add(
      unreleased
    );

    wotb.transfer(msg.sender, unreleased*10**9); // transfer with 9 decimal as wOTB

    emit TokensReleased(msg.sender, unreleased);
  }

  /*---- VIEWS ----*/
  /**
   * @notice Calculates the amount to invest in USD.
   * @param beneficiary address of the beneficiary
   */
  function investmentAmount(address beneficiary) public view returns (uint256) {
    return vestedBeneficiaries[beneficiary].amount.mul(otbPrice);
  }

  /**
   * @notice Calculates the amount that has already vested but hasn't been released yet.
   * @param beneficiary address of the beneficiary
   */
  function releasableAmount(address beneficiary) public view returns (uint256) {
    return vestedAmount(beneficiary).sub(vestedBeneficiaries[beneficiary].released);
  }

  /**
   * @notice Calculates the amount that has already vested.
   * @param beneficiary address of the beneficiary
   */
  function vestedAmount(address beneficiary) public view returns (uint256) {
    uint256 totalBalance = vestedBeneficiaries[beneficiary].amount;

    if (block.timestamp < startTime || startTime == 0) {
      return 0;
    } else if (block.timestamp >= startTime.add(duration)) {
      return totalBalance;
    } else {
      
      return
      totalBalance.mul(block.timestamp.sub(startTime)).div(duration);
    }
  }


  /*---- EVENTS ----*/

  event TokensReleased(address beneficiary, uint256 amount);

  event AddBeneficiary(address beneficiary, uint256 amount);

  event RemoveBeneficiary(address beneficiary);

  event UpdateBeneficiary(address beneficiary, uint256 amount);

  event TransferredUsd(address beneficiary, uint256 usdAmount);

  event WithdrawUsd(uint256 amount);

  event Bootstrap(uint256 totalOTBRequired);
}
