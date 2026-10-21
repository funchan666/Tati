# Tati 金币与 Apple 内购

2026-10-21。实现采用项目现有 SwiftUI 和 StoreKit 2，最低系统 iOS 17。

## 商品配置

完整配置见 [Tati-IAP-products.csv](Tati-IAP-products.csv)。用户提供的 7 个 ID 和价格数字保持不变，币数调整为 450 / 950 / 2,700 / 5,800 / 12,400 / 32,500 / 70,000。

新增两档消耗型商品：

| Product ID | USD 基准价格 | 金币 |
| --- | ---: | ---: |
| nvqpshrkctazlme | 2.99 | 1,500 |
| bzrktwqmnvslhya | 29.99 | 19,200 |

价格表按 USD 基准展示，Apple 根据 storefront 给出实际本币价格。此 CSV 是配置交接表，不是已上传的 App Store Connect 记录。必须在 com.tati.app 对应的 App Store Connect 应用下核对原有 7 档，并创建新增 2 档 Consumable 商品、价格和可售地区，完成必要的元数据及商务协议配置。本轮没有登录或修改 App Store Connect。

## 客户端购买及交付

- 启动只订阅 Transaction.updates 并检查 Transaction.unfinished；进入钱包、选择套餐不会请求商品。只有 Buy 按钮调用 Product.products(for:)，只请求选中的 ID。
- 获取商品后使用 Apple displayPrice；USD storefront 的价格与配置不符或商品不是 consumable 时停止，不弹出购买流程。
- 每次支付前原子保存 checkout token、原账户 ID、SKU 和当时金币数量。用该 UUID 作为 appAccountToken，并通过这份明确映射关联到账户。旧版本 offer 的到账数量不采用新版本目录重新计算。
- 调用真实 Product.purchase(options:)，保留 Apple 系统购买确认。没有伪造购买成功、赠送替代购买或自动购买。
- 只有 verified 交易可交付。以 Apple transaction.id 去重；账户归属、offer、余额、交付记录、已处理 ID 在同一份 visitor-v1.json 中原子写入并读回确认。确认成功后才 finish()。
- 重复回调只完成已保存的订单，不重复加币。未知归属、缺 token、签名失败、旧记录证据不足或保存失败均不结束交易。账号删除保留交易归属及去重证据，新账号不能接收旧订单。
- 取消不加币；待批准由更新监听处理；中断可通过 Recover purchases 重新检查未结束订单。没有将消耗型商品伪装成可无限恢复的永久权益。
- 收到已验证的退款/撤销事件时仅调整对应账户，已花费部分记为待抵扣调整，从后续购买到账中结清，重复事件不重复扣减。未接入服务端退款通知，不保证客户端收到所有历史退款事件。

## 赠送及消费

- 新建访客账号首次登录赠送 300 金币，余额与领取标记一次保存；退出登录、重启或重新展示欢迎卡都不重复发放。旧账号迁移不追溯发放。欢迎卡采用既有金币、礼盒和票券图片，入场动画遵循 Reduce Motion。
- 欢迎弹窗关闭状态持久化，保存失败时保留入口；金币在进入首页前已到账。
- 总余额 = 购买金币 + 赠送/签到金币，所有页面监听同一 VisitorStore；支出优先扣赠送部分，不收取聊天、消息、语音/视频通话、关注、浏览或发布费用。
- 房间礼物特效分别为 50 / 80 / 120 / 180 / 240 / 360 / 680 / 1,200 金币，按数量乘算。确认前显示金额及余额，保存支出和使用记录后播放原图特效。当前仅在本人屏幕播放，不冒充远端送达或转账；私聊/个人页不能借礼物入口扣费。
- Kitchen spotlight 头像框 300 金币一次解锁。解锁和扣费同次保存，此后穿戴/卸下免费；保留旧版本已经获得的头像框。
- 每次消费都需明确确认。余额不足显示缺少的数量，Recharge 按钮打开钱包；不会自动扣款或购买。充值后由用户重新确认原消费。

## 当前边界与检查记录

原 UI 素材未覆盖或替换。只做源码、配置、资源引用和 git diff 检查；没有编译、测试、模拟器/真机运行、sandbox/TestFlight 支付、真实扣款、Apple 商品在线可售或退款恢复验证。

当前账户/钱包仍是设备持久化，未建立服务端钱包、账号找回、跨设备同步或防止重新安装领取欢迎金币的机制。删除账号/应用数据可能丢失余额和未交付订单关联信息；无法从 Apple 已完成的消耗型订单重建剩余余额，不得宣称已具备跨设备资产恢复。

官方依据：[Product](https://developer.apple.com/documentation/storekit/product)、[appAccountToken](https://developer.apple.com/documentation/appstoreserverapi/appaccounttoken)、[finish()](https://developer.apple.com/documentation/storekit/transaction/finish())、[unfinished](https://developer.apple.com/documentation/storekit/transaction/unfinished)。商品可售和实际支付效果需后续授权运行验证。
