const { expect } = require("chai")

async function calculateTxFee(tx) {
  // 等待交易确认并获取收据
  const receipt = await tx.wait();
  
  // 如果交易失败，抛出错误
  if (receipt.status === 0) {
    throw new Error("Transaction failed");
  }

  // 获取交易使用的 Gas 数量和价格
  const gasUsed = receipt.gasUsed;
  const gasPrice = receipt.effectiveGasPrice || tx.gasPrice;
  
  // 计算交易费用
  const txFee = gasUsed * gasPrice;
  
  return {
    txFee,       // 交易总费用 (wei)
    gasUsed,     // 使用的 Gas 数量
    gasPrice,    // Gas 单价 (wei)
    receipt      // 完整的交易收据
  };
}

const isLogActive = true
function printLogs(context) {
    if(isLogActive) {
        console.log(context)
    }
}

module.exports = {
  calculateTxFee,
  printLogs
};