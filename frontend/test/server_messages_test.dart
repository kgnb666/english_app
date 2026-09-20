import "package:flutter_test/flutter_test.dart";
import "package:english_coach/l10n/server_messages.dart";

void main() {
  group("ServerMessages.localize", () {
    test("转换固定英文文案", () {
      expect(
        ServerMessages.localize("Invalid username or password"),
        "用户名或密码错误",
      );
      expect(
        ServerMessages.localize("Current password is incorrect"),
        "当前密码不正确",
      );
    });

    test("转换带变量的英文文案", () {
      expect(
        ServerMessages.localize("Username 'demo' already exists"),
        "用户名「demo」已被注册",
      );
      expect(
        ServerMessages.localize("Email 'demo@test.com' already registered"),
        "邮箱「demo@test.com」已被注册",
      );
    });

    test("中文原文直接透传", () {
      expect(ServerMessages.localize("用户名或密码错误"), "用户名或密码错误");
    });

    test("未知英文/空值退回兜底文案", () {
      expect(
        ServerMessages.localize("Something exploded", fallback: "登录失败"),
        "登录失败",
      );
      expect(ServerMessages.localize(null, fallback: "登录失败"), "登录失败");
      expect(ServerMessages.localize("   ", fallback: "登录失败"), "登录失败");
    });
  });
}
