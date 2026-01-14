# LuaDevTemplate

这是一个面向 Vela/QuickApp 的表盘 Lua 模板。QuickApp 源码仍放在 `src/`，表盘 Lua 相关内容在 `watchface/`。

## 目录结构

- `src/` 快应用源码
- `watchface/lua/main.lua` 设备侧热更新入口
- `watchface/lua/app/app/lua/main.lua` 表盘 UI 入口
- `watchface/lua/app/*.fprj` 表盘工程文件
- `watchface/lua/app/images/preview.png` 预览图
- `watchface/data/preview.bin` 由 preview.png 生成
- `watchface/data/resource.bin` 由 .face 拷贝生成
- `watchface/data/watchface_list.json` 从设备拉取并改写后再推回
- `bin/` 输出的 .face

## 配置

`watchface.config.json` 是唯一入口：

- `projectName` 模板名称（影响 .face / .fprj）
- `watchfaceId` 设备用 ID（Int32 范围）
- `resourceBin` 控制 preview.bin 生成（lvgl v8/v9、色深、压缩、输入图）

`watchface/lua/config.lua` 由 `scripts/internal/sync_watchface_config.ps1` 生成。

## 任务（VSCode）

- `给真机构建.face`
- `全新部署（生成preview+同步watchface列表配置）`
- `热部署（仅同步Lua代码）`
- `生成 watchfaceId`

## 建议流程

1. 修改 `watchface.config.json`。
2. 需要新 ID 时运行 `生成 watchfaceId`。
3. 日常调试用 `热部署（仅同步Lua代码）`。
4. 完整推送资源时用 `全新部署（生成preview+同步watchface列表配置）`。
5. 需要打包时用 `给真机构建.face`。

## 依赖

- `adb` 在 PATH
- Python 3（`watchface/tools/LVGLImage*.py`）
- `pngquant`（LVGL v9 预览转换）
- `watchface/tools/Compiler.exe`

## 设备目录（部署后）

```
/data/app/watchface/market/<watchfaceId>/
  lua/
    main.lua
    config.lua
    app/
      lua/
        main.lua
  .hotreload/
```
