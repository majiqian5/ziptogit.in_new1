# 律动播放器 PlayerPulse

锁屏与控制中心「正在播放」播放器的美化插件：多彩频谱、按钮缩放、字体颜色/字号、播放器缩放、专辑圆角与专辑封面模糊背景。

- 包名：`com.axs.playerpulse`
- 目标进程：`com.apple.springboard`
- 最低系统：iOS 16.0（按 iOS 16.5 的 MediaRemoteUI 结构适配）
- 打包环境：Rootful / Rootless / Roothide（默认脚本构建 Rootless）

## 功能

| 模块 | 能力 |
|---|---|
| 多彩频谱 | 绘制在专辑封面底部，跟随播放时间轴按节拍律动；柱状/波形两种样式，五种配色，可调条数、高度、不透明度、速度 |
| 按钮 | 统一缩放上一首、播放/暂停、下一首图标（0.6x–1.5x） |
| 字体 | 标题/副标题自定义颜色（`#RRGGBB` / `#RRGGBBAA`）与字号，留空/0 跟随系统 |
| 播放器 | 锁屏播放器整体缩放（0.8x–1.15x）、背景圆角、专辑封面圆角 |
| 专辑背景 | 当前封面高斯模糊后铺在播放器内容下方，可调不透明度 |

## 频谱的工作方式（请先读）

iOS 没有向 SpringBoard 暴露其他 App 的音频电平，因此本插件**不采集音频数据**。频谱由「播放时间轴 + 节拍包络」驱动：

- 播放/暂停、进度、曲目切换来自 MediaRemote 的 Now Playing 信息；
- 频率分布（低频/中频/高频权重）按条位置分层，每拍产生“低频重、八分音符中频、十六分音符高频”的律动；
- `律动速度` 用来匹配歌曲 BPM：120 BPM 约为 1.00x，90 BPM 约为 0.75x，140 BPM 约为 1.17x；
- 暂停时停在低幅度呼吸状态，不伪造“正在播放”。

这样不引入私有音频采集库，也不会因音频路由变化导致崩溃。若需要真实 FFT 频谱，需要另接系统音频采集组件，本项目未集成。

## 设置项

设置入口：`设置 → 律动播放器`。首次安装默认关闭，需要手动打开「启用插件」。

| 键 | 默认 | 范围 | 说明 |
|---|---|---|---|
| `enabled` | 关 | 开关 | 插件总开关 |
| `spectrumEnabled` | 开 | 开关 | 频谱总开关 |
| `spectrumLockScreen` | 开 | 开关 | 锁屏播放器显示频谱 |
| `spectrumControlCenter` | 开 | 开关 | 控制中心播放器显示频谱 |
| `spectrumStyle` | 柱状 | 柱状/波形 | 频谱样式 |
| `spectrumTheme` | 彩虹 | 彩虹/霓虹/极光/单色/跟随封面 | 配色方案 |
| `spectrumColor` | `#7CE7FF` | 十六进制颜色 | 仅“单色”方案使用 |
| `spectrumBars` | 28 | 12–48 | 频谱条数（窄播放器会自动减少） |
| `spectrumHeight` | 42 pt | 16–90 pt | 频谱高度（不超过封面的 55%） |
| `spectrumOpacity` | 0.90 | 0.2–1.0 | 频谱不透明度 |
| `spectrumSpeed` | 1.00x | 0.5–2.0x | 律动速度，用于匹配 BPM |
| `buttonScale` | 1.00x | 0.6–1.5x | 播放控制按钮图标缩放 |
| `titleColor` | 空 | 十六进制颜色 | 标题颜色，空为系统 |
| `subtitleColor` | 空 | 十六进制颜色 | 副标题颜色，空为系统 |
| `titleSize` | 0 | 0–24 pt | 标题字号，0 为系统 |
| `subtitleSize` | 0 | 0–20 pt | 副标题字号，0 为系统 |
| `playerScale` | 1.00x | 0.8–1.15x | 锁屏播放器整体缩放 |
| `playerCorner` | 18 pt | 0–40 pt | 背景圆角（专辑背景开启时可见） |
| `artworkCorner` | 12 pt | 0–40 pt | 专辑封面圆角，0 为系统默认 |
| `artworkBackdrop` | 开 | 开关 | 专辑封面模糊背景 |
| `backdropOpacity` | 0.55 | 0–1 | 背景不透明度 |

