# LuaDevTemplate

这是一个面向 Vela/QuickApp 的表盘 Lua 模板。QuickApp 源码仍放在 `src/`，表盘 Lua 相关内容在 `watchface/`。

## 目录结构

- `src/` 快应用源码
- `watchface/data` 缓存数据（用于在虚拟机安装表盘）
- `watchface/lua` 重载器代码和表盘项目
- `watchface/lua/fprj` 表盘项目
- `watchface/lua/fprj/app` 最终放到实机的目录（代码依赖的资源应该在这里）
- `watchface/lua/fprj/app/lua` 运行在实机的代码
- `watchface/tools` 表盘相关工具
- `bin/` 表盘的编译产物 .face （实机可用）
- `scripts/` 表盘任务脚本

## 说明

真正在实机上运行的部分只有`fprj`文件夹下面的内容
请不要修改`watchface/lua`文件夹下面的下面的`main.lua`这是重载器代码

## 配置

`watchface.config.json` 是唯一入口：

- `projectName` 模板名称（影响 .face / .fprj）
- `watchfaceId` 设备用 ID（Int32 范围）
- `resourceBin` 控制 preview.bin 生成（lvgl v8/v9、色深、压缩、输入图）

`watchface/lua/config.lua` 由 `scripts/internal/sync_watchface_config.ps1` 生成，不要自行修改。

## 任务（VSCode）

![步骤1](./1.png)
![步骤2](./2.png)
![步骤3](./3.png)

## 建议流程

1. 修改 `watchface.config.json`。
2. 需要新 ID 时运行 `生成表盘ID`。
3. 日常调试用 `热重载`。
4. 完整推送资源时用（修改了代码以外的部分，） `全新部署`。
5. 需要打包时用 `构建表盘二进制`。

## 依赖

- `adb` 在 PATH
- Python 3（`watchface/tools/LVGLImage*.py`）
- `pngquant`（LVGL v9 预览转换）
- `watchface/tools/Compiler.exe`

## 虚拟机设备目录（部署后）

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
