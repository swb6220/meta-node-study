// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

contract MyToken {

    mapping(address acount => uint256 blanceOf) private blances;
    mapping(address acountFrom => mapping(address acountTo => uint256 amount)) private allowances;

    string public name = "My ERC20 Token";
    string public desc = "This is My ERC20 Token Demon";
    string public symbol = "METK";
    uint256 public decimals = 18;
    address public owner;
    uint256 public supplies;

    constructor(uint256 _amount) {
        owner = msg.sender;
        _mint(msg.sender, _amount);
    }

    event Transfer(address indexed _from, address indexed _to, uint256 _amount);

    event Approval(address indexed _owner, address indexed _spender, uint256 _amount);

    // 增发钱币，合约拥有者有此权限
    function mint(uint256 _amount) external {
        _mint(msg.sender, _amount);
    }

    function _mint(address _to, uint256 _amount) internal  {
        require(_to == owner, "No permission to mint");
        require(_amount > 0, "The mint amount must be greater than zero");

        supplies += _amount;
        blances[_to] += _amount;
    }

    // 销毁钱币，合约拥有者有此权限
    function burn(uint256 _amount) external  {
        _burn(msg.sender, _amount);
    }

    function _burn(address _from, uint256 _amount) internal {
        require(_from == owner, "No permission to burn");
        require(blances[_from] >= _amount, "Blance not enougg");

        blances[_from] -= _amount;
        supplies -= _amount;
    }

    // 调用者查询自己账户的余额
    function blanceOf() external view returns(uint256) {
        return blances[msg.sender];
    }

    // 调用者，将自己_amount数量的前转给接收者_to
    function transfer(address _to, uint256 _amount) external returns (bool) {
        require(_amount > 0, "The amount must be greater then zero");
        require(blances[msg.sender] >= _amount, "Balance insufficient");
        require(msg.sender != _to, "The sender should not be the same as the receiver");
        // 减小caller的账户余额
        blances[msg.sender] -= _amount;
        // 增加接收者的账户余额
        blances[_to] += _amount;

        emit Transfer(msg.sender, _to, _amount);

        return true;
    }

    // 调用者设置用户_to可以从自己余额中获取_amount数量的钱
    function approve(address _to, uint256 _amount) external  returns (bool) {
        require(msg.sender != _to, "Cannot set appoval to self");
        require(blances[msg.sender] >= _amount, "You have no enough blances");

        allowances[msg.sender][_to] = _amount;

        emit Approval(msg.sender, _to, _amount);

        return true;
    }

    // 查询账户_owner给调用者授予了多少可提取金额
    function getAllowance(address _from, address _to) external view returns (uint256) {
        require(msg.sender == _from || msg.sender == _to, "The caller should be the _from or _to");
        return allowances[_from][_to];
    }

    // 将地址_from的账户_amount数量的钱币转给地址_to的用户
    // _amount的数量必须满足_from账户的余额和其授权给_to账户的金额
    // 可以由_from或者_to账户发起转账
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        require(msg.sender == _from || msg.sender == _to, "The caller should be _from");
        require(_amount > 0, "The amount should be more then zero");
        require(blances[_from] >= _amount, "Blance not enough");
        require(allowances[_from][_to] >= _amount, "The allowance not enough");

        blances[_from] -= _amount;
        blances[_to] += _amount;
        allowances[_from][_to] -= _amount;

        emit Transfer(_from, _to, _amount);

        return true;
    }

}