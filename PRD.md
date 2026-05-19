## 🤖 Assistant

# 类 Discuz 论坛系统 PRD.md  
## 虚拟主机版 / 原生 PHP 版

---

# 1. 产品概述

## 1.1 产品名称

暂定：**ForumX Lite 原生 PHP 论坛系统**

## 1.2 产品定位

ForumX Lite 是一套面向虚拟主机环境的轻量级社区论坛系统，功能对标 Discuz 的核心论坛能力，但技术实现采用**原生 PHP + MySQL**，不依赖 Laravel、Composer、Redis、队列、WebSocket 或额外 PHP 扩展。

系统重点满足以下场景：

- 用户在普通虚拟主机上部署论坛；
- 服务器权限受限，无法安装 PHP 插件；
- 无法修改 `php.ini`；
- 无法运行常驻进程；
- 无法使用命令行 Composer；
- 仅支持传统 PHP 文件上传部署；
- 数据库通常为 MySQL / MariaDB；
- 适合中小型论坛、社区、兴趣站、移动端 API 后端。

---

# 2. 虚拟主机环境约束

## 2.1 技术限制

本产品必须适配以下限制：

| 限制项 | 说明 |
|---|---|
| 无法安装 PHP 扩展 | 不依赖 Redis、Swoole、Imagick、GD 等非必需扩展 |
| 无法修改 PHP 配置 | 不要求修改 `php.ini` |
| 无法运行 Composer | 不依赖 Laravel、ThinkPHP、Symfony 等框架 |
| 无法运行队列进程 | 所有任务同步执行或通过伪计划任务执行 |
| 无法运行 WebSocket | 消息通知采用轮询 |
| 无法访问服务器 Shell | 安装通过上传文件 + 浏览器安装向导完成 |
| 文件权限有限 | 所有可写目录集中在 `/uploads`、`/cache`、`/runtime` |
| 可能无伪静态 | 支持 `index.php?route=xxx` 路由模式 |
| 可能无 HTTPS 强制 | 系统提供 HTTPS 检测和提醒，但不强制依赖 |

---

# 3. 技术架构

## 3.1 总体架构

```text
Flutter App / Web H5
        |
        | HTTP / HTTPS JSON API
        |
原生 PHP API 层
        |
业务 Service 层
        |
MySQL 数据库
        |
本地文件缓存 / 本地上传目录
```

## 3.2 技术栈

### 服务端

| 模块 | 技术 |
|---|---|
| 后端语言 | 原生 PHP 7.4+ / PHP 8.x |
| 数据库 | MySQL 5.7+ / MariaDB 10.x+ |
| 数据库访问 | PDO MySQL 优先，若不可用则 mysqli 兼容 |
| 路由 | 自研轻量路由 |
| 模板 | 原生 PHP 模板，可选 |
| API 格式 | JSON |
| 文件上传 | PHP 原生 `move_uploaded_file()` |
| 缓存 | 文件缓存 |
| Session | PHP 原生 Session 或数据库 Token |
| 密码加密 | `password_hash()` / `password_verify()` |
| 图片处理 | 不强制依赖 GD，默认仅保存原图 |
| 日志 | 本地文件日志 + 数据库操作日志 |

### 客户端

| 模块 | 技术 |
|---|---|
| App | Flutter |
| 网络请求 | Dio |
| 状态管理 | Riverpod / Provider |
| 本地存储 | SharedPreferences / Secure Storage |
| 图片缓存 | cached_network_image |
| 瀑布流 | flutter_staggered_grid_view |

---

# 4. 产品目标

## 4.1 核心目标

1. 在普通虚拟主机上完成部署和运行。
2. 不依赖 Composer、不依赖框架、不依赖额外扩展。
3. 提供论坛系统核心能力：
   - 注册
   - 登录
   - 版块
   - 发帖
   - 回帖
   - 点赞
   - 收藏
   - 签到
   - 消息通知
   - 举报
   - 后台管理
4. 提供适合 Flutter 客户端调用的 REST 风格 API。
5. 系统安装简单，通过浏览器安装向导完成数据库初始化。

---

# 5. 用户角色

## 5.1 游客

可浏览公开内容，不可发帖、回复、点赞、收藏、签到。

## 5.2 普通用户

可注册、登录、发帖、回复、点赞、收藏、签到、举报。

## 5.3 版主

可管理指定版块内容，包括删除、置顶、精华、关闭主题、处理举报。

