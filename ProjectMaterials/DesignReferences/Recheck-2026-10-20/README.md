# 2026-10-20 蓝湖全页面复核

范围：用户指定项目的「直播社交4（33）」63 张画板，不包含咖啡社区的 38 张。通过蓝湖当前画布的已加载图像导出、逐图查看，再对应 SwiftUI 源码检查。原始导出图、来源 URL、资源 ID 见 [index.json](index.json)；这里保存的是设计参考，不是 App 截图，也没有加入 App 运行资源。

采用 JPG、UI Design Reference、UI Taste 和 Duo。保持 Tati、五个无文字 Tab、访客登录、送礼、用户提供的媒体分配及协议 WebView。没有编译、测试、静态编译器分析、启动模拟器或运行 App。

## 后续完整复核与修正

再次逐张查看本目录全部 63 张画板，并检查现有页面、素材映射与调用入口。仍按用户文字变更覆盖五个无字 Tab、Tati 品牌、访客认证及真实服务状态。

- 全局颜色：从 44 / 06 / 16 的平色区域采样，粉色调整为 `#FE68B9`，礼物面板绿为 `#D3FE2E`，浅底为 `#F4FFC7`。WebP 导出有轻微颜色误差，数值为当前参考图采样。
- 10 搜索：姓名、粉色城市、房间标识、兴趣按原层级排列；窄宽度分行。默认显示 Creators，输入关键词后保留原有跨分类搜索入口。
- 14 / 40 / 41 语音列表：Follow 移除多出的 Hot room 横幅，并同步减少对应顶部留白。
- 29 / 30 / 54 / 57 人物及视频：关注后补上大图上的 Followed；移除额外 Food lover；主页、我的视频、搜索结果复用 FeedVideoCard，统一头像、宽高比、播放、详情及点赞入口。编辑封面明确按容器裁切，防止横向图片撑宽。
- 31 / 32 / 33 发布：210 点创建菜单进入表单时自动切换大尺寸 sheet；计数移回输入框右下角，输入框高度按原布局调整。保持保存与未发布状态，不伪造上传。
- 17 钱包：换回已有 `coin-pile`，原 `gift-hero` 继续用于邀请码页。
- 22 签到：头图按设计裁去底部装饰留白，返回按钮仍处于安全区域；日期标签移到卡片右上角，复用原标签、金币和卡片素材。显示下一可领取日，修正满八天后下一周期的卡片高亮。
- 04 / 61 房间：空麦位改用原 `mic-small` 加原生圆形按钮背景及边框，不再用工具面板的方形图标；背景选择使用 110:130 缩略比例和角落选中态，移除多余英文背景名。两个生成麦位候选因透明边缘不佳弃用，未进入项目资源。
- 19 / 56 / 59 客服：FAQ 字号、展开正文层级按图收紧；客服标题补原头像，底部调整为麦克风 / 输入与发送 / 图片的顺序。
- 其余画板检查既有页面结构、入口及资源引用；没有为了复制画面里的金额、排名、在线数或聊天内容而接入或伪造服务。

静态结果：原有 654 个 UI / 内容 / 运行时资源的 SHA-256 均未改变。新增文案修正版签到图并同步导入脚本及映射；67 个直接图片引用存在，运行资源 JSON 可读取，旧 VideoCard 引用为零，git diff --check 通过。未编译、测试、启动模拟器或 App；没有设备截图，因此不能宣称已达到逐像素一致或所有姿态无遮挡。

## 本轮主要修正

- 对照原画板收紧房型与人物弹层，补语言选中态；原卡片、原插画、原图标保留。
- 窄屏聊天栏用同一组子视图重排，保留输入与附件选择状态；礼物余额/数量/按钮支持分行。
- 通用提示层在高度不足时滚动；房间前景绕开当前活动遮挡/折叠保留区域，消息区随可用高度收缩；背景仍铺满。
- AI 头部与内容一起滚动，为键盘和输入留下空间；评论/聊天/AI/客服的多行输入避免胶囊两端裁字；短视频详情长文案可滚动。
- 删除各页多余常驻说明；必要的草稿、服务和支付状态保留在相应内容或操作反馈中。相机用途字符串同步到 project.yml，避免重新生成工程时恢复 preview 文案。
- 修正文档中已经过时的“前景全部忽略安全区”要求，防止后续再次引入上下遮挡。

