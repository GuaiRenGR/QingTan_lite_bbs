# 轻听音乐

独立的 Android Flutter 音乐搜索、播放和下载应用。所有音乐 API 都由客户端直接请求，不依赖轻坛服务端。

最低支持 Android 7.0（API 24）。

## 功能

- 11 个音乐源搜索和播放
- 标准音质（128 kbps）播放与下载
- 播放列表、封面和同步滚动歌词
- 后台播放、锁屏和通知栏媒体控制
- 下载时写入标题、歌手、专辑、封面和歌词标签
- 同时保存 `歌曲 - 歌手.lrc`
- Android 公共目录：`Download/QingTanMusic`

## 数据来源

多音源数据来自 [GD 音乐台](https://music.gdstudio.xyz)，仅供个人学习使用，禁止商业用途。网易云音乐官方选项直接调用网易云公开网页接口。

## 构建

```sh
flutter pub get
flutter build apk --release
```
