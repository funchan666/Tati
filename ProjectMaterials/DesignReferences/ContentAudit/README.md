# Tati 内容素材接入清单

日期：2026-10-20。用户要求所有素材都使用，并授权自行分配。

已查看 49 张图片，以及 16 段视频各三个位置的抽帧。49 张图片分别绑定一个稳定的示例资料 ID；保持原六个示例 ID，再新增 43 个资料。多人合照采用组合示例名称，不通过人脸推断身份，也不把多张照片判断为同一个真人。名字、地区和兴趣属于示例配置，不是对照片中真人的身份认定。

16 段视频按可见内容命名，保留 Tati collection 内容归属；其中 10 段用于短视频列表，6 段分配给全部视频直播间作为循环播放画面。没有照片与视频人物对应说明，因此房间示例主持人的配置不代表照片与视频属于同一真人。所有原片原样复制，封面来自各自视频约 10% 处的实际画面，不用静态图冒充视频。

## 页面入口

- Home → 右上搜索 → People：可浏览全部 49 个资料；进入资料可查看照片，点击照片可看完整比例。
- 资料头像同步到搜索、关注、聊天、黑名单和房主面板；8 个已有房间封面复用各自房主图片。
- Video：10 段内置视频进入列表，支持卡内播放、详情、点赞和评论草稿；搜索中的 Videos 同样可查找。
- Home / 搜索 Rooms：新增 `soup-kitchen`（V09）和 `crepe-station`（V12），使用原片封面及循环播放画面。视频直播间从 4 个增至 6 个，语音房保持 4 个；原有 4 个直播间也分别绑定 V06、V08、V04、V02，封面保持不变。6 段房间视频均不再重复出现在短视频列表。当前仍为本地素材播放，未接实时直播服务。
- 保持五个纯图标 Tab、本地访客、送礼入口和既有读写契约；不会自动关注或创建伪造观众。

## 静态检查结果

- 原始素材 65/65 已显式映射，未使用/遗漏文件数 0。49 张图片副本、16 段视频副本与原文件 SHA-256 相同。
- 16 张视频封面可解码；独立 TatiContent.xcassets 共 65 个 imageset，无重名或悬空图片引用。
- 18 个 Swift 源文件、两个 Asset Catalog、content-library.json 和全部 16 个 MP4 有 target 引用。
- 原 UIAssets 与 TatiArtwork.xcassets 合计 436 个文件哈希保持一致。
- ProjectMaterials、审计联系表、脚本和原始下载文件没有被自动加入应用包。
- 所有视频文件元数据显示 H.264、720×1280；这不是 iOS 解码与播放验收。
- 新增内容资源源文件约 148.91 MiB；全部运行时资源源文件约 168.99 MiB。保留所有原片，没有为压体积删内容；未构建，因此没有 IPA/下载体积数据。
- 未编译、未测试、未运行 App、模拟器或设备；未宣称实际布局、播放流畅度或折叠姿态通过。

## 图片分配（每份均可从 People 进入）