## 5.4 管理员

可访问后台，管理用户、版块、帖子、回复、举报、配置等。

## 5.5 超级管理员

拥有全部权限，可管理管理员账号和系统关键配置。

---

# 6. 系统模块

## 6.1 前台 / App API 模块

```text
认证模块
首页 Feed 模块
版块模块
主题模块
回复模块
点赞模块
收藏模块
签到模块
用户主页模块
消息通知模块
举报模块
上传模块
搜索模块
```

## 6.2 后台管理模块

```text
管理员登录
后台首页
用户管理
版块管理
主题管理
回复管理
举报管理
签到管理
积分管理
系统配置
敏感词管理
上传管理
操作日志
```

---

# 7. 部署与目录设计

## 7.1 推荐目录结构

```text
/forumx
├── index.php                  # API 入口
├── admin.php                  # 后台入口
├── install.php                # 安装向导
├── config
│   ├── config.php             # 基础配置
│   ├── database.php           # 数据库配置
│   └── routes.php             # 路由配置
├── app
│   ├── Controllers
│   ├── Services
│   ├── Models
│   ├── Middlewares
│   └── Helpers
├── core
│   ├── App.php
│   ├── Router.php
│   ├── Request.php
│   ├── Response.php
│   ├── Database.php
│   ├── Validator.php
│   ├── Auth.php
│   ├── Upload.php
│   └── Cache.php
├── views
│   └── admin
├── public
│   ├── assets
│   └── static
├── uploads
│   ├── avatars
│   ├── images
│   ├── attachments
│   └── temp
├── cache
├── runtime
│   ├── logs
│   └── sessions
└── sql
    └── install.sql
```

## 7.2 可写目录

安装时检测以下目录是否可写：

```text
/uploads
/cache
/runtime
/runtime/logs
/runtime/sessions
```

---

# 8. 路由设计

由于虚拟主机可能不支持伪静态，系统默认采用查询参数路由：

```text
/index.php?route=auth/login
/index.php?route=auth/register
/index.php?route=threads/list
/index.php?route=threads/detail&id=1
```

如果服务器支持伪静态，可选支持：

```text
/api/auth/login
/api/threads
/api/threads/1
```

## 8.1 API 通用规范

### 请求格式

```http
Content-Type: application/json
Authorization: Bearer {token}
```

也兼容：

```http
Content-Type: application/x-www-form-urlencoded
```

### 响应格式

```json
{
  "code": 0,
  "message": "success",
  "data": {},
  "request_id": "req_xxxxx"
}
```

### 错误码

| code | 说明 |
|---|---|
| 0 | 成功 |
| 400 | 参数错误 |
| 401 | 未登录 |
| 403 | 无权限 |
| 404 | 数据不存在 |
| 409 | 数据冲突 |
| 422 | 校验失败 |
| 429 | 请求过于频繁 |
| 500 | 服务异常 |

---

# 9. 核心功能需求

---

# 9.1 注册功能

## 9.1.1 注册方式

虚拟主机版默认支持：

1. 用户名 + 密码 + 图形验证码
2. 邮箱注册，可选
3. 手机注册，可预留，不默认依赖短信接口

## 9.1.2 注册字段

| 字段 | 必填 | 规则 |
|---|---|---|
| username | 是 | 3-20 位，中文、英文、数字、下划线 |
| nickname | 否 | 默认等于用户名 |
| email | 否 | 唯一 |
| password | 是 | 8-32 位，建议包含字母和数字 |
| password_confirm | 是 | 与密码一致 |
| captcha | 是 | 图形验证码 |
| agreement | 是 | 必须同意用户协议 |

## 9.1.3 密码存储

必须使用 PHP 原生函数：

```php
password_hash($password, PASSWORD_DEFAULT);
password_verify($password, $hash);
```

系统不得使用：

```text
MD5
SHA1
Base64
明文密码
```

## 9.1.4 注册限制

- 同 IP 每小时最多注册 N 个账号。
- 用户名、昵称命中敏感词时禁止注册。
- 注册成功后默认用户组为普通会员。
- 注册奖励积分可后台配置。

---

# 9.2 登录功能

## 9.2.1 登录方式

支持：

- 用户名 + 密码
- 邮箱 + 密码

## 9.2.2 登录安全

