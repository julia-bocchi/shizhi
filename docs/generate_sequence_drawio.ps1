param(
  [string]$OutputDir = 'img'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:NextId = 1

function New-CellId {
  $script:NextId += 1
  return [string]$script:NextId
}

function Escape-Xml {
  param(
    [AllowNull()]
    [string]$Text
  )

  if ($null -eq $Text) {
    return ''
  }
  return [System.Security.SecurityElement]::Escape($Text)
}

function Get-HeaderStyle {
  param(
    [string]$Type
  )

  if ($Type -eq 'actor') {
    return 'shape=umlActor;whiteSpace=wrap;html=1;strokeWidth=2;fontSize=18;verticalLabelPosition=bottom;verticalAlign=top;'
  }
  if ($Type -eq 'backend') {
    return 'rounded=1;whiteSpace=wrap;html=1;fillColor=#e7f0ff;strokeColor=#000000;strokeWidth=2;fontSize=16;arcSize=10;'
  }
  if ($Type -eq 'store') {
    return 'rounded=1;whiteSpace=wrap;html=1;fillColor=#eaf7e8;strokeColor=#82b366;strokeWidth=2;fontSize=16;arcSize=10;'
  }
  if ($Type -eq 'ai') {
    return 'rounded=1;whiteSpace=wrap;html=1;fillColor=#f3e8ff;strokeColor=#9673a6;strokeWidth=2;fontSize=16;arcSize=10;'
  }
  return 'rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#000000;strokeWidth=2;fontSize=16;arcSize=10;'
}

function Get-ActivationStyle {
  return 'rounded=0;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;strokeWidth=1.5;'
}

function Get-MessageStyle {
  param(
    [bool]$Return = $false
  )

  if ($Return) {
    return 'edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeWidth=1.6;dashed=1;endArrow=open;endFill=0;'
  }
  return 'edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeWidth=1.8;endArrow=blockThin;endFill=1;'
}

function Add-Title {
  param(
    [System.Text.StringBuilder]$Builder,
    [string]$Text
  )

  $id = New-CellId
  [void]$Builder.AppendLine("        <mxCell id=""$id"" value=""$(Escape-Xml $Text)"" style=""text;html=1;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;fontSize=28;fontStyle=1;"" parent=""1"" vertex=""1"">")
  [void]$Builder.AppendLine('          <mxGeometry x="50" y="20" width="900" height="40" as="geometry"/>')
  [void]$Builder.AppendLine('        </mxCell>')
}

function Add-Participant {
  param(
    [System.Text.StringBuilder]$Builder,
    [hashtable]$Participant,
    [hashtable]$Refs
  )

  $id = New-CellId
  $Refs[$Participant.Key] = [ordered]@{
    Id = $id
    CenterX = $Participant.X + 70
    BottomY = 920
  }

  $width = 140
  $height = if ($Participant.Type -eq 'actor') { 110 } else { 56 }
  [void]$Builder.AppendLine("        <mxCell id=""$id"" value=""$(Escape-Xml $Participant.Label)"" style=""$(Get-HeaderStyle $Participant.Type)"" parent=""1"" vertex=""1"">")
  [void]$Builder.AppendLine("          <mxGeometry x=""$($Participant.X)"" y=""70"" width=""$width"" height=""$height"" as=""geometry""/>")
  [void]$Builder.AppendLine('        </mxCell>')

  $lineId = New-CellId
  $startY = if ($Participant.Type -eq 'actor') { 180 } else { 126 }
  $centerX = $Participant.X + 70
  [void]$Builder.AppendLine("        <mxCell id=""$lineId"" value="""" style=""endArrow=none;html=1;dashed=1;strokeWidth=1.4;"" parent=""1"" edge=""1"">")
  [void]$Builder.AppendLine('          <mxGeometry relative="1" as="geometry">')
  [void]$Builder.AppendLine("            <mxPoint x=""$centerX"" y=""$startY"" as=""sourcePoint""/>")
  [void]$Builder.AppendLine("            <mxPoint x=""$centerX"" y=""920"" as=""targetPoint""/>")
  [void]$Builder.AppendLine('          </mxGeometry>')
  [void]$Builder.AppendLine('        </mxCell>')
}

function Add-Activation {
  param(
    [System.Text.StringBuilder]$Builder,
    [string]$ParticipantType,
    [int]$CenterX,
    [int]$Y
  )

  if ($ParticipantType -eq 'actor') {
    return
  }
  $id = New-CellId
  $x = $CenterX - 10
  [void]$Builder.AppendLine("        <mxCell id=""$id"" value="""" style=""$(Get-ActivationStyle)"" parent=""1"" vertex=""1"">")
  [void]$Builder.AppendLine("          <mxGeometry x=""$x"" y=""$Y"" width=""20"" height=""52"" as=""geometry""/>")
  [void]$Builder.AppendLine('        </mxCell>')
}

function Add-Message {
  param(
    [System.Text.StringBuilder]$Builder,
    [hashtable]$Refs,
    [hashtable]$Participants,
    [hashtable]$Message
  )

  $edgeId = New-CellId
  $source = $Refs[$Message.From]
  $target = $Refs[$Message.To]
  $style = Get-MessageStyle -Return ([bool]$Message.Return)
  [void]$Builder.AppendLine("        <mxCell id=""$edgeId"" value=""$(Escape-Xml $Message.Label)"" style=""$style"" parent=""1"" edge=""1"">")
  [void]$Builder.AppendLine('          <mxGeometry relative="1" as="geometry">')
  [void]$Builder.AppendLine("            <mxPoint x=""$($source.CenterX)"" y=""$($Message.Y)"" as=""sourcePoint""/>")
  [void]$Builder.AppendLine("            <mxPoint x=""$($target.CenterX)"" y=""$($Message.Y)"" as=""targetPoint""/>")
  [void]$Builder.AppendLine('          </mxGeometry>')
  [void]$Builder.AppendLine('        </mxCell>')

  if (-not [bool]$Message.Return -and $Participants[$Message.To].Type -ne 'actor') {
    Add-Activation -Builder $Builder -ParticipantType $Participants[$Message.To].Type -CenterX $target.CenterX -Y ($Message.Y - 14)
  }
}

function Build-DrawioXml {
  param(
    [hashtable]$Diagram
  )

  $script:NextId = 1
  $refs = @{}
  $participantsMap = @{}
  foreach ($p in $Diagram.Participants) {
    $participantsMap[$p.Key] = $p
  }

  $sb = [System.Text.StringBuilder]::new()
  [void]$sb.AppendLine('<mxfile host="app.diagrams.net">')
  [void]$sb.AppendLine("  <diagram id=""$(New-CellId)"" name=""第 1 页"">")
  [void]$sb.AppendLine('    <mxGraphModel dx="1600" dy="1000" grid="0" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="2200" pageHeight="1400" math="0" shadow="0">')
  [void]$sb.AppendLine('      <root>')
  [void]$sb.AppendLine('        <mxCell id="0"/>')
  [void]$sb.AppendLine('        <mxCell id="1" parent="0"/>')

  Add-Title -Builder $sb -Text $Diagram.Title
  foreach ($participant in $Diagram.Participants) {
    Add-Participant -Builder $sb -Participant $participant -Refs $refs
  }
  foreach ($message in $Diagram.Messages) {
    Add-Message -Builder $sb -Refs $refs -Participants $participantsMap -Message $message
  }

  [void]$sb.AppendLine('      </root>')
  [void]$sb.AppendLine('    </mxGraphModel>')
  [void]$sb.AppendLine('  </diagram>')
  [void]$sb.AppendLine('</mxfile>')
  return $sb.ToString()
}

function Write-Diagram {
  param(
    [hashtable]$Diagram,
    [string]$BaseDir
  )

  $path = Join-Path $BaseDir $Diagram.File
  $content = Build-DrawioXml -Diagram $Diagram
  [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$diagrams = @(
  @{
    File = 'home_sequence.drawio'
    Title = 'Home 模块顺序图：首页概览加载'
    Participants = @(
      @{ Key = 'user'; Label = '用户'; Type = 'actor'; X = 40 },
      @{ Key = 'page'; Label = 'HomeTabPage'; Type = 'page'; X = 260 },
      @{ Key = 'helper'; Label = 'HomeDashboardHelper'; Type = 'page'; X = 520 },
      @{ Key = 'store'; Label = 'PersistentStorage'; Type = 'store'; X = 800 }
    )
    Messages = @(
      @{ From = 'user'; To = 'page'; Label = '打开首页'; Y = 220; Return = $false },
      @{ From = 'page'; To = 'store'; Label = '读取 foodPlan / workoutRecord / weightRecord / userProfile'; Y = 300; Return = $false },
      @{ From = 'page'; To = 'helper'; Label = 'getTodayDashboardCalories()'; Y = 380; Return = $false },
      @{ From = 'helper'; To = 'store'; Label = '读取今日饮食/训练缓存'; Y = 460; Return = $false },
      @{ From = 'store'; To = 'helper'; Label = '返回摄入/消耗数据'; Y = 540; Return = $true },
      @{ From = 'page'; To = 'helper'; Label = 'getHomeWeightTrend()/getHomeReminderItems()'; Y = 620; Return = $false },
      @{ From = 'helper'; To = 'store'; Label = '读取体重/资料缓存'; Y = 700; Return = $false },
      @{ From = 'helper'; To = 'page'; Label = '返回趋势、提醒、摘要'; Y = 780; Return = $true },
      @{ From = 'page'; To = 'user'; Label = '渲染今日概览'; Y = 860; Return = $true }
    )
  },
  @{
    File = 'record_sequence.drawio'
    Title = 'Record 模块顺序图：submitWeightRecord()'
    Participants = @(
      @{ Key = 'user'; Label = '用户'; Type = 'actor'; X = 30 },
      @{ Key = 'page'; Label = 'RecordTabPage'; Type = 'page'; X = 220 },
      @{ Key = 'store'; Label = 'PersistentStorage'; Type = 'store'; X = 470 },
      @{ Key = 'sync'; Label = 'SyncService'; Type = 'page'; X = 730 },
      @{ Key = 'server'; Label = 'mock-backend/server.js'; Type = 'backend'; X = 980 },
      @{ Key = 'db'; Label = 'data.json'; Type = 'store'; X = 1280 }
    )
    Messages = @(
      @{ From = 'user'; To = 'page'; Label = '输入体重并点击保存'; Y = 220; Return = $false },
      @{ From = 'page'; To = 'store'; Label = 'addOrUpdateRecord() 覆盖 weightRecordText'; Y = 300; Return = $false },
      @{ From = 'page'; To = 'sync'; Label = 'syncOperationNowOrQueue(weight upsert)'; Y = 380; Return = $false },
      @{ From = 'sync'; To = 'server'; Label = 'PUT /weight-records/{date}'; Y = 460; Return = $false },
      @{ From = 'server'; To = 'db'; Label = 'loadStore() / 定位 user.weightRecords'; Y = 540; Return = $false },
      @{ From = 'server'; To = 'db'; Label = 'saveStore() 写回新增/覆盖结果'; Y = 620; Return = $false },
      @{ From = 'server'; To = 'sync'; Label = '返回 record + isUpdated'; Y = 700; Return = $true },
      @{ From = 'sync'; To = 'store'; Label = '更新 pendingSyncQueue / lastSyncSuccess / 远端 ID'; Y = 780; Return = $false },
      @{ From = 'sync'; To = 'page'; Label = '返回 syncedImmediately + state'; Y = 860; Return = $true },
      @{ From = 'page'; To = 'user'; Label = '显示同步成功或离线提示'; Y = 940; Return = $true }
    )
  },
  @{
    File = 'food_sequence.drawio'
    Title = 'Food 模块顺序图：saveTodaySelections()'
    Participants = @(
      @{ Key = 'user'; Label = '用户'; Type = 'actor'; X = 20 },
      @{ Key = 'page'; Label = 'FoodSelectionPage'; Type = 'page'; X = 200 },
      @{ Key = 'store'; Label = 'PersistentStorage'; Type = 'store'; X = 450 },
      @{ Key = 'sync'; Label = 'SyncService'; Type = 'page'; X = 710 },
      @{ Key = 'server'; Label = 'mock-backend/server.js'; Type = 'backend'; X = 970 },
      @{ Key = 'db'; Label = 'data.json'; Type = 'store'; X = 1260 }
    )
    Messages = @(
      @{ From = 'user'; To = 'page'; Label = '选择食物并点击保存'; Y = 220; Return = $false },
      @{ From = 'page'; To = 'store'; Label = 'saveFoodPlans() 替换当天餐次的本地 foodPlanText'; Y = 300; Return = $false },
      @{ From = 'page'; To = 'sync'; Label = 'syncOperationNowOrQueue(food_meal replace)'; Y = 380; Return = $false },
      @{ From = 'sync'; To = 'server'; Label = 'GET /food-plans?startDate=date&endDate=date'; Y = 460; Return = $false },
      @{ From = 'server'; To = 'db'; Label = 'loadStore() / 查询现有 meal plans'; Y = 540; Return = $false },
      @{ From = 'server'; To = 'sync'; Label = '返回当前餐次列表'; Y = 620; Return = $true },
      @{ From = 'sync'; To = 'server'; Label = 'DELETE 旧餐次 + POST 新 food-plans'; Y = 700; Return = $false },
      @{ From = 'server'; To = 'db'; Label = 'ensureFoodOptionForPlan() + saveStore()'; Y = 780; Return = $false },
      @{ From = 'server'; To = 'sync'; Label = '返回新计划'; Y = 860; Return = $true },
      @{ From = 'sync'; To = 'store'; Label = 'replaceLocalFoodMeal() 回填远端计划'; Y = 940; Return = $false },
      @{ From = 'sync'; To = 'page'; Label = '返回 state / syncedImmediately'; Y = 1020; Return = $true },
      @{ From = 'page'; To = 'user'; Label = '提示保存成功并返回'; Y = 1100; Return = $true }
    )
  },
  @{
    File = 'exercise_sequence.drawio'
    Title = 'Exercise 模块顺序图：finishAndSaveSession()'
    Participants = @(
      @{ Key = 'user'; Label = '用户'; Type = 'actor'; X = 20 },
      @{ Key = 'page'; Label = 'ExerciseDetailPage'; Type = 'page'; X = 200 },
      @{ Key = 'store'; Label = 'PersistentStorage'; Type = 'store'; X = 450 },
      @{ Key = 'sync'; Label = 'SyncService'; Type = 'page'; X = 710 },
      @{ Key = 'server'; Label = 'mock-backend/server.js'; Type = 'backend'; X = 970 },
      @{ Key = 'db'; Label = 'data.json'; Type = 'store'; X = 1260 }
    )
    Messages = @(
      @{ From = 'user'; To = 'page'; Label = '结束训练并保存'; Y = 220; Return = $false },
      @{ From = 'page'; To = 'page'; Label = '计算 calories / metrics / nextRecord'; Y = 300; Return = $false },
      @{ From = 'page'; To = 'store'; Label = 'serializeWorkoutRecords() 写入本地记录'; Y = 380; Return = $false },
      @{ From = 'page'; To = 'sync'; Label = 'syncOperationNowOrQueue(workout_record create)'; Y = 460; Return = $false },
      @{ From = 'sync'; To = 'server'; Label = 'POST /workout-records'; Y = 540; Return = $false },
      @{ From = 'server'; To = 'db'; Label = 'loadStore() / 追加 workoutRecords'; Y = 620; Return = $false },
      @{ From = 'server'; To = 'db'; Label = 'saveStore()'; Y = 700; Return = $false },
      @{ From = 'server'; To = 'sync'; Label = '返回 remoteRecord'; Y = 780; Return = $true },
      @{ From = 'sync'; To = 'store'; Label = 'replaceEntityIdInState() / 回填远端 ID'; Y = 860; Return = $false },
      @{ From = 'sync'; To = 'page'; Label = '返回同步后的 state'; Y = 940; Return = $true },
      @{ From = 'page'; To = 'user'; Label = 'goBack() 并看到记录已更新'; Y = 1020; Return = $true }
    )
  },
  @{
    File = 'assistant_sequence.drawio'
    Title = 'Assistant 模块顺序图：submitToAssistant()'
    Participants = @(
      @{ Key = 'user'; Label = '用户'; Type = 'actor'; X = 20 },
      @{ Key = 'page'; Label = 'AiAssistantTabPage'; Type = 'page'; X = 200 },
      @{ Key = 'config'; Label = 'assistant-config-cache'; Type = 'store'; X = 450 },
      @{ Key = 'context'; Label = 'health-plan-cache'; Type = 'store'; X = 700 },
      @{ Key = 'helper'; Label = 'AiAssistantHelper'; Type = 'page'; X = 950 },
      @{ Key = 'ai'; Label = 'BigModel Chat API'; Type = 'ai'; X = 1200 }
    )
    Messages = @(
      @{ From = 'user'; To = 'page'; Label = '输入问题并发送'; Y = 220; Return = $false },
      @{ From = 'page'; To = 'config'; Label = '读取 aiApiEndpoint / model / key / history'; Y = 300; Return = $false },
      @{ From = 'page'; To = 'context'; Label = '读取体重/训练/计划/食物上下文'; Y = 380; Return = $false },
      @{ From = 'page'; To = 'helper'; Label = 'requestAiAssistant(task, context)'; Y = 460; Return = $false },
      @{ From = 'helper'; To = 'ai'; Label = 'HTTPS Chat Completions 请求'; Y = 540; Return = $false },
      @{ From = 'ai'; To = 'helper'; Label = '返回 reply / plans / foodPlans'; Y = 620; Return = $true },
      @{ From = 'helper'; To = 'page'; Label = '解析成 AiAssistantResponse'; Y = 700; Return = $true },
      @{ From = 'page'; To = 'config'; Label = 'saveConversationSnapshot() 写回会话历史'; Y = 780; Return = $false },
      @{ From = 'page'; To = 'user'; Label = '显示回复与可导入草案'; Y = 860; Return = $true }
    )
  },
  @{
    File = 'profile_auth_sequence.drawio'
    Title = 'Profile/Auth 模块顺序图：handleLogin()'
    Participants = @(
      @{ Key = 'user'; Label = '用户'; Type = 'actor'; X = 20 },
      @{ Key = 'page'; Label = 'LoginPage'; Type = 'page'; X = 220 },
      @{ Key = 'api'; Label = 'ApiService'; Type = 'page'; X = 470 },
      @{ Key = 'cache'; Label = 'account-cache'; Type = 'store'; X = 720 },
      @{ Key = 'server'; Label = 'mock-backend/server.js'; Type = 'backend'; X = 970 },
      @{ Key = 'db'; Label = 'data.json'; Type = 'store'; X = 1260 }
    )
    Messages = @(
      @{ From = 'user'; To = 'page'; Label = '输入账号密码并登录'; Y = 220; Return = $false },
      @{ From = 'page'; To = 'api'; Label = 'loginWithPassword(username, password)'; Y = 300; Return = $false },
      @{ From = 'api'; To = 'server'; Label = 'POST /auth/login'; Y = 380; Return = $false },
      @{ From = 'server'; To = 'db'; Label = 'loadStore() / 校验用户密码 / saveStore(token)'; Y = 460; Return = $false },
      @{ From = 'server'; To = 'api'; Label = '返回 authSession'; Y = 540; Return = $true },
      @{ From = 'page'; To = 'cache'; Label = '保存 authSessionText'; Y = 620; Return = $false },
      @{ From = 'page'; To = 'api'; Label = 'fetchUserProfile(authSession)'; Y = 700; Return = $false },
      @{ From = 'api'; To = 'server'; Label = 'GET /user-profile'; Y = 780; Return = $false },
      @{ From = 'server'; To = 'db'; Label = 'ensureUser() / 读取 profile'; Y = 860; Return = $false },
      @{ From = 'server'; To = 'api'; Label = '返回 profile'; Y = 940; Return = $true },
      @{ From = 'page'; To = 'cache'; Label = 'serializeUserProfile() 写入 userProfileText'; Y = 1020; Return = $false },
      @{ From = 'page'; To = 'user'; Label = '提示登录成功并返回首页'; Y = 1100; Return = $true }
    )
  }
)

foreach ($diagram in $diagrams) {
  Write-Diagram -Diagram $diagram -BaseDir $OutputDir
}
