# 轻坛 (QingTan)

轻量级跨平台社区论坛，基于 Flutter + PHP 构建。

## 功能特性

- 帖子发布（文字、图片、视频、Markdown）
- 隐藏内容（回复可见）
- 评论、点赞、收藏、分享
- 签到打卡、用户关注
- 首页推荐、版块浏览、标签系统
- 搜索帖子与用户
- 浏览历史、收藏管理
- 创作者中心与数据统计
- 个人资料编辑、头像上传
- 应用内版本更新检查

## 技术栈

| 端 | 技术 |
|---|---|
| 客户端 | Flutter · Riverpod · GoRouter · MediaKit |
| 服务端 | PHP · MySQL · OneDrive |

## 项目结构

```
├── hjyz_bbs/              # Flutter 客户端
│   ├── lib/
│   │   ├── core/          # API、配置、工具类
│   │   └── features/      # 功能模块（auth、home、thread、me 等）
│   └── pubspec.yaml
│
└── server/                # PHP 服务端
    ├── app/Controllers/   # API 控制器
    ├── core/              # 核心类库
    ├── config/            # 配置文件
    └── index.php          # 入口文件
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

当前版本：1.1.3+8
