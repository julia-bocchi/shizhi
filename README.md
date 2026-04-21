# shizhi

一个基于 HarmonyOS ArkTS/ETS 的体重追踪与训练辅助应用。

现在应用已经包含：

- 体重记录与趋势分析
- 训练页与训练计划管理
- 用户资料页
- AI 助手页
- AI 生成训练计划并导入训练页

## 功能概览

### 1. AI 助手

- AI 助手现在是独立页签，首页保持空白。
- AI 页可以直接提问训练与体重管理问题。
- AI 会读取最近体重记录、最近训练记录和当前用户资料，再输出建议。
- AI 可以生成训练计划草案，用户可以先修改日期、标题、备注，再导入训练页。
- 页面里的默认接口地址、默认模型、默认 API Key，来自 [entry/src/main/ets/models/AiAssistant.ets](entry/src/main/ets/models/AiAssistant.ets)。
- 如果本地已经保存过旧配置，可以在 AI 助手页点击“恢复默认配置”重新回填。

### 2. 体重记录

- 支持录入或覆盖当天体重。
- 自动展示最近 7 次变化、平均体重和趋势反馈。
- 体重数据已经接入本地持久化，AI 可以读取真实历史记录。

### 3. 训练与计划

- 支持从预设训练或自定义模板生成训练计划。
- AI 生成的训练草案可以导入到训练页日历中。
- 导入后的计划可以在训练页中查看、开始训练或删除。

### 4. 用户资料

- 支持填写昵称、身高、体重、年龄、性别。
- 资料会同步影响训练热量估算和 AI 上下文。

## 默认 AI 平台

当前默认接入的是智谱 BigModel 的 HTTP Chat Completions 接口。

- 默认接口地址：`https://open.bigmodel.cn/api/paas/v4/chat/completions`
- 默认模型：`glm-5.1`
- 默认 Key：从 `AiAssistant.ets` 中的 `DEFAULT_API_KEY` 读取

官方文档：

- BigModel HTTP 接入说明：https://docs.bigmodel.cn/cn/guide/develop/http/introduction

## 关键文件

```text
entry/src/main/ets/
├─ models/
│  ├─ AiAssistant.ets           # AI 默认配置、消息与草案模型
│  ├─ UserProfile.ets           # 用户资料模型
│  ├─ WeightRecord.ets          # 体重记录模型
│  ├─ WorkoutPlan.ets           # 训练计划模型
│  └─ WorkoutRecord.ets         # 训练记录模型
├─ pages/
│  ├─ home/HomeTabPage.ets      # 空白首页
│  ├─ assistant/AiAssistantTabPage.ets # AI 助手页
│  ├─ exercise/                 # 训练页与训练详情页
│  ├─ record/RecordTabPage.ets  # 体重记录页
│  ├─ profile/ProfileTabPage.ets# 用户资料页
│  └─ Index.ets                 # 应用入口与标签页切换
└─ utils/
   ├─ AiAssistantHelper.ets     # AI 请求封装与返回解析
   ├─ WeightRecordHelper.ets    # 体重数据工具
   ├─ WorkoutPlanHelper.ets     # 训练计划序列化与生成
   ├─ ExerciseHelper.ets        # 训练草稿与训练计算工具
   └─ ExerciseStorage.ets       # 持久化键注册
```

## 使用说明

### 1. 配置 AI

打开 AI 助手页后，页面会优先读取本地已保存配置；如果为空，则使用 `AiAssistant.ets` 中的默认值。

你可以：

- 直接使用默认 BigModel 配置
- 在页面中手动修改接口地址、模型和 API Key
- 点击“恢复 BigModel 默认”回退到 `AiAssistant.ets` 的默认配置

### 2. 生成建议

- 点击“分析体重趋势”可以快速生成基于最近体重变化的建议
- 也可以在输入框中自由提问，例如：
  - `我最近体重反弹了，训练应该怎么调整？`
  - `我适合先做有氧还是力量？`

### 3. 导入训练计划

- 点击“生成计划草案”
- 等待 AI 返回草案
- 修改日期、标题、备注
- 点击“导入计划”或“全部导入”
- 切换到训练页查看结果

## 开发说明

- AI 接口当前走前端直连，适合本地联调和原型验证。
- 当前页面会把 AI 配置保存在本地持久化存储中。
- 如果仓库会公开，建议不要把真实 API Key 长期写在源码常量里，生产环境建议改为后端代理。

## 构建

推荐使用 DevEco Studio 打开项目后进行同步和构建。

如果命令行环境里缺少 `hvigor` / `ohpm`，可能无法在终端直接完成完整构建，但不影响在 DevEco Studio 中调试。