## 图片文字处理（后续已修正）

旧 `checkin.imageset/art.png` 和用户原始素材保留不动。新增 `checkin-copy`，通过 Host-Native 图像工具仅请求将副标题 **Local rewards for your daily visit.** 改为 **Rewards for your daily visit.**，保留原插画构图；生成结果已目视检查，签到页面已改用文案修正版。提示词与来源见 `ProjectMaterials/GeneratedUI/checkin-copy-prompt.md`。生成局部编辑不等同于像素级保真声明。

## 静态检查结果与边界

- 本轮前后 654 个 UI、内容与运行时资源文件 SHA-256 相同。
- Swift 字面量直接引用的 67 个图片名称都存在对应 imageset；动态映射沿用既有资源。
- 内容清单仍为 10 段短视频、6 段直播间视频、10 个房间封面映射；没有重新分配或覆盖用户媒体。
- Info.plist 相机用途文案与 project.yml 一致；JSON 可读取；git diff --check 无空白错误。
- 按当前 SDK 声明和 [Apple ViewThatFits 文档](https://developer.apple.com/documentation/swiftui/viewthatfits)、[ReservedRegion 文档](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:)) 检查容器布局用法。未引入未经检查的新设备尺寸，也没有因尺寸变化重置播放器/导航业务身份。
- 未做编译、模拟器、真机、键盘、RTL、大字体、视频解码、开合姿态或线上服务验证。设计图与源代码核对不等于修改后像素完全一致或设备无遮挡验收。

## 逐图记录

“保持”表示本轮没有从设计图与源码对照中发现需要新增修改的结构项，不代表运行验收通过。空数据与不可用服务继续按实际状态显示。

| 参考图 | 蓝湖画板 | 源码及处理 |
| --- | --- | --- |
| [01](01.webp) | 语音房-Voice | `RoomPanels.swift`：房型行改为紧凑字体、8 点圆角；移除重复说明，保留当前标记。 |
| [02](02.webp) | 语音房-加入麦克风 | `FoodRooms.swift`：去掉重复权限说明，保留权限结果和真实系统授权。 |
| [03](03.webp) | 语音房-礼物 | `FoodRooms.swift`：复用同一礼物面板，图片适应列宽，操作区可滚动到达。 |
| [04](04.webp) | 语音房（房内） | `FoodRooms.swift / RoomPanels.swift`：移除额外房间标题和 Room highlights 条；消息区域按可用高度收缩，保留分类动效及发言/礼物。 |
| [05](05.webp) | 语音房间背景 | `FoodRooms.swift / RoomPanels.swift`：保持原舞台/图标/布局入口；共用房间前景及可滚动面板修正。 |
| [06](06.webp) | 直播-礼物 | `FoodRooms.swift`：保留两行四列原礼物；余额和操作条在窄容器分行；原礼物账本和提交回调保持。 |
| [07](07.webp) | 直播-pk | `FoodRooms.swift / RoomPanels.swift`：保持原舞台/图标/布局入口；共用房间前景及可滚动面板修正。 |
| [08](08.webp) | 直播 | `FoodRooms.swift / RoomPanels.swift`：前景与全屏视频背景分离；姓名/城市限行，消息区域按容器高度收缩。 |
| [09](09.webp) | 排行榜 | `Discovery.swift`：空态压缩为一句；保留原背景和分类，不造榜单。 |
| [10](10.webp) | 搜索 | `Discovery.swift`：保持搜索/筛选结构；共用卡片、按钮和弹层的修正。 |
| [11](11.webp) | 语音房-功能入口 | `FoodRooms.swift / RoomPanels.swift`：保持原舞台/图标/布局入口；共用房间前景及可滚动面板修正。 |
| [12](12.webp) | 首页-筛选 | `Discovery.swift`：保持搜索/筛选结构；共用卡片、按钮和弹层的修正。 |
| [13](13.webp) | 首页-关注 | `Discovery.swift`：复用首页卡片修正；保持主动关注过滤。 |
| [14](14.webp) | 语音房-关注 | `Discovery.swift`：复用语音卡片的上伸标签留白。 |
| [15](15.webp) | 语音房-成员 | `RoomPanels.swift`：同一紧凑人物面板，避免三行信息挤压底部操作。 |
| [16](16.webp) | ai美食师 | `PeopleAndChat.swift`：头图区随内容滚动；保留白色圆角面板；移除 examples 和常驻未接入气泡，保存后反馈实际状态。 |
| [17](17.webp) | 我的钱包-充值 | `AccountPages.swift / RechargeOptions.swift`：余额文字为右侧原插画留空间；九宫格状态单行，删除重复说明。 |
| [18](18.webp) | 邀请码 | `AccountPages.swift`：删除末尾重复提示；不可用邀请码和禁用分享仍明确。 |
| [19](19.webp) | 客服支持-展开 | `SupportAndPreferences.swift`：保持原横幅、描边搜索、FAQ 条目及固定底部入口。 |
| [20](20.webp) | 我的等级 | `AccountPages.swift`：姓名限制两行并避让右上角原徽章。 |
| [21](21.webp) | 粉丝 | `PeopleAndChat.swift`：保持原行/表单/弹层结构，沿用通用按钮的文字适应和滚动容器。 |
| [22](22.webp) | 每日签到 | `AccountPages.swift`：金币网格和领取状态保持；后续已接入去除 Local 的文案修正版，调整头图裁切、日期角标与下一日高亮。 |
| [23](23.webp) | 黑名单 | `AccountPages.swift`：保持原图、描边布局和真实库存/名单状态。 |
| [24](24.webp) | 设置 | `AccountPages.swift`：删除底部长段技术说明；原描边行和偏好功能保持。 |
| [25](25.webp) | 切换语言-弹窗 | `TatiComponents.swift`：原纸张底板；短内容居中，容器高度不足时滚动，确认/取消逻辑保持。 |
| [26](26.webp) | 编辑资料 | `PeopleAndChat.swift`：保持原行/表单/弹层结构，沿用通用按钮的文字适应和滚动容器。 |
| [27](27.webp) | 切换语言 | `SupportAndPreferences.swift`：补齐选中行的浅绿底色；保留选择确认，移除常驻技术说明。 |
| [28](28.webp) | 评论 | `FoodVideos.swift`：多行输入改圆角矩形并留竖向内边距；草稿未发布状态保留。 |
| [29](29.webp) | 用户主页 | `PeopleAndChat.swift`：姓名与国家分行，避免与头像和礼物按钮互相挤压。 |
| [30](30.webp) | 用户主页-弹窗 | `PeopleAndChat.swift`：保持原行/表单/弹层结构，沿用通用按钮的文字适应和滚动容器。 |
| [31](31.webp) | 马上发布 | `FoodVideos.swift`：沿用原视频封面和 Change video 图片，精简说明，保留文案计数。 |
| [32](32.webp) | 发布视频 | `FoodVideos.swift`：删除重复的收藏/发布说明，保留真实保存按钮及结果反馈。 |
| [33](33.webp) | 直播+发布 | `FoodVideos.swift`：保持原创建入口/封面/标签，表单内容可滚动、底部操作独立。 |
| [34](34.webp) | 去开直播 | `FoodVideos.swift`：保持原创建入口/封面/标签，表单内容可滚动、底部操作独立。 |
| [35](35.webp) | 语音房-离开房间 | `FoodRooms.swift`：删除三按钮下的重复说明，保持最小化/离开/停留。 |
| [36](36.webp) | 语音房-邀请朋友 | `RoomPanels.swift`：移除重复未接入提示，缩短空态；点击邀请仍反馈实际服务状态。 |
| [37](37.webp) | 语音房-音乐播放 | `FoodRooms.swift / RoomPanels.swift`：保持原舞台/图标/布局入口；共用房间前景及可滚动面板修正。 |
| [38](38.webp) | 语音房-房型切换 | `RoomPanels.swift`：与 Voice 共用紧凑行；选择与持久化不变。 |
| [39](39.webp) | 语音房-多位视频 | `FoodRooms.swift / RoomPanels.swift`：保留既有布局选择；房间前景复用活动保留区避让，后台服务状态未伪造。 |
| [40](40.webp) | 语音房-美食 | `Discovery.swift`：复用语音卡片的上伸标签留白。 |
| [41](41.webp) | 语音房（Party 列表） | `Discovery.swift`：为上伸的 Hot room 原图补足顶部空间，避免卡片边界裁切。 |
| [42](42.webp) | 直播-礼物充值 | `RechargeOptions.swift`：紧凑套餐行，选中标记移到角落；未知价格以 Unavailable 标明，不添加假价格。 |
| [43](43.webp) | 直播-观众列表 | `FoodRooms.swift / RoomPanels.swift`：保持原舞台/图标/布局入口；共用房间前景及可滚动面板修正。 |
| [44](44.webp) | 首页 | `Discovery.swift`：保持原双列卡片；封面姓名/城市限行，已有 Live 原图和动效保持。 |
| [45](45.webp) | 首页-发现 | `Discovery.swift`：复用首页卡片修正；排序和内容分配保持。 |
| [46](46.webp) | 美食直播logo | `TatiApp.swift / Resources`：保持已确认品牌、五个纯图标入口及原资源。 |
| [47](47.webp) | tab栏 | `TatiApp.swift / Resources`：保持已确认品牌、五个纯图标入口及原资源。 |
| [48](48.webp) | 邮箱与密码 | `TatiApp.swift`：按既定访客方案覆盖，不增加无法验证的邮箱密码表单。 |
| [49](49.webp) | 登陆-苹果 | `TatiApp.swift`：按既定访客登录方案覆盖；不恢复模拟 Apple 授权。 |
| [50](50.webp) | 登陆 | `TatiApp.swift`：移除与欢迎图重复的介绍行；已有 Tati 早餐图和同意协议/访客进入保持。 |
| [51](51.webp) | 启动 | `TatiApp.swift / Resources`：保持已确认品牌、五个纯图标入口及原资源。 |
| [52](52.webp) | 视频（详情） | `FoodVideos.swift`：长作者/文案限制在可滚动信息区；失败底色上的文字使用深色，避免白字不可读。 |
| [53](53.webp) | 我的背包 | `AccountPages.swift`：保持原图、描边布局和真实库存/名单状态。 |
| [54](54.webp) | 视频（列表） | `FoodRooms.swift / RoomPanels.swift`：保持原舞台/图标/布局入口；共用房间前景及可滚动面板修正。 |
| [55](55.webp) | 聊天 | `PeopleAndChat.swift`：窄容器工具栏分行；AnyLayout 保留输入/附件实例；删除顶部重复服务提示。 |
| [56](56.webp) | 联系客服 | `SupportAndPreferences.swift`：首条引导缩短；多行输入改圆角矩形，保留未发送草稿标识。 |
| [57](57.webp) | 我的 | `PeopleAndChat.swift`：姓名最多两行；原封面、统计条、横幅和菜单素材保持。 |
| [58](58.webp) | 发布成功 | `TatiComponents.swift / FoodVideos.swift`：共用自适应纸张弹窗，继续按实际结果显示 Video saved，不冒充上传成功。 |
| [59](59.webp) | 客服支持 | `SupportAndPreferences.swift`：保持原横幅、描边搜索、FAQ 条目及固定底部入口。 |
| [60](60.webp) | 缺省页 | `TatiComponents.swift`：保持原缺省插画和对应业务空态。 |
| [61](61.webp) | 语音房（背景面板） | `FoodRooms.swift / RoomPanels.swift`：保持原舞台/图标/布局入口；共用房间前景及可滚动面板修正。 |
| [62](62.webp) | 直播-主页 | `RoomPanels.swift`：头像缩至 60 点，姓名/城市紧凑排布；移除额外兴趣说明，按钮保持。 |
| [63](63.webp) | 反馈 | `AccountPages.swift`：移除重复的未接入说明，底部仍是 Save draft，保存结果不冒充提交。 |
