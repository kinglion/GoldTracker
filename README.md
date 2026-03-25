# GoldTracker

一款 macOS 原生桌面小组件，实时追踪工行纸黄金价格，支持价格提醒通知。

## 功能特性

- **实时金价**：从中国工商银行官网抓取纸黄金最新报价
- **桌面小组件**：通过 macOS 桌面 Widget 随时查看金价，无需打开 App
- **价格提醒**：可设置目标价格，达到时自动发送系统通知
- **手动刷新**：小组件内置刷新按钮，点击即可立即更新价格
- **自动更新**：每 15 分钟自动刷新一次（受系统限制）

## 截图

> 小组件展示工行纸黄金当前报价（元/克），并显示最后更新时间。

## 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Xcode 14.0+
- Swift 5.7+

## 快速开始

### 1. 克隆项目

```bash
git clone git@github.com:kinglion/GoldTracker.git
cd GoldTracker
```

### 2. 用 Xcode 打开

```bash
open GoldTracker.xcodeproj
```

### 3. 构建并运行

1. 在 Xcode 中选择 `GoldTracker` Scheme
2. 按 `Cmd+R` 运行主 App（首次运行会请求通知权限）

### 4. 添加小组件

1. 在 macOS 桌面右键 → **编辑小组件**
2. 点击 `+` 号，搜索 **GoldTracker**
3. 选择 **实时金价** 小组件添加到桌面

### 5. 配置价格提醒（可选）

- 长按桌面上的小组件 → **编辑小组件**
- 开启「开启全局通知」开关
- 填写「提醒目标价（元/克）」
- 当金价达到或超过目标价时，自动弹出系统通知

## 项目结构

```
GoldTracker/
├── GoldTracker/                    # 主 App Target
│   ├── GoldTrackerApp.swift        # App 入口，申请通知权限
│   ├── ContentView.swift           # 占位界面
│   └── Assets.xcassets/            # App 图标资源
│
├── GoldWidget/                     # Widget Extension Target
│   ├── GoldWidget.swift            # 核心逻辑（数据获取、解析、UI）
│   ├── GoldWidgetBundle.swift      # Widget 注册入口
│   └── Assets.xcassets/            # Widget 图标与背景资源
│
└── GoldTracker.xcodeproj/          # Xcode 工程文件
```

## 技术实现

| 技术 | 用途 |
|------|------|
| SwiftUI | 小组件 UI 构建 |
| WidgetKit | macOS 桌面小组件框架 |
| App Intents | 手动刷新按钮 & 用户配置面板 |
| UserNotifications | 系统通知推送 |
| URLSession | HTTP 网络请求 |
| GB18030 | 解码工行网页的 GBK 编码 |
| NSRegularExpression | 从 HTML 中提取金价数据 |

### 数据来源

金价数据来自工商银行纸黄金页面：

```
https://mybank.icbc.com.cn/icbc/newperbank/perbank3/gold/goldaccrual_query_out.jsp
```

通过正则表达式匹配页面中 `id="activeprice_*"` 元素提取实时报价。

## 开发说明

### Widget 刷新机制

- WidgetKit 在 macOS 上最短刷新间隔为 **15 分钟**（系统强制限制）
- 用户可通过小组件内的刷新按钮触发即时刷新
- 每次刷新后，下次自动刷新时间重新计算

### 编码处理

工行网页采用 GBK（GB18030）编码，App 优先使用 `GB_18030_2000` 解码，若失败则回退到 UTF-8。

## License

MIT License
