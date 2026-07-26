# 轻坛 (QingTan)

轻量级跨平台社区论坛，基于 Flutter + PHP 构建。

## 功能特性

- 帖子发布（图文/文章模式，BBCode 标签）
- 隐藏内容（回复可见）、DV 码唯一标识
- 评论、点赞、收藏、分享、举报
- B站风格视频播放器（双击快进/后退、拖拽进度、长按倍速）
- 铭牌系统与认证标识（绿 V / 蓝 V / 金 V）
- 深度链接（`hyjzbbs://thread/DV码`）
- 多线程下载管理（历史恢复、暂停/继续、Android 系统打开器）
- 账号与安全（修改密码、设备管理、登录记录）
- 管理中心（用户权限编辑、帖子管理、置顶/锁定/删除）
- 签到打卡、用户关注
- 首页推荐（加权随机抽取+兴趣画像）、支持完整交互的管理员 X 风格信息流、版块浏览、标签系统
- 全局音乐播放器、封面动态取色背景、音乐律动、持久播放缓存、歌词同步滚动与歌单管理
- 六种可持久化主题色（包含 MD3 经典蓝）
- 搜索帖子与用户
- 浏览历史、收藏管理
- 创作者中心与数据统计
- 个人资料编辑、头像上传
- 应用内版本更新检查

## 技术栈

| 端 | 技术 |
|---|---|
| 客户端 | Flutter · Riverpod · GoRouter · MediaKit · Dio |
| 服务端 | PHP 7.4+ · MySQL · OneDrive |

## 项目结构

```
├── PRD.md                   # 产品需求文档
├── changes.md               # 版本更新日志
├── hjyz_bbs/                # Flutter 客户端
│   ├── lib/
│   │   ├── core/
│   │   │   ├── api/         # Dio 客户端、ApiResult 封装
│   │   │   ├── config/      # AppConfig（版本、API 地址）
│   │   │   ├── services/    # 业务服务
│   │   │   ├── storage/     # Token 持久化
│   │   │   └── widgets/     # 通用组件
│   │   ├── features/        # 功能模块（auth、home、thread、me 等）
│   │   ├── app.dart
│   │   ├── main.dart
│   │   └── router.dart      # GoRouter 路由定义
│   └── pubspec.yaml
│
└── server/                  # PHP 服务端
    ├── app/Controllers/     # 27 个 API 控制器
    ├── core/                # 核心类库（Database、Auth、Response 等）
    ├── config/              # 数据库、OneDrive 配置
    ├── install.php          # 安装向导
    ├── index.php            # API 入口（路由分发）
    ├── download.php         # 下载分发
    └── share.php            # 分享跳转
```

## 快速开始

### 客户端

```bash
cd hjyz_bbs
flutter pub get
flutter run
```

### 服务端

1. 配置 `server/config/` 下的数据库
2. 复制 `server/config/onedrive.local.example.php` 为
   `server/config/onedrive.local.php`，填写 OneDrive 凭据；也可使用
   `ONEDRIVE_CLIENT_ID`、`ONEDRIVE_CLIENT_SECRET`、
   `ONEDRIVE_REFRESH_TOKEN` 等环境变量
3. 运行 `server/install.php` 初始化数据库
4. 部署 `server/` 到 PHP 环境

已有站点升级附件文件管理功能时，部署后运行一次
`server/upgrade_version_1_1_8.php`，成功后立即删除该脚本。

升级 1.1.9 时，再运行一次 `server/upgrade_version_1_1_9.php`，
该脚本会保存旧 DV 别名、重新生成全部帖子 DV，并创建音乐歌单数据表，成功后立即删除。

升级客户端 1.2.4 时，部署服务端后运行一次
`server/upgrade_version_1_2_4.php` 登记新版本，成功后立即删除该脚本。

音乐播放器动态背景参考 NeriPlayer 的 HyperBackground 实现并翻译为
Flutter 跨平台渲染，来源与许可证见 `THIRD_PARTY_NOTICES.md`。

`onedrive.local.php` 和 `cache/onedrive_token.json` 已被 Git 忽略，禁止将真实凭据写入其他受版本控制的文件。

## 版本

当前版本：1.2.4+30
