# Tati 金币与 Apple 内购

2026-10-22，按最新版 Prada 更新。当前规则以 [接入记录](../Docs/BackendAPI/Integration.md) 及 `KitchenCoinPurchases` 为准。

保留宿主 StoreKit 2 和唯一 Transaction.updates 消费者。九档商品 ID、币数及 USD 价格保持不变；目录来自服务器 kitchen offers。App Store Connect 商品创建、可售状态、签名和真实交易没有验证。

钱包进入时通过 Product.products 读取 Apple 的真实消耗型商品及当地价格。加载期间和不可用的商品均不可购买；失败保留提示和主动重试入口，不使用参考美元价格替代商品价格。退出页面不取消已共享的商品查询；购买仍重新核对具体商品并调用 Apple 原生购买界面，不增加模拟成功或直接发币路径。

九档商品的名称、描述、商品 ID、币数及 USD 参考价格汇总在 `Tati-IAP-products.csv`。参考价格不等于已在 App Store Connect 设置或可售的价格。当前共享 scheme 未指定本地 StoreKit Configuration，Archive 使用 Release；仓库不含 `.storekit` 商品文件。App Review 使用 Apple 沙盒测试正式配置的商品，不会产生实际扣款；沙盒不是应用自行模拟购买。提交前需在 App Store Connect 配齐商品、价格、地区、审核截图及付费协议，并用 TestFlight/沙盒确认取商品、Apple 交易、后台验单与到账完整链路。当前仅检查源码，未完成这些外部验证。

每笔新购在内存中冻结来源、原资料 ID、appAccountToken、商品和当时币数。必要 Apple 验证和真实 App receipt 快照完成后，先 finish，再向统一接口进行一次最长 30 秒的确认。确认等待不占 Apple 购买锁。原生购买仅在 HTTP 2xx + 整数 code=0 后原子写入金币和去重记录；实时消息购买不增加原生钱包币数，确认后刷新现有网页。旧响应不会归给新资料。

进程启动只做一次、最多十秒的消耗型遗留交易释放；不重验旧单、不补到账。历史订单证据保留，但不再自动恢复或联网补交消耗型订单。待批准不 finish；未知类型和非消耗型商品不混入清理。已验证退款仅调整原账户，并保留原有负债处理。

先 finish 且不自动补交，存在中断后已扣款未到账的风险。钱包入口改为 Purchase help，不承诺恢复；用户可通过 hudden.serudiv22@gmail.com 提供 Apple 订单信息。后台必须在实际验单与幂等处理成功后才返回成功，不能把导入响应当成验单服务。

已有余额、支出、食谱解锁、头像框、真实用户操作和历史记账键保留。首次赠币按接口金额幂等发放，欢迎赠币弹窗已移除。礼物仍为当前房间视图的个人特效，不冒充远端投递或转账。未增加聊天、关注或浏览收费。

未编译、运行或进行真实支付/退款/服务验证。