设置面板底部有「恢复默认设置」，会清除所有自定义并关闭插件。

## 编译

需要可用的 Theos 工具链与 iPhoneOS 16.5 SDK。

```sh
sh build.sh rootless      # 默认
sh build.sh rootful
sh build.sh roothide
sh build.sh all           # 三套环境分别 clean + package
```

产物在 `packages/`。也可以把仓库推到 GitHub，使用自带的 `.github/workflows/build.yml`（macOS 14 + Xcode 15.4 + iPhoneOS 16.5 SDK）构建并发布 Release；默认矩阵只构建 Rootless。

## 安装

1. 在 Sileo / Zebra / Filza 中安装 `packages/*.deb`（Rootless 设备装 Rootless 包）。
2. 打开 `设置 → 律动播放器`，开启「启用插件」。
3. 打开锁屏播放器或控制中心音乐模块；必要时重新播放一次歌曲，让 MediaRemote 推送封面与播放状态。

无需注销；切换歌曲或重新布局播放器会重新读取设置。

## 目录结构

```text
playerpulse/
├── Hooks/AxsPlayerPulseMain.xm           # MediaRemoteUI / 背光 hook
├── Headers/AxsPlayerPulsePrivate.h       # iOS 16.5 私有类声明
├── Sources/
│   ├── AxsPlayerPulseConfig.*            # 配置快照
│   ├── AxsPlayerPulseDefaults.h          # 键名、枚举、重置键表
│   ├── AxsPlayerPulsePreferences.h       # 单写入方配置读写
│   ├── AxsPlayerPulsePaths.h             # Rootful/Rootless/Roothide 路径
│   ├── AxsPlayerPulseStyle.*             # 配置 → 样式快照、配色解析
│   ├── AxsPlayerPulseNowPlaying.*        # MediaRemote 状态、封面与主色
│   ├── AxsPlayerPulseSpectrumView.*      # 频谱绘制与节拍引擎
│   ├── AxsPlayerPulseBackdropView.*      # 封面模糊背景
│   └── AxsPlayerPulsePlayerStyler.*      # 播放器布局/字体/按钮/频谱装配
└── AxsPlayerPulsePrefs/                  # 设置面板 + 自定义滑条 + 列表控制器
```

## 适配与边界

- 基于 iOS 16.5 的 `MRUNowPlayingView` 层级：`_artworkView`、`_headerView`（含 `_labelView`）、`_transportControlsView`（`_leftButton/_centerButton/_rightButton`）。取不到 ivar 时会按类名回退查找，iOS 17/18 未验证。
- 播放器缩放只作用于锁屏，避免控制中心模块网格被裁切。
- 频谱是只读装饰层，不接管触摸；屏幕熄灭时停止刷新。
- 所有自定义标识带 `AxsPlayerPulse` 前缀；配置只有设置面板一个写入方。

## 验证范围

已完成：

- `scripts/doctor.py` 工程结构与命名空间检查通过；
- 偏好 plist 可被 `plistlib` 解析，21 个配置键与代码默认值一一对应；
- 源码括号/字符串平衡、头文件引用、Makefile 文件收集与私有类声明静态检查。

未完成（当前环境没有 Theos、iPhoneOS SDK 与 clang，也没有越狱设备）：

- Theos 编译与 deb 内容检查；
- Rootless/Roothide 真机加载、设置面板读写、频谱实际帧率与触摸穿透；
- iOS 17/18 私有类结构适配。

首次安装后建议先用 `dpkg-deb -I/-c` 检查包，再在目标设备上逐项验收设置。
