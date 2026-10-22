# 项目素材

此目录仅作为设计与素材导入来源，不自动加入 App 运行时资源。
建立 Xcode 工程时使用显式资源引用，仅导入筛选后的运行时副本。

- `DesignReferences/`：设计截图、导出稿、页面说明。已保存用户提供的总览图。
- `UIAssets/`：原稿配套图标、按钮、背景、装饰、字体及许可说明。
- `ContentImages/`：头像、人物大图、相册、内容图片；请按用户或内容 ID 标明归属。
- `ContentVideos/`：视频及明确配对的封面；请按内容 ID 标明归属。

素材可以分批补充。未提供的人物图片和视频不从网络随机下载；内容占位统一管理。


## 已实施

Tati 原生工程已建立。UI 副本由 Scripts/import_assets.py 按 runtime-mapping.json 导入。GeneratedUI 保存 Tati 品牌文字局部适配和缺失图标补充；不修改 UIAssets 原图。

2026-10-20：49 张图片与 16 段视频已经逐一分配并显式导入。原始文件保留原名与内容，准确对应关系见 content-slots.json，逐项清单与检查证据见 DesignReferences/ContentAudit/README.md。Scripts/import_content.py 将照片和原片副本放入独立运行时资源，并从原片提取封面；ProjectMaterials 本身不打包。

2026-10-22：内容素材改为按原文件名从用户指定的 R2 `photo/` 与 `videos/` 目录加载。`content-slots.json` 保存全部 65 个原文件的 `remoteURL`；应用元数据仅包含原有在用内容，保留既有暂缓展示标记。`Scripts/import_content.py` 现在只生成链接映射，不再复制照片、视频或封面到 App。旧运行时副本保留在 `PackagedMediaArchive/`，不进入应用资源。原始 `ContentImages/`、`ContentVideos/` 内容不变。详见 `Documentation/Hosted-content-media.md`。
