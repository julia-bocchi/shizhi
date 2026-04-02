# shizhi

一个基于 HarmonyOS ArkTS/ETS 的体重记录小应用。

## 当前功能

- 首页目前保留为空页面，用来承接后续扩展。
- 底部提供固定导航，支持首页与记录页切换，并加了更直观的图形符号。
- 记录页支持录入或覆盖当天体重。
- 提供近 7 次趋势、均值、反馈文案和最近记录列表。
- 柱状图顶部支持在“表情标签”和“文字标签”之间切换。

## 项目结构

```text
.
├─ AppScope/                          # 应用级配置与资源
├─ entry/
│  └─ src/main/
│     ├─ ets/
│     │  ├─ components/
│     │  │  └─ MainBottomNavigation.ets   # 底部导航组件
│     │  ├─ constants/
│     │  │  └─ AppTheme.ets               # 页面主题色与共享样式常量
│     │  ├─ models/
│     │  │  ├─ TabItem.ets                # 底部页签模型
│     │  │  └─ WeightRecord.ets           # 体重记录数据模型
│     │  ├─ pages/
│     │  │  ├─ home/
│     │  │  │  └─ HomeTabPage.ets         # 首页
│     │  │  ├─ record/
│     │  │  │  └─ RecordTabPage.ets       # 体重记录页
│     │  │  └─ Index.ets                  # 页面入口与页签切换容器
│     │  ├─ utils/
│     │  │  └─ WeightRecordHelper.ets     # 日期、图表、示例数据等工具函数
│     │  ├─ entryability/
│     │  └─ entrybackupability/
│     └─ resources/                       # 模块资源
├─ hvigor/                               # HarmonyOS 构建配置
└─ README.md
```

## 页面说明

### 首页

当前不放业务内容，只保留底部导航，方便后续继续扩展卡片、概览或快捷操作。

### 记录页

- 顶部展示当前体重与近 7 次变化。
- 中间支持录入当天体重。
- 趋势图显示最近 7 次记录。
- 柱状图顶部标签可以切换成表情或文字，适合不同阅读习惯。

## 后续扩展建议

- 在首页加入本周概览、快捷记录入口或目标体重卡片。
- 将当前示例数据替换为本地持久化存储。
- 为底部导航继续扩展“我的”或“设置”页签。