- 登录失败记录日志。
- 单账号连续失败 5 次，锁定 15 分钟。
- 同 IP 5 分钟内失败超过 N 次，需要验证码。
- 登录成功后生成 Token。
- 退出登录后 Token 失效。

## 9.2.3 Token 机制

由于虚拟主机不适合复杂 JWT 扩展，本系统采用数据库 Token：

### 登录成功生成：

```text
access_token = bin2hex(random_bytes(32))
```

### Token 存储表：

`user_tokens`

| 字段 | 说明 |
|---|---|
| id | ID |
| user_id | 用户 ID |
| token_hash | Token 哈希 |
| device_id | 设备 ID |
| ip | 登录 IP |
| user_agent | UA |
| expired_at | 过期时间 |
| created_at | 创建时间 |

Token 只返回明文一次，数据库保存：

```php
hash('sha256', $token)
```

---

# 9.3 首页 Feed

## 9.3.1 页面结构

首页提供移动端推荐 Feed：

```text
顶部搜索
频道 Tab
Banner，可选
快捷入口
双列瀑布流
```

## 9.3.2 频道

```text
推荐
热门
最新
精华
关注，可选
图文
问答
```

## 9.3.3 推荐排序规则

虚拟主机版采用 MySQL 规则排序：

```sql
score = view_count * 0.2
      + reply_count * 0.3
      + like_count * 0.3
      + favorite_count * 0.4
      + share_count * 0.2
      + digest_weight
      + recent_weight
```

不依赖推荐服务、不依赖队列、不依赖搜索引擎。

---

# 9.4 版块功能

## 9.4.1 版块列表

展示：

- 版块名称
- 图标
- 简介
- 今日发帖数
- 总主题数
- 总回复数
- 是否启用

## 9.4.2 版块详情

支持：

- 版块信息
- 版主信息
- 版块规则
- 主题列表
- 排序：
  - 最新回复
  - 最新发布
  - 热门
  - 精华

---

# 9.5 发帖功能

## 9.5.1 支持帖子类型

V1.0 支持：

1. 普通主题
2. 图文主题

V1.1 可扩展：

1. 投票主题
2. 悬赏主题
3. 活动主题

## 9.5.2 发帖字段

| 字段 | 必填 | 说明 |
|---|---|---|
| forum_id | 是 | 所属版块 |
| title | 是 | 5-80 字 |
| content | 是 | 正文 |
| cover | 否 | 封面图 |
| images | 否 | 图片列表 |
| tags | 否 | 最多 5 个 |
| type | 否 | 默认 normal |

## 9.5.3 发帖限制

- 必须登录。
- 账号状态正常。
- 用户组有发帖权限。
- 版块允许发帖。
- 标题和正文需进行敏感词检测。
- 新用户发帖间隔限制。
- 每日发帖数量限制。
- 若后台开启审核，则帖子进入待审核状态。

---

# 9.6 回复功能

## 9.6.1 回复类型

支持：

- 普通回复
- 引用回复
- 楼中楼回复

## 9.6.2 回复规则

- 登录用户才可回复。
- 关闭主题不可回复。
- 禁言用户不可回复。
- 回复内容不可为空。
- 回复内容需敏感词过滤。
- 回复成功后更新：
  - 主题回复数
  - 版块回复数
  - 最后回复时间
  - 用户积分

---

# 9.7 点赞功能

## 9.7.1 支持对象

- 主题
- 回复

## 9.7.2 点赞规则

- 每个用户对同一对象只能点赞一次。
- 可取消点赞。
- 点赞数量同步更新在主题或回复表中。
- 不使用异步队列。

---

# 9.8 收藏功能

## 9.8.1 支持对象

- 主题
- 版块

## 9.8.2 收藏规则

- 每个用户对同一对象只能收藏一次。
- 可取消收藏。
- 收藏数量实时更新。

---

# 9.9 签到功能

## 9.9.1 签到规则

- 每个自然日只能签到一次。
- 签到奖励积分。
- 连续签到奖励递增。
- 断签后连续天数重置。

## 9.9.2 奖励示例

| 连续天数 | 奖励积分 |
|---|---|
| 第 1 天 | 5 |
| 第 2 天 | 6 |
| 第 3 天 | 7 |
| 第 7 天 | 20 |
| 第 30 天 | 100 |

---

# 9.10 消息通知

## 9.10.1 消息类型

- 系统通知
- 回复我的
- 点赞通知
- 收藏通知
- 审核通知
- 举报处理通知
- 积分变动通知

