# 轻坛 Kotlin 原生版

`qingtan_kotlin` 是轻坛社区客户端 `hjyz_bbs` 的原生 Android/Kotlin 实现，沿用相同的应用名、包名、版本号与服务器，原 Flutter 工程保持不变。

当前基础版包含：

- 首页双列自适应瀑布流、刷新和分页加载
- 帖子卡片与连接真实详情接口的预览页
- 连接现有 PHP API 的账号登录和登录态持久化
- 游客/已登录状态的“我的”页
- Material 3 + Jetpack Compose 原生界面

## 代码结构

- `core/`：与 Flutter `AppConfig` 对齐的固定配置
- `data/model/`：首页、帖子详情和评论模型
- `data/network/`：现有 PHP API 与登录令牌存储
- `ui/ForumViewModel.kt`：首页频道、详情和登录状态
- `ui/screens/`：首页、帖子详情、登录、“我的”各自独立页面
- `ui/components/`：瀑布流卡片及通用加载/错误状态
- `ui/theme/`：Material 主题与品牌色

## GitHub Actions 编译

在仓库的 Actions 页面手动运行 `Build Qingtan Kotlin Android`，或者向 `qingtan_kotlin/**` 推送改动。任务完成后，在该次运行的 Artifacts 中下载 `qingtan-kotlin-apk`。

云端使用 JDK 17、Gradle 8.9 和 Android SDK 35 构建可安装的 release APK，无需本机安装开发环境。

## 本地开发（可选）

用 Android Studio 打开本目录，或在安装 Android SDK 后运行：

```sh
./gradlew :app:assembleRelease
```
