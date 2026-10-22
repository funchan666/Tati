# 项目素材

此目录仅作为设计与素材导入来源，不自动加入 App 运行时资源。
建立 Xcode 工程时使用显式资源引用，仅导入筛选后的运行时副本。

- `DesignReferences/`：设计截图、导出稿、页面说明。已保存用户提供的总览图。
- `UIAssets/`：原稿配套图标、按钮、背景、装饰、字体及许可说明。
- `content-slots.json`：49 张人物图与 16 条视频的链接、原文件名、历史校验信息和内容归属；本地原件已删除。

素材可以分批补充。未提供的人物图片和视频不从网络随机下载；内容占位统一管理。


## 已实施

Tati 原生工程已建立。UI 副本由 Scripts/import_assets.py 按 runtime-mapping.json 导入。GeneratedUI 保存 Tati 品牌文字局部适配和缺失图标补充；不修改 UIAssets 原图。

2026-10-20：49 张图片与 16 段视频已经逐一分配并显式导入。原始文件保留原名与内容，准确对应关系见 content-slots.json，逐项清单与检查证据见 DesignReferences/ContentAudit/README.md。Scripts/import_content.py 将照片和原片副本放入独立运行时资源，并从原片提取封面；ProjectMaterials 本身不打包。

2026-10-22：内容素材改为按原文件名从用户指定的 R2 `photo/` 与 `videos/` 目录加载。16 条视频全部启用：视频列表 10 条、房间内 6 条。随后按用户明确要求，已删除 `ContentImages/`、`ContentVideos/`、`PackagedMediaArchive/`、`ContentReviewHold/` 及内容检查抽帧和联系表图片。仅保留 `content-slots.json` 中的链接、原文件名、历史 SHA-256 与字节数；导入和核对脚本不再依赖本地内容文件。UI 原图、原创界面素材、字体和文字检查记录继续保留。详见 `Documentation/Hosted-content-media.md` 与 `Documentation/Local-content-cleanup.json`。