## 9.10.2 实现方式

由于虚拟主机无法运行 WebSocket，消息采用：

```text
App 定时轮询未读数
用户进入消息页时分页拉取消息
```

接口：

```text
/index.php?route=notifications/list
/index.php?route=notifications/unread_count
/index.php?route=notifications/read
```

---

# 9.11 上传功能

## 9.11.1 支持上传类型

V1.0 支持：

- 头像
- 帖子图片
- 附件，可选

## 9.11.2 上传限制

由于无法修改 PHP 配置，上传大小受虚拟主机限制：

```text
upload_max_filesize
post_max_size
max_execution_time
```

系统后台仅允许设置不超过服务器限制的上传大小。

## 9.11.3 文件安全

- 校验文件扩展名。
- 校验 MIME 类型。
- 文件重命名。
- 不允许上传 PHP、HTML、JS、EXE 等危险文件。
- 上传路径不允许执行 PHP。
- 文件名生成方式：

```text
年月目录 + 随机文件名
/uploads/images/2025/01/随机名.jpg
```

## 9.11.4 图片处理

不强制依赖 GD 或 Imagick。

默认行为：

- 保存原图。
- 记录文件地址、大小、MIME。
- 不进行服务端压缩。

如服务器支持 GD，可在后台启用缩略图功能。

---

# 9.12 搜索功能

## 9.12.1 搜索范围

- 主题标题
- 主题正文
- 用户昵称
- 版块名称

## 9.12.2 实现方式

虚拟主机版不依赖 Elasticsearch。

默认使用 MySQL：

```sql
LIKE '%关键词%'
```

如 MySQL 支持 FULLTEXT，可后台开启全文索引搜索。

---

# 9.13 举报功能

## 9.13.1 举报对象

- 主题
- 回复
- 用户

## 9.13.2 举报原因

- 广告垃圾
- 色情低俗
- 辱骂攻击
- 侵权
- 诈骗
- 违法违规
- 其他

## 9.13.3 处理流程

```text
用户提交举报
后台生成举报记录
管理员查看举报
管理员处理
系统通知举报人
```

---

# 9.14 后台管理

## 9.14.1 后台登录

后台入口：

```text
/admin.php
```

支持：

- 管理员账号密码登录
- 图形验证码
- 登录失败锁定
- 后台 Session 登录

## 9.14.2 后台首页

展示：

- 今日新增用户
- 今日新增主题
- 今日新增回复
- 今日签到人数
- 待审核主题
- 待处理举报
- 服务器 PHP 版本
- MySQL 版本
- 上传限制

## 9.14.3 用户管理

支持：

- 用户列表
- 搜索用户
- 查看用户详情
- 修改用户资料
- 修改用户组
- 修改积分
- 禁言用户
- 解禁用户
- 封禁用户
- 重置密码

## 9.14.4 版块管理

支持：

- 新增版块
- 编辑版块
- 删除版块
- 排序
- 启用 / 禁用
- 设置发帖权限
- 设置是否审核

## 9.14.5 主题管理

支持：

- 查看主题列表
- 按版块筛选
- 按作者筛选
- 编辑主题
- 删除主题
- 恢复主题
- 置顶
- 精华
- 关闭主题
- 审核通过
- 审核拒绝

## 9.14.6 回复管理

支持：

- 查看回复列表
- 删除回复
- 恢复回复
- 审核回复
- 查看上下文

## 9.14.7 系统配置

配置项保存到数据库或 `config/site.php`。

包括：

- 站点名称
- 站点 Logo
- 注册开关
- 发帖审核开关
- 回复审核开关
- 上传大小限制
- 允许上传类型
- 积分规则
- 敏感词配置
- 验证码开关
- SEO 设置

---

# 10. 数据库设计

以下为虚拟主机版核心表。

---

## 10.1 用户表 `fx_users`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | bigint unsigned | 用户 ID |
| username | varchar(50) | 用户名 |
| nickname | varchar(50) | 昵称 |
| email | varchar(100) | 邮箱 |
| password_hash | varchar(255) | 密码哈希 |
| avatar | varchar(255) | 头像 |
| bio | varchar(255) | 简介 |
| group_id | int | 用户组 |
| level | int | 等级 |
| score | int | 积分 |
| status | tinyint | 状态 |
| last_login_at | datetime | 最后登录时间 |
| last_login_ip | varchar(45) | 最后登录 IP |
| created_at | datetime | 创建时间 |
| updated_at | datetime | 更新时间 |

