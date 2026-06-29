# 轻坛 (QingTan)

轻量级跨平台社区论坛，基于 Flutter + PHP 构建。

## 功能特性

- 帖子发布（图文/文章模式，BBCode 标签）
- 隐藏内容（回复可见）、DV 码唯一标识
- 评论、点赞、收藏、分享、举报
- B站风格视频播放器（双击快进/后退、拖拽进度、长按倍速）
- 铭牌系统与认证标识（绿 V / 蓝 V / 金 V）
- 深度链接（`hyjzbbs://thread/DV码`）
- 多线程下载管理（暂停/继续/断点续传）
- 账号与安全（修改密码、设备管理、登录记录）
- 管理中心（用户权限编辑、帖子管理、置顶/锁定/删除）
- 签到打卡、用户关注
- 首页推荐（加权随机抽取+兴趣画像）、版块浏览、标签系统
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

1. 配置 `server/config/` 下的数据库与 OneDrive
2. 运行 `server/install.php` 初始化数据库
3. 部署 `server/` 到 PHP 环境

## 版本

当前版本：1.1.5+10
