import 'package:flutter_test/flutter_test.dart';
import 'package:hjyz_bbs/core/utils/deep_link_helper.dart';

void main() {
  test('解析标准帖子深度链接', () {
    final location = DeepLinkHelper.locationFor(
      Uri.parse('hyjzbbs://thread/85'),
    );

    expect(location, '/thread/85');
  });

  test('兼容无主机名的帖子深度链接', () {
    final location = DeepLinkHelper.locationFor(
      Uri.parse('hyjzbbs:///thread/85'),
    );

    expect(location, '/thread/85');
  });

  test('拒绝无效帖子编号和其他协议', () {
    expect(
      DeepLinkHelper.locationFor(Uri.parse('hyjzbbs://thread/invalid')),
      isNull,
    );
    expect(
      DeepLinkHelper.locationFor(Uri.parse('https://thread/85')),
      isNull,
    );
  });

  test('解析短链接跳转', () {
    expect(
      DeepLinkHelper.locationFor(Uri.parse('hyjzbbs://dv/abc123')),
      '/dv/abc123',
    );
  });
}