---

## 10.2 用户 Token 表 `fx_user_tokens`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | bigint unsigned | ID |
| user_id | bigint unsigned | 用户 ID |
| token_hash | char(64) | Token 哈希 |
| device_id | varchar(100) | 设备 ID |
| ip | varchar(45) | IP |
| user_agent | varchar(255) | UA |
| expired_at | datetime | 过期时间 |
| created_at | datetime | 创建时间 |

---

## 10.3 用户组表 `fx_user_groups`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | int | 用户组 ID |
| name | varchar(50) | 用户组名称 |
| type | varchar(20) | member/admin/special |
| permissions | text | JSON 权限 |
| min_score | int | 最低积分 |
| max_score | int | 最高积分 |
| status | tinyint | 状态 |

---

## 10.4 版块表 `fx_forums`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | int | 版块 ID |
| parent_id | int | 父版块 |
| name | varchar(100) | 版块名称 |
| icon | varchar(255) | 图标 |
| cover | varchar(255) | 封面 |
| description | text | 简介 |
| rules | text | 版规 |
| sort_order | int | 排序 |
| thread_count | int | 主题数 |
| post_count | int | 回复数 |
| today_count | int | 今日数 |
| need_audit | tinyint | 是否审核 |
| status | tinyint | 状态 |
| created_at | datetime | 创建时间 |

---

## 10.5 主题表 `fx_threads`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | bigint unsigned | 主题 ID |
| forum_id | int | 版块 ID |
| user_id | bigint unsigned | 作者 ID |
| type | varchar(20) | 类型 |
| title | varchar(120) | 标题 |
| summary | varchar(255) | 摘要 |
| content | mediumtext | 正文 |
| cover | varchar(255) | 封面 |
| tags | varchar(255) | 标签 JSON |
| view_count | int | 浏览数 |
| reply_count | int | 回复数 |
| like_count | int | 点赞数 |
| favorite_count | int | 收藏数 |
| share_count | int | 分享数 |
| is_top | tinyint | 置顶 |
| is_digest | tinyint | 精华 |
| is_closed | tinyint | 关闭 |
| status | tinyint | 状态 |
| last_reply_at | datetime | 最后回复 |
| created_at | datetime | 创建时间 |
| updated_at | datetime | 更新时间 |

---

## 10.6 回复表 `fx_posts`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | bigint unsigned | 回复 ID |
| thread_id | bigint unsigned | 主题 ID |
| user_id | bigint unsigned | 回复用户 |
| parent_id | bigint unsigned | 父回复 |
| quote_post_id | bigint unsigned | 引用回复 |
| content | mediumtext | 内容 |
| floor | int | 楼层 |
| like_count | int | 点赞数 |
| status | tinyint | 状态 |
| created_at | datetime | 创建时间 |

---

## 10.7 点赞表 `fx_likes`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | bigint unsigned | ID |
| user_id | bigint unsigned | 用户 ID |
| object_type | varchar(20) | thread/post |
| object_id | bigint unsigned | 对象 ID |
| created_at | datetime | 创建时间 |

唯一索引：

```text
user_id + object_type + object_id
```

---

## 10.8 收藏表 `fx_favorites`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | bigint unsigned | ID |
| user_id | bigint unsigned | 用户 ID |
| object_type | varchar(20) | thread/forum |
| object_id | bigint unsigned | 对象 ID |
| created_at | datetime | 创建时间 |

---

## 10.9 签到表 `fx_checkins`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | bigint unsigned | ID |
| user_id | bigint unsigned | 用户 ID |
| checkin_date | date | 签到日期 |
| reward_score | int | 奖励积分 |
| continuous_days | int | 连续天数 |
| created_at | datetime | 创建时间 |

唯一索引：

```text
user_id + checkin_date
```

---

## 10.10 积分日志表 `fx_score_logs`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | bigint unsigned | ID |
| user_id | bigint unsigned | 用户 ID |
| action | varchar(50) | 行为 |
| amount | int | 变动数量 |
| balance | int | 当前余额 |
| remark | varchar(255) | 备注 |
| created_at | datetime | 创建时间 |

---

