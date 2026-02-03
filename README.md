# LuaDevTemplate

Vela/QuickApp 表盘 Lua 开发模板。

## 目录结构

- `watchface/fprj/` 表盘项目（用户只需关注这里）
  - `app/` 最终释放到实机的内容
    - `lua/main.lua` 表盘入口代码
    - `lua/` 其他 Lua 模块
    - `images/` 图片等资源
  - `*.fprj` 项目元数据
- `watchface/data/` 缓存数据（用于在虚拟机安装表盘）
- `watchface/tools/` 表盘相关工具
- `bin/` 表盘编译产物 .face（实机可用）
- `scripts/` 任务脚本及热重载器

## 说明

运行 `pip install -r requirements.txt` 安装依赖（必做）

用户只需在 `watchface/fprj/app/` 下编写代码和放置资源，目录结构与真机一致。热重载器由推送脚本自动注入，开发时完全透明。

## 配置

`watchface.config.json` 是唯一入口：

- `projectName` 模板名称（影响 .face / .fprj）
- `watchfaceId` 设备用 ID（Int32 范围）
- `power_consumption` 功耗等级（1-3）
- `resourceBin` 控制 preview.bin 生成（lvgl v8/v9、色深、压缩、输入图）

 `Xiaomi Watch S3`以及`Xiaomi Band 8P`仅支持 lvgl v8，生成preview.bin时请在`watchface.config.json`将`lvglVersion`改为`8`

## 任务

![步骤1](./1.png)

![步骤2](./2.png)

![步骤3](./3.png)

你也可以给`运行任务`添加快捷键

打开：`文件-首选项-键盘快捷方式`，或者同时按下：`Ctrl+K+S`三个按键。此时会进入热键设置页面，在搜索栏搜索`workbench.action.tasks.runTask`或者`任务: 运行任务`，选中并设置一个你习惯的组合式快捷键。

## 建议流程

1. 修改 `watchface.config.json`。
2. 需要新 ID 时运行 `生成表盘ID`。
3. 在 `watchface/fprj/app/` 下编写代码和放置资源。
4. 日常调试用 `热重载`。
5. 完整推送资源时用（修改了代码以外的部分） `全新部署`。
6. 需要打包时用 `构建表盘二进制`。

## 虚拟机设备目录（部署后）

```
/data/app/watchface/market/<watchfaceId>/
  lua/
    main.lua          ← 重载器（自动注入）
    _app_main.lua     ← 用户代码（从 fprj/app/lua/main.lua 重命名）
    *.lua             ← 用户其他模块
    config.lua
  images/             ← 资源文件
  .hotreload/
```

与真机释放的目录结构一致（真机上 `main.lua` 即用户代码，无重载器）。

## 依赖

- Python 3
