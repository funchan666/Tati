# Tati

内容素材加载更新（2026-10-22）：49 张图片、16 条视频全部通过指定 R2 链接加载，本地原件、旧打包副本及审查副本已按用户要求删除。`ProjectMaterials/content-slots.json` 保留链接、原文件名与历史校验信息；无需本地媒体即可用 `python3 Scripts/import_content.py` 重新生成配置。静态核对使用 `python3 Scripts/inspect_hosted_media.py`；加 `--check-links` 仅执行 HTTPS HEAD 可达性检查。详见 [链接资源说明](Documentation/Hosted-content-media.md)。

根据提供的蓝湖美食社交设计实现的原生 SwiftUI iPhone 应用。最低 iOS 17；当前新增 Duo API 使用 Xcode 27.1 SDK 声明并带运行时可用性保护。品牌 Tati，五个入口 Home / Room / Video / AI / Me。本轮交付本地访客版本，保留礼物，不自动关注。

工程：`Tati.xcodeproj`，scheme：`Tati`。`project.yml` 为 XcodeGen 配置源。已生成工程，未执行编译、测试、分析器、模拟器或设备运行。

## 已实现的本地交互

- 欢迎页、应用内 WebView 协议阅读、访客进入、退出与删除本地资料。
- 直播 Hot / Discover / Follow、语音房 Party / Food / Follow、热门话题、搜索、城市/主题/语言筛选；关闭筛选不应用临时选择。
- 房间预览、主播资料面板、关注、成员空态、房型与背景选择、PK 双画面预览、本地音频播放/静音、麦克风权限检查、最小化/返回/退出。
- 礼物选择/数量/余额不足、本地赠礼预览记录；每日签到按八日 10–80 免费演示币循环，与真实购买余额隔离；已有余额保留。
- 视频列表内播放/暂停、导入/替换视频、真实首帧封面、50 字描述、本地保存成功提示、详情播放/暂停/结束、点赞、删除、评论草稿。一个共享播放器，离页/切 Tab/进入后台停止。
- 用户主页、关注关系、拉黑/取消拉黑；拉黑后列表和搜索隐藏对应内容。
- 资料头像/封面选择与移除、姓名/简介/地区/兴趣编辑、钱包套餐布局与记录、签到、等级、背包分类与头像框、设置。
- 私聊、客服、反馈/举报支持本地图片附件；评论与 AI 问题支持文本草稿。客服 FAQ 可搜索/展开，语言偏好可选择/确认/保存，但尚无完整译文。
- 开播准备的照片选择、标题、分类和原生相机预览。相机只预览，不广播。

本地数据保存在 Application Support/Tati/visitor-v1.json；导入媒体在相邻 Media 目录。变更原子写入并回读确认。读取失败不覆盖原始数据；存储校验失败暂停继续写入。退出保留资料，删除访客清除记录及已关联媒体。