## 10.11 上传附件表 `fx_attachments`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | bigint unsigned | 附件 ID |
| user_id | bigint unsigned | 上传用户 |
| object_type | varchar(20) | thread/post/avatar |
| object_id | bigint unsigned | 对象 ID |
| file_name | varchar(255) | 原文件名 |
| file_path | varchar(255) | 文件路径 |
| file_url | varchar(255) | 访问 URL |
| file_type | varchar(50) | MIME |
| file_size | int | 大小 |
| status | tinyint | 状态 |
| created_at | datetime | 创建时间 |

---

## 10.12 消息表 `fx_notifications`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | bigint unsigned | ID |
| user_id | bigint unsigned | 接收用户 |
| type | varchar(50) | 消息类型 |
| title | varchar(100) | 标题 |
| content | text | 内容 |
| data | text | JSON 数据 |
| is_read | tinyint | 是否已读 |
| created_at | datetime | 创建时间 |

---

## 10.13 举报表 `fx_reports`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | bigint unsigned | 举报 ID |
| reporter_id | bigint unsigned | 举报人 |
| target_type | varchar(20) | thread/post/user |
| target_id | bigint unsigned | 对象 ID |
| reason | varchar(100) | 原因 |
| description | text | 描述 |
| status | tinyint | 状态 |
| handler_id | bigint unsigned | 处理人 |
| handled_at | datetime | 处理时间 |
| created_at | datetime | 创建时间 |

---

## 10.14 系统配置表 `fx_settings`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | int | ID |
| setting_key | varchar(100) | 配置键 |
| setting_value | mediumtext | 配置值 |
| type | varchar(20) | 类型 |
| updated_at | datetime | 更新时间 |

---

## 10.15 敏感词表 `fx_sensitive_words`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | int | ID |
| word | varchar(100) | 敏感词 |
| replacement | varchar(100) | 替换词 |
| level | tinyint | 等级 |
| status | tinyint | 状态 |
| created_at | datetime | 创建时间 |

---

# 11. API 设计

---

## 11.1 认证接口

| 接口 | 方法 | 说明 |
|---|---|---|
| `?route=captcha/image` | GET | 获取验证码 |
| `?route=auth/register` | POST | 注册 |
| `?route=auth/login` | POST | 登录 |
| `?route=auth/logout` | POST | 退出 |
| `?route=user/me` | GET | 当前用户 |

---

## 11.2 首页接口

| 接口 | 方法 | 说明 |
|---|---|---|
| `?route=home/feed` | GET | 首页瀑布流 |
| `?route=home/hot` | GET | 热门内容 |
| `?route=home/latest` | GET | 最新内容 |

---

## 11.3 版块接口

| 接口 | 方法 | 说明 |
|---|---|---|
| `?route=forums/list` | GET | 版块列表 |
| `?route=forums/detail&id=1` | GET | 版块详情 |
| `?route=forums/threads&id=1` | GET | 版块主题列表 |

---

## 11.4 主题接口

| 接口 | 方法 | 说明 |
|---|---|---|
| `?route=threads/list` | GET | 主题列表 |
| `?route=threads/detail&id=1` | GET | 主题详情 |
| `?route=threads/create` | POST | 发帖 |
| `?route=threads/update&id=1` | POST | 编辑主题 |
| `?route=threads/delete&id=1` | POST | 删除主题 |
| `?route=threads/like&id=1` | POST | 点赞 |
| `?route=threads/unlike&id=1` | POST | 取消点赞 |
| `?route=threads/favorite&id=1` | POST | 收藏 |
| `?route=threads/unfavorite&id=1` | POST | 取消收藏 |

---

## 11.5 回复接口

| 接口 | 方法 | 说明 |
|---|---|---|
| `?route=posts/list&thread_id=1` | GET | 回复列表 |
| `?route=posts/create` | POST | 发表回复 |
| `?route=posts/delete&id=1` | POST | 删除回复 |
| `?route=posts/like&id=1` | POST | 点赞回复 |

---

## 11.6 签到接口

| 接口 | 方法 | 说明 |
|---|---|---|
| `?route=checkin/status` | GET | 签到状态 |
| `?route=checkin/do` | POST | 签到 |
| `?route=checkin/rank` | GET | 签到排行 |

---

## 11.7 上传接口

| 接口 | 方法 | 说明 |
|---|---|---|
| `?route=upload/image` | POST | 上传图片 |
| `?route=upload/avatar` | POST | 上传头像 |
| `?route=upload/file` | POST | 上传附件 |

---

## 11.8 消息接口

