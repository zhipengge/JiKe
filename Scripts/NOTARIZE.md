# 签名与公证操作指引

已发布的 1.0.0 / 1.0.1 / 1.0.2 都是 **ad-hoc 签名**，用户必须「右键 → 打开」才能启动。
这份文档是把它们换成正式公证版所需的全部步骤。

工具链已经在 `release.sh` 里写好了，**不需要改脚本**，配好证书和凭据直接跑即可。

---

## 前置：两个条件

### 条件一：付费的 Apple Developer 账号

Developer ID 证书**只有付费会员**（$99/年）能创建。你机器上已有 3 张
`Apple Development` 证书，说明有开发者账号，但要确认是付费的那种。

查法：登录 <https://developer.apple.com/account> → 左侧 `Certificates, Identifiers & Profiles`
→ 如果能看到 `Developer ID Application` 这个证书类型，就是付费账号。

### 条件二：创建 Developer ID Application 证书

1. 打开 <https://developer.apple.com/account/resources/certificates/list>
2. 点 `+` → 选 **Developer ID Application** → Continue
3. 它要求上传一个 CSR 文件。先生成：

   ```bash
   # 在「钥匙串访问」里：钥匙串访问 → 证书助理 → 从证书颁发机构请求证书
   # 常用名称填你的名字，选「存储到磁盘」，得到一个 .certSigningRequest 文件
   ```

4. 上传 CSR → 下载 `.cer` → 双击导入钥匙串

导入后验证：

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

**这一行必须出现**，否则后面的签名会退回 ad-hoc。

---

## 第一步：存公证凭据

`notarytool` 需要一份存在钥匙串里的凭据。用 App 专用密码（不是 Apple ID 密码）：

1. 打开 <https://account.apple.com> → 登录 → `登录与安全` → `App 专用密码` → 生成一个
2. 记下 Team ID（<https://developer.apple.com/account> 的 Membership 页，形如 `ABCDE12345`）
3. 存进钥匙串：

```bash
xcrun notarytool store-credentials "AC_PASSWORD" \
  --apple-id "你的AppleID邮箱" \
  --team-id "你的TeamID" \
  --password "刚生成的App专用密码"
```

`AC_PASSWORD` 是 profile 名，可以随便取，但要和下一步传的 `NOTARY_PROFILE` 一致。

苹果会拿这个账号去 `altool` 验证一次，看到 `Credentials saved to keychain` 就成功了。

---

## 第二步：重打一版并上传

改一下版本号（`CURRENT_PROJECT_VERSION` 要涨，`MARKETING_VERSION` 按需）：

```bash
cd /Users/gezhipeng/m3_apps/JiKe

# 打包：自动找 Developer ID 签名 → 公证 → staple → 出 zip/dmg/sha256
NOTARY_PROFILE="AC_PASSWORD" ./Scripts/release.sh 1.0.3
```

脚本里已有的行为：

- 没传 `SIGN_IDENTITY` 时会**自动搜索** Developer ID Application，找到就用
- 同时传了 `NOTARY_PROFILE` 才会走公证，否则只签名并提示「已签名但未公证」
- 公证用 `--wait` 同步等结果，完了自动 `stapler staple` 并验证

跑完检查：

```bash
# 签名者应该是 Developer ID，不再是 adhoc
codesign -dv --verbose=2 dist/JiKe-1.0.3.app | grep Authority

# 公证票据应该能验证通过
xcrun stapler validate dist/JiKe-1.0.3.app

# Gatekeeper 应该放行
spctl -a -vv -t exec dist/JiKe-1.0.3.app
```

最后一条输出 `accepted` 才算成功。

---

## 第三步：上传 Release

把上一步和上传合成一条命令：

```bash
CREATE_GITHUB_RELEASE=1 NOTARY_PROFILE="AC_PASSWORD" ./Scripts/release.sh 1.0.3
```

脚本会自己判断：`v1.0.3` 已存在就 `gh release upload --clobber` 覆盖资产，
不存在就 `gh release create`。**Release 说明由脚本生成**（含校验方式与隐私政策链接），
不要手写覆盖它。

**注意**：脚本里那段说明模板有「首次请右键打开」之类的措辞吗？有的话顺手改掉——
公证版再让人右键打开，会显得包仍然有问题。模板在 `Scripts/release.sh` 的 `NOTES` 变量里。

历史版本（1.0.0 / 1.0.1 / 1.0.2）要不要重新用公证版覆盖，由你决定。
替换单个资产：`gh release upload <tag> <file> --clobber`。

---

## 常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| `release.sh` 打印「未找到 Developer ID Application，将打出未公证包」 | 证书没装进钥匙串，或不是付费账号 | 回到「条件二」 |
| `notarytool` 报 `Invalid credentials` | App 专用密码错，或 Team ID 错 | 重新 `store-credentials` |
| 公证返回 `Invalid` | 包里某处没签名或缺 Hardened Runtime | `xcrun notarytool log <submission-id> --keychain-profile AC_PASSWORD` 看详情 |
| 公证通过但 `spctl` 仍拒绝 | 忘了 staple，或验的是旧包 | 确认验的是 `dist/` 下的新产物 |
| 想跳过公证快速出包 | — | `SKIP_NOTARY=1 ./Scripts/release.sh x.y.z` |

---

## 参考

- [notarytool 官方文档](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- 脚本：`Scripts/release.sh`（本文所有命令都从它里面来）
