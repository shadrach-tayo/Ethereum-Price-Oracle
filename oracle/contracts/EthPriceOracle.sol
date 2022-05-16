// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
// import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/access/AccessControl.sol";
import "./CallerContractInterface.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

contract EthPriceOracle is AccessControl {
  using SafeMath for uint256;

  struct Response {
    address oracleAddress;
    address callerAddress;
    uint256 ethPrice;
  }

  uint private randNonce = 0;
  uint private modulus = 1000;
  mapping(uint256 => bool) pendingRequests;
  mapping(uint256 => Response[]) requestsIdToResponse;
  
  uint noOfOracles = 0;
  uint THRESHOLD = 0;
  bytes32 public constant ORACLE_ROLE = keccak256('ORACLE_ROLE');
  bytes32 public constant DEFAULT_ADMIN_ROLE = keccak256('DEFAULT_ADMIN_ROLE');

  event AddOracleEvent(address oracleAddress);
  event GetLatestEthPriceEvent(address callerAddress, uint id);
  event SetLatestEthPriceEvent(uint256 ethPrice, address callerAddress);


  constructor(address _owner) {
    _setupRole(DEFAULT_ADMIN_ROLE, _owner);
    _setRoleAdmin(ORACLE_ROLE, bytes32(bytes20(_owner)));
  }

  function getLatestEthPrice() public returns(uint256) {
    randNonce++;
    uint id = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % modulus;
    pendingRequests[id] = true;
    emit GetLatestEthPriceEvent(msg.sender, id);
    return id;
  }

  function setLatestEthPrice(uint256 _ethPrice, address _callerAddress, uint256 _id) public onlyRole(ORACLE_ROLE) {
    require(pendingRequests[_id], "This request is not in my pending list.");
    Response memory resp;
    resp = Response(msg.sender, _callerAddress, _ethPrice);
    requestsIdToResponse[_id].push(resp);
    uint noOfResponses = requestsIdToResponse[_id].length;
    if(noOfResponses == THRESHOLD) {
      uint computedEthPrice = 0;
      for(uint i = 0; i < noOfResponses; i++) {
        computedEthPrice = computedEthPrice.add(requestsIdToResponse[_id][i].ethPrice);
      }
      computedEthPrice = computedEthPrice.div(noOfResponses);
      delete pendingRequests[_id];
      delete requestsIdToResponse[_id];
      CallerContractInterface callerContractInstance;
      callerContractInstance = CallerContractInterface(_callerAddress);
      callerContractInstance.callback(computedEthPrice, _id);
      emit SetLatestEthPriceEvent(computedEthPrice, _callerAddress);
    }
  }

  function addOracle(address _oracle) public {
    grantRole(ORACLE_ROLE, _oracle);
    noOfOracles++;
  }

  function removeOracle(address _oracle) public {
    require(noOfOracles > 1);
    revokeRole(ORACLE_ROLE, _oracle);
  }

}