# 示例应用的签名文件（仅本地，不入库）

签名文件（`*.jks`）和 `example/android/key.properties` 已从版本库移除，并由 `.gitignore` 忽略。没有这些文件时，release 构建会自动回退到 debug 签名，因此克隆仓库后可以直接运行示例。

> 该签名只用于示例应用本地打包，**不可**用于正式发布。

## 创建本地签名（可选）

```sh
keytool -genkeypair -v \
  -keystore example/jks/local_release.jks \
  -alias local_release -keyalg RSA -keysize 2048 -validity 10000
```

然后复制 `example/android/key.properties.example` 为 `example/android/key.properties`，填入真实的别名、密码和 `storeFile` 路径（相对 `example/android/app`）。

```properties
storeFile=../../jks/local_release.jks
keyAlias=local_release
storePassword=...
keyPassword=...
```

不要把 `key.properties` 或 `.jks` 提交到 Git。
