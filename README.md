# Tati

原生 SwiftUI 美食社区应用，最低 iOS 17，现有五个入口为 Home、Room、Video、Cooking notes、Me。保留原创 Tati 资源、两套本地字体、已有用户编辑/草稿/钱包持久化与原生媒体所有者。

2026-10-22 已接入 Prada：App ID `48859669`，接口域名 `https://api.afterhou.top`。当前接口、路由、支付与服务边界见 [接入记录](Docs/BackendAPI/Integration.md)。

导入文件只有两份：

- [接口模板-48859669.json](Docs/BackendAPI/generated/接口模板-48859669.json)
- [配置模板-48859669.json](Docs/BackendAPI/generated/配置模板-48859669.json)

在控制台选择上述 App，导入两份文件并校验保存。完整初始展示数据通过三组 POST JSON 接口加载，失败提供重试，不使用包内数据兜底。保留 49 张图片和全部 16 段视频的原 R2 链接，10 段用于视频列表、6 段用于房间。此前按用户要求删除的本地内容原件/备份不会重建；原创 UI、字体及用户自行导入的媒体继续按各自用途保留。

`Tati.xcodeproj` 的 scheme 为 `Tati`；`project.yml` 是 XcodeGen 配置源。Alamofire 依赖已解析并锁定；本次没有编译、测试或运行应用，也没有调用业务接口或发起购买。源码静态核对不等于实际服务、设备效果或审核结论。

离线检查：

```sh
python3 Scripts/inspect_table_integration.py
python3 Scripts/inspect_kitchen_delivery.py
python3 Scripts/inspect_hosted_media.py
```

`Scripts/import_content.py` 现在只更新 Docs 中的部署 catalog；更新后按接入记录重新生成两份模板。没有内容图片/视频的本地打包兜底。

一键认证、原生 WebSocket、同会话 WKWebView、APNs 回调、先结束 Apple 交易再单次确认的调用链已接到现有页面/服务。固定展示 JSON 不提供真人直播、RTC、聊天送达、举报受理、审核后台或跨设备钱包。既有房间媒体/送礼特效、待发布内容及消息草稿的真实边界仍保留，详情见接入记录。

原创素材来源与设计参考仍在 `ProjectMaterials`。过期页面改动说明、衍生预览和开发缓存已清理。用户指定的协议页内容与链接保持原样；当前接口及支付行为以接入记录为准。
