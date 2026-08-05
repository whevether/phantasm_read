# Add project specific ProGuard rules here.
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

-ignorewarnings

# Flutter / WebView 无需在此 keep：
# - io.flutter.* 由 Flutter Gradle Plugin 自带规则处理
# - androidx.webkit.* 由 webview_flutter 等插件 consumer rules 覆盖
# 若 release 打包报缺类，再按报错补针对性 -keep，勿全局 keep **