欢迎页及设置页的协议入口统一通过 `WKWebView` 打开用户提供的[用户协议](https://sites.google.com/view/tutu-terms-of-service/foodd)和[隐私协议](https://sites.google.com/view/tati-privacypolicy/foodd)，需要网络。提供加载提示、失败重试与应用内返回；布局更新不会重新加载文档。链接已接入源码，未进行应用内加载验证；网页读取工具未能访问这两个页面，不代表已确认其发布状态。

## 素材

用户提供的 145 张 UI PNG 保留原名与内容。139 张按语义导入运行时；原品牌、欢迎页、签到文案使用局部编辑副本；额外补充发送/暂停/评论/观看人数/关闭开关/播放六个缺失图标。UI 运行时总计 144 个 imageset 和一个 AppIcon；独立内容目录另外增加 49 个照片 imageset、16 个真实视频封面 imageset、16 个 MP4 和只读内容映射。原始资料、总览图、审计联系表不会加入应用资源。

- 对应表：`ProjectMaterials/DesignReferences/AssetAudit/runtime-mapping.json`
- 原稿盘点：`ProjectMaterials/DesignReferences/AssetAudit/README.md`
- 生成/编辑记录：`ProjectMaterials/GeneratedUI/prompts.json`
- 内容素材逐文件映射：`ProjectMaterials/content-slots.json`（49 图、16 视频均已接入）
- 导入命令：`python3 Scripts/import_assets.py`（依赖 Pillow，仅资源拷贝/缩放，不构建应用）。新增源文件后用 `xcodegen generate` 更新工程。

已在蓝湖逐张查看全部 63 张画板，并逐项对应页面入口、弹层和本地交互。详见 [逐页核对清单](ProjectMaterials/DesignReferences/lanhu-page-audit.md)。本轮 436 个已有素材及目录元数据文件的 SHA-256 前后相同，没有新增或替换图片。未运行应用作像素与设备布局验收，不能称为已完成像素级验收。

## 待后续输入与接服务

2026-10-20 已接入用户提供的全部 49 张图片与 16 段视频：49 个示例资料使用稳定图片，4 个语音房复用各自房主照片。按最新分配，10 段保留在短视频列表，6 段分别供全部 6 个视频直播间循环展示；语音房保持 4 个。全部 6 个直播间封面均使用各自播放视频的实际抽帧，与进入房间后的内容一致。全部图片可从搜索的 People 进入，10 段短视频可从 Video 或搜索进入，6 段房间视频可从首页或房间搜索进入。房间展示的是本地素材，尚未接入实时直播服务。具体分配见 [素材接入清单](ProjectMaterials/DesignReferences/ContentAudit/README.md)。设计中的三首房间音乐和完整界面译文仍未提供。

全部房间共用发言与礼物动态区：每个房间配置 6 条主题示例发言和 2 条示例礼物，有限次分批显示；页面标题为 Room highlights，操作反馈区分保存与送达。当前访客的房间消息与礼物记录按房间保存，送礼继续使用原本的演示金币账本，只有持久保存成功才更新动态。示例内容不写入余额、交易或成员记录。旧礼物记录不补猜房间归属，已有资料与账本保留。

以下入口已有页面/状态，但线上能力尚未接入：账号、直播/语音上麦/PK、观众与排行、互关聊天与通话、AI 回答、上传/审核/举报受理、邀请码、推送、充值和真实礼物投递。钱包不请求商品、不编造价格、不发起/完成交易；演示礼物不扣真实余额。`TatiPurchases` 目前只负责显示未配置状态，不是 StoreKit 支付实现。

发布前另需确认 Bundle ID（当前占位 `com.tati.app`）、签名 Team、后台/实时音视频/AI 配置、App Store 商品、发行者与客服信息及正式协议。在线服务接入后同步替换本地说明与隐私清单。

## 静态交付核对

18 个 Swift 文件的 target 引用、启动 Storyboard 和隐私资源、144 个 imageset 的 JSON/图片文件、75 个直接写明的素材名引用、436 个已有素材文件哈希、Info/Privacy plist、XML 与 git diff 已做静态核对。没有执行 Swift 编译、Xcode 构建、测试、运行或实际交易。静态核对不证明 Swift 类型检查和真实设备交互通过。

## 内容导入补充（2026-10-20）

`python3 Scripts/import_content.py` 显式导入已分配的全部内容；原媒体逐字节保留，未压缩或截短。内容资源源文件约 148.91 MiB，全部运行时资源源文件约 168.99 MiB，均不是 IPA 大小。两个 Asset Catalog 分离，既有 UI 图片未修改。

Duo 本次只处理新接入照片和独立播放器的容器/遮挡适配，保留既有业务所有者，不宣称整包或所有姿态已验收。详情及当前 SDK 证据见素材清单。未执行编译、测试、App 运行或实际 iOS 视频播放验证。


## 厨房手记与当前交付检查

新增食谱份量换算、采购清单、私人的试做记录，以及两个可用金币一次解锁的主题食谱册。使用两套随包字体和 Image 2 Host-Native 原创素材；业务命名保留旧存档键及交易标识兼容。

当前审核风险、权限行为和未完成的服务见 [本轮交付记录](Documentation/Kitchen-product-and-review-audit.md)。该记录优先于此前针对单页的历史检查。仅运行了源码、配置与资源核对，没有编译、应用运行或真实支付验证。
