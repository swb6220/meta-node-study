# 作业 1：ERC20 代币

**任务：参考 openzeppelin-contracts/contracts/token/ERC20/IERC20.sol实现一个简单的 ERC20 代币合约。**

要求：
合约包含以下标准 ERC20 功能：
1. balanceOf：查询账户余额。
2. transfer：转账。
3. approve 和 transferFrom：授权和代扣转账。
4. 使用 event 记录转账和授权操作。
5. 提供 mint 函数，允许合约所有者增发代币。

提示：
- 使用 mapping 存储账户余额和授权信息。
- 使用 event 定义 Transfer 和 Approval 事件。
- 部署到sepolia 测试网，导入到自己的钱包