| 接口 | 方法 | 说明 |
|---|---|---|
| `?route=notifications/list` | GET | 消息列表 |
| `?route=notifications/unread_count` | GET | 未读数 |
| `?route=notifications/read&id=1` | POST | 标记已读 |
| `?route=notifications/read_all` | POST | 全部已读 |

---

# 12. 权限设计

## 12.1 权限判断维度

每个核心操作需判断：

1. 是否登录；
2. 用户状态是否正常；
3. 用户组权限；
4. 版块权限；
5. 内容状态；
6. 是否被禁言；
7. 是否达到频率限制；
8. 是否需要审核。

## 12.2 用户状态

| 状态 | 说明 |
|---|---|
| 1 | 正常 |
| 2 | 待审核 |
| 3 | 禁言 |
| 4 | 冻结 |
| 5 | 封禁 |

## 12.3 主题状态

| 状态 | 说明 |
|---|---|
| 1 | 正常 |
| 2 | 待审核 |
| 3 | 已屏蔽 |
| 4 | 已删除 |

---

# 13. 安全需求

## 13.1 数据库安全

- 必须使用预处理 SQL。
- 禁止直接拼接用户输入。
- 数据库错误不得直接输出给用户。
- 后台配置开启调试模式时才显示错误详情。

## 13.2 XSS 防护

- 用户昵称、标题输出时进行 HTML 转义。
- 正文内容默认进行安全过滤。
- 不允许直接保存危险脚本标签。
- 后台可配置允许的 HTML 标签。

## 13.3 CSRF 防护

后台管理表单必须使用 CSRF Token。

API 使用 Token 鉴权，可不强制 CSRF。

## 13.4 上传安全

- 禁止上传 `.php`、`.phtml`、`.php5`、`.html`、`.js` 等文件。
- 上传目录不得执行 PHP。
- 文件名必须随机生成。
- 保存原文件名仅用于展示，不用于真实路径。

## 13.5 登录安全

- 密码加密存储。
- 登录失败限制。
- Token 过期机制。
- 退出登录删除 Token。
- 管理员登录记录日志。

---

# 14. 缓存设计

由于不能使用 Redis，采用文件缓存。

## 14.1 文件缓存目录

```text
/cache
```

## 14.2 缓存内容

可缓存：

- 站点配置
- 版块列表
- 热门主题
- 敏感词列表
- 用户组权限

## 14.3 缓存策略

- 后台修改配置时清理缓存。
- 缓存文件使用 PHP 数组或 JSON。
- 缓存文件命名：

```text
/cache/settings.php
/cache/forums.php
/cache/permissions.php
/cache/hot_threads.json
```

---

# 15. 伪计划任务设计

虚拟主机通常无法运行 Cron，因此系统提供两种方式。

## 15.1 访问触发

当用户访问站点时，系统判断是否需要执行轻量任务：

```text
清理过期 Token
清理验证码
重置版块今日统计
清理临时上传文件
```

## 15.2 外部 URL 触发

如果虚拟主机支持计划任务访问 URL，可配置：

```text
https://domain.com/index.php?route=cron/run&key=安全密钥
```

---

# 16. Flutter 客户端适配要求

## 16.1 API 地址

Flutter 客户端需要支持两种 API 模式：

```text
https://domain.com/index.php?route=auth/login
```

或：

```text
https://domain.com/api/auth/login
```

## 16.2 首页瀑布流

要求：

- 双列瀑布流；
- 支持下拉刷新；
- 支持分页加载；
- 帖子卡片显示：
  - 封面
  - 标题
  - 作者
  - 点赞数
  - 回复数
  - 精华角标
  - 置顶角标

## 16.3 Token 保存

客户端使用本地安全存储保存：

```text
access_token
user_id
nickname
avatar
```

请求时携带：

```http
Authorization: Bearer {token}
```

---

# 17. 安装向导

## 17.1 安装入口

```text
/install.php
```

## 17.2 安装步骤

```text
1. 环境检测
2. 目录权限检测
3. 数据库配置
4. 导入数据表
5. 创建管理员账号
6. 写入配置文件
7. 删除或锁定 install.php
```

## 17.3 环境检测项

| 检测项 | 要求 |
|---|---|
| PHP 版本 | >= 7.4 |
| MySQL 支持 | PDO MySQL 或 mysqli |
| JSON 支持 | 必须 |
| Session 支持 | 建议 |
| file_uploads | 必须 |
| uploads 可写 | 必须 |
| cache 可写 | 必须 |
| runtime 可写 | 必须 |

