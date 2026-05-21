# 获嘉一中论坛 (Huijia No.1 Middle School Forum)

获嘉一中校园论坛，基于 Flutter + PHP 构建的跨平台社区应用。

## 功能特性

### 帖子系统
- 发帖（支持文字、图片、视频、Markdown）
- 隐藏内容（回复可见）
- 帖子点赞、收藏、分享
- 浏览历史记录

### 互动功能
- 评论与回复
- 签到打卡
- 用户关注
- 私信聊天

### 内容发现
- 首页推荐（推荐/热门/精华/最新）
- 版块浏览
- 标签系统
- 搜索帖子、用户

### 创作者中心
- 帖子数据统计
- 内容管理

### 个人中心
- 编辑个人资料
- 浏览历史
- 收藏管理
- 设置（深色模式等）

## 技术栈

### 客户端
- Flutter
- Riverpod（状态管理）
- GoRouter（路由）
- MediaKit（视频播放）

### 服务端
- PHP
- MySQL
- OneDrive（文件存储）

## 项目结构

```
bbs/
├── hjyz_bbs/          # Flutter 客户端
│   ├── lib/
│   │   ├── core/      # 核心模块（API、配置、工具）
│   │   ├── features/  # 功能模块
│   │   │   ├── auth/          # 登录注册
│   │   │   ├── checkin/       # 签到
│   │   │   ├── creator/       # 创作者中心
│   │   │   ├── discover/      # 发现
│   │   │   ├── history/       # 历史记录
│   │   │   ├── home/          # 首页
│   │   │   ├── main/          # 主框架
│   │   │   ├── me/            # 个人中心
│   │   │   ├── message/       # 私信
│   │   │   ├── post/          # 发帖
│   │   │   ├── profile/       # 资料编辑
│   │   │   ├── search/        # 搜索
│   │   │   ├── thread/        # 帖子详情
│   │   │   └── user/          # 用户主页
│   │   └── main.dart
│   └── pubspec.yaml
│
└── server/            # PHP 服务端
    ├── app/
    │   └── Controllers/   # API 控制器
    ├── core/              # 核心类库
    ├── config/            # 配置文件
    └── index.php          # 入口文件
```

## 运行方式

### 客户端

```bash
cd hjyz_bbs
flutter pub get
flutter run
```

### 服务端

1. 配置 `server/config/` 目录下的数据库和 OneDrive 配置
2. 运行 `server/install.php` 初始化数据库
3. 将 `server/` 部署到 PHP 环境

## 版本

- 当前版本：1.0.2+2
