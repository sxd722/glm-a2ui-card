# HDC Debug Bridge

本项目提供一个面向本地测试的 Ability 调试入口。它通过 `aa start` 的 Want 参数把命令送入 App，再由 App 内部的白名单路由调用 Forge、Skill 和 Nested App 逻辑。

## 协议

必填参数：

- `debugAction`：固定白名单动作。
- `debugRequestId`：建议填写，用于去重和读取结果。

可选 payload：

- `debugPayload`：普通字符串或 JSON。
- `debugPayloadBase64`：复杂 JSON 的 UTF-8 Base64；与 `debugPayload` 二选一。

当前动作：

`setForgeSource`、`runForgeAnalyze`、`runForgePreview`、`installForgePreview`、`runForgePipeline`、`setSkillFields`、`runSkillAction`、`setNestedFields`、`runNestedAction`、`loadForgeImageFromDevice`、`loadForgeImageDataUrl`、`resetForgeImageTransfer`、`appendForgeImageChunk`、`finishForgeImageTransfer`、`loadTravelDemo`、`resetWorkbench`。

当设备临时目录对 App 沙箱不可读时，可把压缩后的 data URL 使用 `debugPayloadBase64` 传递给 `loadForgeImageDataUrl`。单条解码后的 data URL 不超过 60 KB。

从 HDC 临时目录载入图片：

```powershell
hdc file send C:\Users\bluez\Downloads\skill.png /data/local/tmp/glm-skill-source.png
./docs/debug/hdc-debug.ps1 -Action loadForgeImageFromDevice `
  -Payload /data/local/tmp/glm-skill-source.png
./docs/debug/hdc-debug.ps1 -Action runForgePipeline
```

`loadForgeImageFromDevice` 只允许读取 `/data/local/tmp/` 下的图片，App 会限制图片大小并转为 GLM 视觉请求所需的 data URL。

Windows 命令行长度不足以传输较大的图片时，使用 helper 的 `send-image` 模式。它会在 PC 端压缩图片，并通过多个 HDC chunk 命令重组：

```powershell
./docs/debug/hdc-debug.ps1 -Mode send-image `
  -ImagePath 'C:\Users\bluez\Downloads\141531b8-5d31-4200-a659-9e895079b5db.png' `
  -Target 3UJ0124904000099
```

## 示例

直接加载内置 Nested App：

```powershell
./docs/debug/hdc-debug.ps1 -Action loadTravelDemo
```

批量填充旅行 Skill 字段：

```powershell
$payload = '{"fields":[{"id":"departure","value":"上海"},{"id":"destination","value":"成都"},{"id":"startDate","value":"2026-08-01"},{"id":"endDate","value":"2026-08-03"},{"id":"adults","value":"2"},{"id":"budget","value":"5000"},{"id":"preferences","value":"美食、轻松游"}]}'
./docs/debug/hdc-debug.ps1 -Action setSkillFields -Payload $payload -Base64
```

触发 Nested App 动作：

```powershell
$action = '{"id":"start-planning","label":"开始规划","kind":"navigate","targetPageId":"editor","payload":""}'
./docs/debug/hdc-debug.ps1 -Action runNestedAction -Payload $action -Base64
```

设置 skill.md 文本来源：

```powershell
$skill = Get-Content -Raw .\skill.md
$source = @{ kind = 'text'; value = $skill; fileName = 'skill.md' } | ConvertTo-Json -Compress
./docs/debug/hdc-debug.ps1 -Action setForgeSource -Payload $source -Base64
./docs/debug/hdc-debug.ps1 -Action runForgeAnalyze
```

发送后读取结果：

```powershell
./docs/debug/hdc-debug.ps1 -Mode wait -RequestId <requestId> -WaitSeconds 120
```

也可以直接使用原始 HDC 命令：

```powershell
hdc shell aa start -a EntryAbility -b com.example.glma2uicard `
  --ps debugAction runSkillAction `
  --ps debugRequestId skill-001 `
  --ps debugPayload "执行下一步"
```

## 行为约束

- 命令队列最多缓存 16 条，按顺序串行执行。
- 相同 `debugRequestId` 不会重复执行。
- 冷启动命令先进入队列，页面出现后自动 drain；前台或后台重复启动走 `onNewWant`。
- GLM 单次请求仍遵守 120 秒超时；超时会产生失败回执并终止当前工作流。
- `onDump` 返回最近的脱敏结果。使用 `aa dump -l` 找到本应用 AbilityRecord ID，再使用 `aa dump -i <id> -c` 获取结果。
- dump 和 hilog 不输出 API Key、完整模型输出或完整业务 payload。
- 图片二进制不通过 Want 传输。图片调试命令只能使用 App 已经载入的图片素材。

该入口按当前 Demo 需求在所有 build mode 中启用。由于 `EntryAbility` 为 exported，不能把它当作正式发布环境的安全边界；发布前应增加 debug build gate 或设备口令。