---

# 18. 非功能需求

## 18.1 性能目标

适合中小型站点：

| 场景 | 目标 |
|---|---|
| 首页 Feed | 1-2 秒 |
| 登录接口 | 500ms-1s |
| 帖子详情 | 1 秒内 |
| 发帖 | 1-2 秒 |
| 上传图片 | 受虚拟主机带宽影响 |

## 18.2 数据规模建议

虚拟主机版建议规模：

| 指标 | 建议 |
|---|---|
| 注册用户 | 1 万以内 |
| 主题数 | 10 万以内 |
| 回复数 | 100 万以内 |
| 日活 | 1000 以内 |
| 并发 | 受主机配置限制 |

如果超过以上规模，建议迁移到 VPS / 云服务器版本。

---

# 19. 版本规划

## 19.1 V1.0 虚拟主机基础版

包含：

- 安装向导
- 用户注册登录
- 首页 Feed
- 版块
- 发帖
- 回复
- 点赞
- 收藏
- 签到
- 图片上传
- 后台基础管理

## 19.2 V1.1 社区增强版

包含：

- 举报处理
- 消息通知
- 用户主页
- 积分等级
- 敏感词管理
- 内容审核

## 19.3 V1.2 论坛增强版

包含：

- 投票帖
- 悬赏帖
- 勋章
- 任务系统
- 广告系统
- 搜索增强

## 19.4 V2.0 可迁移云服务器版

包含：

- Redis 缓存适配
- 队列任务
- 对象存储
- CDN
- 全文搜索
- WebSocket 消息

---

# 20. 验收标准

## 20.1 安装验收

- 可通过 FTP 上传文件部署；
- 可通过浏览器访问 `install.php` 安装；
- 可连接 MySQL；
- 可创建管理员；
- 可锁定安装程序；
- 不需要 Composer；
- 不需要修改 PHP 配置；
- 不需要安装额外插件。

## 20.2 注册登录验收

- 用户可注册；
- 密码加密保存；
- 用户可登录；
- 登录后返回 Token；
- 退出后 Token 失效；
- 登录失败会限制频率。

## 20.3 发帖验收

- 登录用户可发帖；
- 未登录用户不可发帖；
- 标题和正文必填；
- 发帖后版块主题数增加；
- 个人主页可看到自己的主题。

## 20.4 回复验收

- 登录用户可回复；
- 关闭主题不可回复；
- 回复后主题回复数增加；
- 回复楼层正确递增。

## 20.5 首页验收

- 首页返回分页 Feed；
- 支持推荐、热门、最新、精华频道；
- App 可展示双列瀑布流；
- 点击帖子可进入详情页。

## 20.6 后台验收

- 管理员可登录后台；
- 可管理用户；
- 可管理版块；
- 可管理主题；
- 可管理回复；
- 可处理举报；
- 可修改系统配置。

---

# 21. 原生 PHP 实现原则

本项目必须遵循以下实现原则：

1. **不使用 Composer。**
2. **不使用 Laravel / ThinkPHP / Symfony 等框架。**
3. **不依赖 Redis。**
4. **不依赖 Swoole。**
5. **不依赖队列进程。**
6. **不依赖 WebSocket。**
7. **不强制依赖 GD / Imagick。**
8. **所有功能使用原生 PHP 可实现。**
9. **所有核心配置可通过后台管理。**
10. **所有数据库操作必须预处理。**
11. **必须兼容无伪静态环境。**
12. **必须支持通过 FTP 上传部署。**

---

# 22. 推荐最小运行环境

```text
PHP >= 7.4
MySQL >= 5.7 或 MariaDB >= 10.2
PDO MySQL 或 mysqli
JSON 扩展
Session 支持
file_uploads = On
可写 uploads/cache/runtime 目录
```

---

# 23. 总结

ForumX Lite 原生 PHP 版是一套面向虚拟主机环境的轻量级论坛系统。它保留 Discuz 类论坛的核心能力，同时去除对现代服务端框架和复杂基础设施的依赖。

核心特点：

- 原生 PHP；
- 无需 Composer；
- 无需安装插件；
- 无需修改 PHP 配置；
- 支持虚拟主机；
- 支持 Flutter App API；
- 支持后台管理；
- 可逐步升级到云服务器增强版。
