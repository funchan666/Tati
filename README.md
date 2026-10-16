# Tati

根据提供的蓝湖美食社交设计实现的原生 SwiftUI iPhone 应用。最低 iOS 17，品牌 Tati，五个入口 Home / Room / Video / AI / Me。本轮交付本地访客版本，保留礼物，不自动关注。

工程：`Tati.xcodeproj`，scheme：`Tati`。`project.yml` 为 XcodeGen 配置源。已生成工程，未执行编译、测试、分析器、模拟器或设备运行。

## 已实现的本地交互

- 欢迎页、协议说明、访客进入、退出与删除本地资料。
- 直播 Hot / Discover / Follow、语音房 Party / Food / Follow、热门话题、搜索、城市/主题/语言筛选；关闭筛选不应用临时选择。
- 房间预览、主播资料面板、关注、成员空态、房型与背景选择、PK 双画面预览、本地音频播放/静音、麦克风权限检查、最小化/返回/退出。
- 礼物选择/数量/余额不足、本地赠礼预览记录；每日签到按八日 10–80 免费演示币循环，与真实购买余额隔离；已有余额保留。
- 视频列表内播放/暂停、导入/替换视频、真实首帧封面、50 字描述、本地保存成功提示、详情播放/暂停/结束、点赞、删除、评论草稿。一个共享播放器，离页/切 Tab/进入后台停止。
- 用户主页、关注关系、拉黑/取消拉黑；拉黑后列表和搜索隐藏对应内容。
- 资料头像/封面选择与移除、姓名/简介/地区/兴趣编辑、钱包套餐布局与记录、签到、等级、背包分类与头像框、设置。
- 私聊、客服、反馈/举报支持本地图片附件；评论与 AI 问题支持文本草稿。客服 FAQ 可搜索/展开，语言偏好可选择/确认/保存，但尚无完整译文。
- 开播准备的照片选择、标题、分类和原生相机预览。相机只预览，不广播。

本地数据保存在 Application Support/Tati/visitor-v1.json；导入媒体在相邻 Media 目录。变更原子写入并回读确认。读取失败不覆盖原始数据；存储校验失败暂停继续写入。退出保留资料，删除访客清除记录及已关联媒体。

## 素材

用户提供的 145 张 UI PNG 保留原名与内容。139 张按语义导入运行时；原品牌、欢迎页、签到文案使用局部编辑副本；额外补充发送/暂停/评论/观看人数/关闭开关/播放六个缺失图标。运行时总计 144 个 imageset 和一个 AppIcon。原始资料、总览图、审计联系表不会加入应用资源。

- 对应表：`ProjectMaterials/DesignReferences/AssetAudit/runtime-mapping.json`
- 原稿盘点：`ProjectMaterials/DesignReferences/AssetAudit/README.md`
- 生成/编辑记录：`ProjectMaterials/GeneratedUI/prompts.json`
- 后补内容槽位：`ProjectMaterials/content-slots.json`
- 导入命令：`python3 Scripts/import_assets.py`（依赖 Pillow，仅资源拷贝/缩放，不构建应用）。新增源文件后用 `xcodegen generate` 更新工程。

已在蓝湖逐张查看全部 63 张画板，并逐项对应页面入口、弹层和本地交互。详见 [逐页核对清单](ProjectMaterials/DesignReferences/lanhu-page-audit.md)。本轮 436 个已有素材及目录元数据文件的 SHA-256 前后相同，没有新增或替换图片。未运行应用作像素与设备布局验收，不能称为已完成像素级验收。

## 待后续输入与接服务

人物照片、直播封面、视频及视频封面仍待用户补充；设计中的三首房间音乐和完整界面译文也尚未提供。当前不使用网络照片、随机人物或假视频。提供后按 content-slots.json 标注归属，再导入到运行时资源，不能只把原图放进 ProjectMaterials 就当成已接入。

以下入口已有页面/状态，但线上能力尚未接入：账号、直播/语音上麦/PK、观众与排行、互关聊天与通话、AI 回答、上传/审核/举报受理、邀请码、推送、充值和真实礼物投递。钱包不请求商品、不编造价格、不发起/完成交易；演示礼物不扣真实余额。`TatiPurchases` 目前只负责显示未配置状态，不是 StoreKit 支付实现。

发布前另需确认 Bundle ID（当前占位 `com.tati.app`）、签名 Team、后台/实时音视频/AI 配置、App Store 商品、发行者与客服信息及正式协议。在线服务接入后同步替换本地说明与隐私清单。

## 静态交付核对

16 个 Swift 文件的 target 引用、启动 Storyboard 和隐私资源、144 个 imageset 的 JSON/图片文件、75 个直接写明的素材名引用、436 个已有素材文件哈希、Info/Privacy plist、XML 与 git diff 已做静态核对。没有执行 Swift 编译、Xcode 构建、测试、运行或实际交易。静态核对不证明 Swift 类型检查和真实设备交互通过。
