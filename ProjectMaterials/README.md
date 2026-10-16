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

人物和视频的建议命名及归属见 content-slots.json。仍可使用你原来的文件名，只需补充与角色/房间的对应关系。放入原始素材目录后还需要显式导入，不会将目录整体打包。