| 编号 | 原始文件 | 示例资料 | 运行时素材 |
| --- | --- | --- | --- |
| I01 | `828776562_18110484950019933_1274418079164789390_n.jpg` | Luna / `creator-luna` | `portrait-01`：头像＋主页照片 |
| I02 | `829054808_18157222810512696_1511540759907490784_n.jpg` | Avery / `portrait-02` | `portrait-02`：头像＋主页照片 |
| I03 | `829310825_18627363997010758_4506985276544211277_n.jpg` | Rowan / `portrait-03` | `portrait-03`：头像＋主页照片 |
| I04 | `829602854_18637273639035454_7863518920919092101_n.jpg` | André / `creator-andre` | `portrait-04`：头像＋主页照片 |
| I05 | `829711039_18587777635069401_6858970808061207273_n.jpg` | Trail Friends / `portrait-05` | `portrait-05`：头像＋主页照片 |
| I06 | `829973023_18633178075060794_6462288533902213791_n.jpg` | Ellis / `portrait-06` | `portrait-06`：头像＋主页照片 |
| I07 | `830272061_18655744786032706_2790915464625276229_n.jpg` | Jamie / `portrait-07` | `portrait-07`：头像＋主页照片 |
| I08 | `831424277_18490614706105805_849108897253351104_n.jpg` | Morgan / `portrait-08` | `portrait-08`：头像＋主页照片 |
| I09 | `834317533_18132112789784995_6704606860262801293_n.jpg` | Quinn / `portrait-09` | `portrait-09`：头像＋主页照片 |
| I10 | `836248660_18393126976167387_8090635735672246557_n.jpg` | Riley / `portrait-10` | `portrait-10`：头像＋主页照片 |
| I11 | `836787533_18033720395890693_6120712375957738863_n.jpg` | Beach Table / `portrait-11` | `portrait-11`：头像＋主页照片 |
| I12 | `837632427_18632650270011107_4403921076513325941_n.jpg` | Chloe / `creator-chloe` | `portrait-12`：头像＋主页照片 |
| I13 | `838658775_18646835638060210_5169025348299645935_n.jpg` | Blair / `portrait-13` | `portrait-13`：头像＋主页照片 |
| I14 | `838985333_18107305592192461_2116322463346817209_n.jpg` | Cameron / `portrait-14` | `portrait-14`：头像＋主页照片 |
| I15 | `839179549_18641471329031914_5481253250148838365_n.jpg` | Reese / `portrait-15` | `portrait-15`：头像＋主页照片 |
| I16 | `839589735_18435631513194537_5962308028115092182_n.jpg` | Finley / `portrait-16` | `portrait-16`：头像＋主页照片 |
| I17 | `839617909_18636140752036257_2098987833378784333_n.jpg` | Jordan / `portrait-17` | `portrait-17`：头像＋主页照片 |
| I18 | `840900763_18629218363016458_6769438208836358437_n.jpg` | Alex / `portrait-18` | `portrait-18`：头像＋主页照片 |
| I19 | `841865648_18565415170078011_7354168267474431641_n.jpg` | Harper / `portrait-19` | `portrait-19`：头像＋主页照片 |
| I20 | `843116921_18637496905042936_171745215508899891_n.jpg` | Drew / `portrait-20` | `portrait-20`：头像＋主页照片 |
| I21 | `843205753_18632792290036679_8602263243103834282_n.jpg` | Taylor / `portrait-21` | `portrait-21`：头像＋主页照片 |
| I22 | `843838416_18120983045289691_4899054224201084247_n.jpg` | Parker / `portrait-22` | `portrait-22`：头像＋主页照片 |
| I23 | `844190190_18636426934039263_6884579072562259791_n.jpg` | Skyler / `portrait-23` | `portrait-23`：头像＋主页照片 |
| I24 | `844340780_18638813539054188_3830060607232740863_n.jpg` | Charlie / `portrait-24` | `portrait-24`：头像＋主页照片 |
| I25 | `844394608_18634550761055018_7929487706353879535_n.jpg` | River / `portrait-25` | `portrait-25`：头像＋主页照片 |
| I26 | `844417632_18635528491056541_3211862696628029101_n.jpg` | Casey / `portrait-26` | `portrait-26`：头像＋主页照片 |
| I27 | `845426207_18030181799887168_6154182754476216077_n.jpg` | Robin / `portrait-27` | `portrait-27`：头像＋主页照片 |
| I28 | `846612204_18468348052140978_4703040474988332638_n.jpg` | Blake / `portrait-28` | `portrait-28`：头像＋主页照片 |
| I29 | `846809318_18638088085046648_7081383790175278758_n.jpg` | Hayden / `portrait-29` | `portrait-29`：头像＋主页照片 |
| I30 | `847939309_18497838286108045_8543151347112222288_n.jpg` | Arden / `portrait-30` | `portrait-30`：头像＋主页照片 |
| I31 | `848186636_18634657000034456_1849772215626504826_n.jpg` | Marley / `portrait-31` | `portrait-31`：头像＋主页照片 |
| I32 | `848196762_18596616184067882_5040749258115402944_n.jpg` | Remy / `portrait-32` | `portrait-32`：头像＋主页照片 |
| I33 | `848350979_18117800251966463_4246244980606132227_n.jpg` | Elowen / `creator-elowen` | `portrait-33`：头像＋主页照片 |
| I34 | `848455291_18632687518006554_3359078306032398090_n.jpg` | Frankie / `portrait-34` | `portrait-34`：头像＋主页照片 |
| I35 | `848570268_18640427161053528_7037236695005080667_n.jpg` | Jules / `portrait-35` | `portrait-35`：头像＋主页照片 |
| I36 | `848787245_18641211943061805_9184416787013129240_n.jpg` | Lane / `portrait-36` | `portrait-36`：头像＋主页照片 |
| I37 | `848993977_18648226450040978_509925620388878282_n.jpeg` | Maria / `creator-maria` | `portrait-37`：头像＋主页照片 |
| I38 | `849249060_18491159053111288_3983019166277374001_n.jpg` | Shiloh / `portrait-38` | `portrait-38`：头像＋主页照片 |
| I39 | `849379197_18634841125034320_7118850056566480884_n.jpg` | Milan / `portrait-39` | `portrait-39`：头像＋主页照片 |
| I40 | `849477563_18644804980020391_7819057180524614658_n.jpg` | Dakota / `portrait-40` | `portrait-40`：头像＋主页照片 |
| I41 | `849550952_18647420800054373_7823618734353762798_n.jpg` | Scout / `portrait-41` | `portrait-41`：头像＋主页照片 |
| I42 | `849772940_18633906298015460_6434628501364025450_n.jpg` | Seraphina / `creator-seraphina` | `portrait-42`：头像＋主页照片 |
| I43 | `849773126_18639655996046648_3371346672247127660_n.jpg` | Kendall / `portrait-43` | `portrait-43`：头像＋主页照片 |
| I44 | `849891055_18637263916055018_725435053853064446_n.jpg` | Rory / `portrait-44` | `portrait-44`：头像＋主页照片 |
| I45 | `849951132_18645365749035248_82605801469605953_n.jpg` | City Duo / `portrait-45` | `portrait-45`：头像＋主页照片 |
| I46 | `851150067_18452401138123730_8650624205739965452_n.jpg` | Linden / `portrait-46` | `portrait-46`：头像＋主页照片 |
| I47 | `851150069_18644948692026015_1961800893533170202_n.jpg` | Reagan / `portrait-47` | `portrait-47`：头像＋主页照片 |
| I48 | `856125458_18634475317010758_476292385336594519_n.jpg` | Oakley / `portrait-48` | `portrait-48`：头像＋主页照片 |
| I49 | `858594027_18637182445035158_2943445897430238107_n.jpg` | Wren / `portrait-49` | `portrait-49`：头像＋主页照片 |

## 视频分配（6 段用于房间，其余 10 段进入 Video 与搜索）

| 编号 | 内容 | 运行时视频 | 时长 |
| --- | --- | --- | --- |
| V01 | A generous sandwich in Osaka | `collection-osaka-sandwich.mp4` | 21.5 秒 |
| V02 | A sweet bake, from pan to plate → `sweet-evening` 房间 | `collection-bakery-dessert.mp4` | 94.5 秒 |
| V03 | A little cafe break | `collection-cafe-break.mp4` | 7.1 秒 |
| V04 | Crunchy bites at the kitchen counter → `kitchen-stories` 房间 | `collection-crispy-bites.mp4` | 19.4 秒 |
| V05 | Noodles at an outdoor table | `collection-outdoor-noodles.mp4` | 120.2 秒 |
| V06 | A toasted sandwich, packed with flavour → `pasta-table` 房间 | `collection-toasted-sandwich.mp4` | 32.2 秒 |
| V07 | A creative mixing experiment | `collection-creative-mix.mp4` | 14.3 秒 |
| V08 | A table full of street-food flavours → `street-bites` 房间 | `collection-street-food-table.mp4` | 77.2 秒 |
| V09 | A look inside a busy kitchen → `soup-kitchen` 房间 | `collection-kitchen-soup.mp4` | 51.6 秒 |
| V10 | Folding and cooking homemade dumplings | `collection-dumplings.mp4` | 40.5 秒 |
| V11 | A lively evening around the dinner table | `collection-dinner-friends.mp4` | 17.6 秒 |
| V12 | Fresh crepes on the griddle → `crepe-station` 房间 | `collection-crepe-making.mp4` | 41.8 秒 |
| V13 | A quiet break on the trail | `collection-trail-break.mp4` | 14.8 秒 |
| V14 | Everyday moments with friends | `collection-everyday-moments.mp4` | 13.1 秒 |
| V15 | An outdoor noodle tasting | `collection-noodle-tasting.mp4` | 68.6 秒 |
| V16 | Cooking together in the kitchen | `collection-cooking-together.mp4` | 10.4 秒 |

逐文件原始路径、哈希、内容 ID、封面及使用位置见 [content-slots.json](../../content-slots.json)。图片索引见 images-1.jpg 至 images-3.jpg；视频抽帧索引见 videos-1.jpg、videos-2.jpg。

## 导入与后续维护

`python3 Scripts/import_content.py` 读取已审核的明确映射，复制原媒体并提取真实封面。输入新增、缺失或哈希变化会中止导入，需要先更新对应映射；不会任意跳过文件。新增代码或资源后执行 `xcodegen generate` 仅更新工程文件，不是编译。

现有本地访客的导入媒体仍从 Application Support/Media 读取；内置影片只从 Bundle 读取。删除用户资料或自导入视频不会删除内置内容。新增 FoodClip 可选字段兼容旧本地记录。

## Duo 相关静态适配范围

使用 UI Design Reference、UI Taste、JPG 和 Duo；此次内容接入不需要网页风格变更或新增生成艺术。已读取当前 Xcode.app 版本与 SDK 文件：Xcode 27.1 / iPhoneOS 27.1，最低部署仍为 iOS 17。

参照 [Apple 的 Duo 准备指南](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo) 和 [reservedRegions API](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:))，并查看本机 SwiftUI SDK 声明。新增照片使用容器尺寸裁切；完整照片和独立视频播放器及叠加控件在 iOS 27.1 查询活动 division/occlusion 区域，选择可用区域展示，旧系统沿用当前容器。未按机型硬编码尺寸，未以尺寸变化重建播放器或账户。

本次没有改登录、支付、相机采集、多 scene 或全局导航布局；原前景保持系统安全区，背景才延伸。固定弹层、全局自定义栏和采集页面的全部 Duo 姿态仍需独立适配审查与实际设备验收，不能据此宣称整包完成 Duo 验收。实际构建此新 API 代码需支持对应声明的 Xcode 27.1 或更新 SDK。
