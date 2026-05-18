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

function Build-Label {
  param(
    [string]$Stereotype,
    [string]$Name,
    [string]$Detail = ''
  )

  $label = "&lt;&lt;$Stereotype&gt;&gt;<div><b>$Name</b></div>"
  if ($Detail.Trim().Length -gt 0) {
    $formattedDetail = $Detail.Replace("`n", '<br/>')
    $label += "<div><font style=""font-size:12px;color:#666666;"">$formattedDetail</font></div>"
  }
  return $label
}

function Get-NodeStyle {
  param(
    [string]$Type
  )

  switch ($Type) {
    'page' {
      return 'shape=component;whiteSpace=wrap;html=1;align=center;verticalAlign=top;spacingTop=12;fillColor=#ffffff;strokeColor=#000000;strokeWidth=2;fontSize=17;'
    }
    'pack' {
      return 'shape=component;whiteSpace=wrap;html=1;align=center;verticalAlign=top;spacingTop=12;fillColor=#f5f5f5;strokeColor=#000000;strokeWidth=2;fontSize=17;'
    }
    'store' {
      return 'shape=component;whiteSpace=wrap;html=1;align=center;verticalAlign=top;spacingTop=12;fillColor=#eaf7e8;strokeColor=#82b366;strokeWidth=2;fontSize=17;'
    }
    'backend' {
      return 'shape=component;whiteSpace=wrap;html=1;align=center;verticalAlign=top;spacingTop=12;fillColor=#e7f0ff;strokeColor=#6c8ebf;strokeWidth=2;fontSize=17;'
    }
    'ai' {
      return 'shape=component;whiteSpace=wrap;html=1;align=center;verticalAlign=top;spacingTop=12;fillColor=#f3e8ff;strokeColor=#9673a6;strokeWidth=2;fontSize=17;'
    }
    'device' {
      return 'shape=component;whiteSpace=wrap;html=1;align=center;verticalAlign=top;spacingTop=12;fillColor=#fff4d6;strokeColor=#d6b656;strokeWidth=2;fontSize=17;'
    }
    default {
      return 'shape=component;whiteSpace=wrap;html=1;align=center;verticalAlign=top;spacingTop=12;fillColor=#ffffff;strokeColor=#000000;strokeWidth=2;fontSize=17;'
    }
  }
}

function Get-EdgeStyle {
  return 'edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeWidth=1.8;dashed=1;endArrow=open;endFill=0;'
}

function Add-Node {
  param(
    [System.Text.StringBuilder]$Builder,
    [hashtable]$Node,
    [hashtable]$Refs
  )

  $id = New-CellId
  $Refs[$Node.Key] = $id
  $label = Build-Label -Stereotype $Node.Stereotype -Name $Node.Name -Detail $Node.Detail
  [void]$Builder.AppendLine("        <mxCell id=""$id"" value=""$(Escape-Xml $label)"" style=""$(Get-NodeStyle $Node.Type)"" parent=""1"" vertex=""1"">")
  [void]$Builder.AppendLine("          <mxGeometry x=""$($Node.X)"" y=""$($Node.Y)"" width=""$($Node.Width)"" height=""$($Node.Height)"" as=""geometry""/>")
  [void]$Builder.AppendLine('        </mxCell>')
}

function Add-Edge {
  param(
    [System.Text.StringBuilder]$Builder,
    [hashtable]$Edge,
    [hashtable]$Refs
  )

  $id = New-CellId
  $style = Get-EdgeStyle
  if ($Edge.ContainsKey('ExitX')) {
    $style += "exitX=$($Edge.ExitX);exitY=$($Edge.ExitY);exitDx=0;exitDy=0;"
  }
  if ($Edge.ContainsKey('EntryX')) {
    $style += "entryX=$($Edge.EntryX);entryY=$($Edge.EntryY);entryDx=0;entryDy=0;"
  }
  $label = Escape-Xml $Edge.Label
  [void]$Builder.AppendLine("        <mxCell id=""$id"" value=""$label"" style=""$style"" parent=""1"" source=""$($Refs[$Edge.From])"" target=""$($Refs[$Edge.To])"" edge=""1"">")
  [void]$Builder.AppendLine('          <mxGeometry relative="1" as="geometry">')
  if ($Edge.ContainsKey('Points') -and $Edge.Points.Count -gt 0) {
    [void]$Builder.AppendLine('            <Array as="points">')
    foreach ($point in $Edge.Points) {
      [void]$Builder.AppendLine("              <mxPoint x=""$($point.X)"" y=""$($point.Y)""/>")
    }
    [void]$Builder.AppendLine('            </Array>')
  }
  [void]$Builder.AppendLine('          </mxGeometry>')
  [void]$Builder.AppendLine('        </mxCell>')
}

function Build-DrawioXml {
  param(
    [hashtable]$Diagram
  )

  $script:NextId = 1
  $refs = @{}
  $sb = [System.Text.StringBuilder]::new()

  [void]$sb.AppendLine('<mxfile host="app.diagrams.net">')
  [void]$sb.AppendLine("  <diagram id=""$(New-CellId)"" name=""第 1 页"">")
  [void]$sb.AppendLine('    <mxGraphModel dx="1600" dy="1000" grid="0" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="2200" pageHeight="1400" math="0" shadow="0">')
  [void]$sb.AppendLine('      <root>')
  [void]$sb.AppendLine('        <mxCell id="0"/>')
  [void]$sb.AppendLine('        <mxCell id="1" parent="0"/>')

  foreach ($node in $Diagram.Nodes) {
    Add-Node -Builder $sb -Node $node -Refs $refs
  }

  foreach ($edge in $Diagram.Edges) {
    Add-Edge -Builder $sb -Edge $edge -Refs $refs
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

  $content = Build-DrawioXml -Diagram $Diagram
  $path = Join-Path $BaseDir $Diagram.File
  [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$diagrams = @(
  @{
    File = 'home.drawio'
    Nodes = @(
      @{ Key = 'router'; Type = 'pack'; Stereotype = 'Harmony ETS Pack'; Name = 'tabRouter'; Detail = 'Index.ets / MainBottomNavigation'; X = 120; Y = 120; Width = 280; Height = 110 },
      @{ Key = 'cache'; Type = 'store'; Stereotype = 'PersistentStorage'; Name = 'local-health-cache'; Detail = "userProfileText`nweightRecordText`nfoodPlanText / workoutRecordText"; X = 120; Y = 430; Width = 300; Height = 150 },
      @{ Key = 'home'; Type = 'page'; Stereotype = 'Harmony ETS Page'; Name = 'HomeTabPage.ets'; Detail = '今日概览 / 快捷入口 / 仪表盘'; X = 520; Y = 250; Width = 280; Height = 120 },
      @{ Key = 'dashboard'; Type = 'pack'; Stereotype = 'Harmony ETS Pack'; Name = 'homeDashboard'; Detail = 'HomeDashboardHelper'; X = 980; Y = 240; Width = 280; Height = 110 },
      @{ Key = 'sync'; Type = 'pack'; Stereotype = 'Harmony ETS Pack'; Name = 'syncCore'; Detail = '其他业务页同步后刷新首页数据'; X = 980; Y = 430; Width = 280; Height = 110 }
    )
    Edges = @(
      @{ From = 'home'; To = 'router'; Label = 'Tab 路由依赖'; ExitX = 0; ExitY = 0.35; EntryX = 1; EntryY = 0.55 },
      @{ From = 'home'; To = 'dashboard'; Label = '摘要计算'; ExitX = 1; ExitY = 0.50; EntryX = 0; EntryY = 0.50 },
      @{ From = 'dashboard'; To = 'cache'; Label = '读取缓存'; ExitX = 0; ExitY = 0.65; EntryX = 1; EntryY = 0.40 },
      @{ From = 'sync'; To = 'cache'; Label = '更新缓存'; ExitX = 0; ExitY = 0.50; EntryX = 1; EntryY = 0.75 }
    )
  },
  @{
    File = 'record.drawio'
    Nodes = @(
      @{ Key = 'record'; Type = 'page'; Stereotype = 'Harmony ETS Page'; Name = 'RecordTabPage.ets'; Detail = '体重录入 / 月历 / 趋势图'; X = 120; Y = 260; Width = 290; Height = 120 },
      @{ Key = 'module'; Type = 'pack'; Stereotype = 'Harmony ETS Pack'; Name = 'recordModule'; Detail = "WeightRecordHelper`nMonthCalendarHelper"; X = 560; Y = 170; Width = 300; Height = 130 },
      @{ Key = 'sync'; Type = 'pack'; Stereotype = 'Harmony ETS Pack'; Name = 'syncCore'; Detail = 'SyncService / SyncQueueHelper'; X = 560; Y = 390; Width = 300; Height = 110 },
      @{ Key = 'cache'; Type = 'store'; Stereotype = 'PersistentStorage'; Name = 'local-health-cache'; Detail = "weightRecordText`npendingSyncQueueText"; X = 1030; Y = 110; Width = 320; Height = 130 },
      @{ Key = 'api'; Type = 'backend'; Stereotype = 'HTTP Backend'; Name = 'weight-api'; Detail = "GET /weight-records`nGET /weight-records/summary`nPUT /weight-records/{date}"; X = 1030; Y = 350; Width = 340; Height = 150 }
    )
    Edges = @(
      @{ From = 'record'; To = 'module'; Label = '趋势计算依赖'; ExitX = 1; ExitY = 0.42; EntryX = 0; EntryY = 0.42 },
      @{ From = 'record'; To = 'sync'; Label = '提交同步任务'; ExitX = 1; ExitY = 0.72; EntryX = 0; EntryY = 0.50 },
      @{ From = 'module'; To = 'cache'; Label = '读取本地记录'; ExitX = 1; ExitY = 0.35; EntryX = 0; EntryY = 0.45 },
      @{ From = 'module'; To = 'api'; Label = '远程汇总查询'; ExitX = 1; ExitY = 0.72; EntryX = 0; EntryY = 0.30 },
      @{ From = 'sync'; To = 'cache'; Label = '维护本地队列'; ExitX = 1; ExitY = 0.30; EntryX = 0; EntryY = 0.82 },
      @{ From = 'sync'; To = 'api'; Label = '体重写回'; ExitX = 1; ExitY = 0.62; EntryX = 0; EntryY = 0.72 }
    )
  },
  @{
    File = 'Exercise.drawio'
    Nodes = @(
      @{ Key = 'tab'; Type = 'page'; Stereotype = 'Harmony ETS Page'; Name = 'ExerciseTabPage.ets'; Detail = '计划日历 / 模板管理 / AI 推荐'; X = 100; Y = 150; Width = 300; Height = 125 },
      @{ Key = 'detail'; Type = 'page'; Stereotype = 'Harmony ETS Page'; Name = 'ExerciseDetailPage.ets'; Detail = '训练计时 / 模板保存 / 记录完成'; X = 100; Y = 360; Width = 300; Height = 125 },
      @{ Key = 'module'; Type = 'pack'; Stereotype = 'Harmony ETS Pack'; Name = 'exerciseModule'; Detail = "ExerciseHelper`nWorkoutPlanHelper / WorkoutPlanMetaHelper`nTrainingFeedbackHelper"; X = 540; Y = 220; Width = 330; Height = 160 },
      @{ Key = 'sync'; Type = 'pack'; Stereotype = 'Harmony ETS Pack'; Name = 'syncCore'; Detail = '计划 / 模板 / 训练记录同步'; X = 540; Y = 480; Width = 320; Height = 110 },
      @{ Key = 'cache'; Type = 'store'; Stereotype = 'PersistentStorage'; Name = 'local-health-cache'; Detail = "savedCustomWorkoutText`nworkoutPlanText / workoutPlanMetaText`nworkoutRecordText"; X = 1030; Y = 120; Width = 330; Height = 150 },
      @{ Key = 'api'; Type = 'backend'; Stereotype = 'HTTP Backend'; Name = 'workout-api'; Detail = "GET /workout-types`n/workout-templates`n/workout-plans`n/workout-records /daily-summary"; X = 1030; Y = 330; Width = 340; Height = 170 },
      @{ Key = 'ai'; Type = 'ai'; Stereotype = 'Third-party AI API'; Name = 'recommendation-api'; Detail = 'requestAiRecommendations()'; X = 1030; Y = 570; Width = 320; Height = 110 }
    )
    Edges = @(
      @{ From = 'tab'; To = 'module'; Label = '页面逻辑依赖'; ExitX = 1; ExitY = 0.42; EntryX = 0; EntryY = 0.30 },
      @{ From = 'detail'; To = 'module'; Label = '训练配置依赖'; ExitX = 1; ExitY = 0.42; EntryX = 0; EntryY = 0.72 },
      @{ From = 'tab'; To = 'sync'; Label = '计划 / 模板同步'; ExitX = 1; ExitY = 0.78; EntryX = 0; EntryY = 0.35 },
      @{ From = 'detail'; To = 'sync'; Label = '记录 / 模板同步'; ExitX = 1; ExitY = 0.72; EntryX = 0; EntryY = 0.72 },
      @{ From = 'module'; To = 'cache'; Label = '读写本地状态'; ExitX = 1; ExitY = 0.22; EntryX = 0; EntryY = 0.52 },
      @{ From = 'module'; To = 'api'; Label = '训练数据查询'; ExitX = 1; ExitY = 0.58; EntryX = 0; EntryY = 0.35 },
      @{ From = 'module'; To = 'ai'; Label = 'AI 推荐'; ExitX = 1; ExitY = 0.85; EntryX = 0; EntryY = 0.38 },
      @{ From = 'sync'; To = 'cache'; Label = '维护本地同步状态'; ExitX = 1; ExitY = 0.35; EntryX = 0; EntryY = 0.86 },
      @{ From = 'sync'; To = 'api'; Label = '写回训练计划与记录'; ExitX = 1; ExitY = 0.60; EntryX = 0; EntryY = 0.78 }
    )
  },
  @{
    File = 'food.drawio'
    Nodes = @(
      @{ Key = 'tab'; Type = 'page'; Stereotype = 'Harmony ETS Page'; Name = 'FoodTabPage.ets'; Detail = '饮食总览 / 日历 / 删除计划'; X = 90; Y = 100; Width = 300; Height = 120 },
      @{ Key = 'plan'; Type = 'page'; Stereotype = 'Harmony ETS Page'; Name = 'FoodPlanPage.ets'; Detail = '按日期选择餐次'; X = 90; Y = 280; Width = 300; Height = 110 },
      @{ Key = 'selection'; Type = 'page'; Stereotype = 'Harmony ETS Page'; Name = 'FoodSelectionPage.ets'; Detail = '选食物 / 自定义食物 / AI 推荐'; X = 90; Y = 460; Width = 300; Height = 130 },
      @{ Key = 'module'; Type = 'pack'; Stereotype = 'Harmony ETS Pack'; Name = 'foodManage'; Detail = "FoodHelper`nFoodVisualHelper"; X = 520; Y = 260; Width = 320; Height = 120 },
      @{ Key = 'sync'; Type = 'pack'; Stereotype = 'Harmony ETS Pack'; Name = 'syncCore'; Detail = '食物与餐次同步'; X = 520; Y = 600; Width = 300; Height = 110 },
      @{ Key = 'cache'; Type = 'store'; Stereotype = 'PersistentStorage'; Name = 'local-food-cache'; Detail = "foodPlanText`ncustomFoodOptionText`ncurrentFoodPlanDateText / currentFoodPlanMealTypeText"; X = 980; Y = 90; Width = 360; Height = 170 },
      @{ Key = 'api'; Type = 'backend'; Stereotype = 'HTTP Backend'; Name = 'food-api'; Detail = "GET /food-options`nPOST/PUT/DELETE /food-options/custom/*`nGET/POST/PUT/DELETE /food-plans"; X = 980; Y = 320; Width = 360; Height = 170 },
      @{ Key = 'ai'; Type = 'ai'; Stereotype = 'Third-party AI API'; Name = 'recommendation-api'; Detail = '饮食 / 运动候选排序'; X = 980; Y = 560; Width = 320; Height = 110 },
      @{ Key = 'picker'; Type = 'device'; Stereotype = 'Device API'; Name = 'photo-picker'; Detail = 'MediaLibraryKit'; X = 520; Y = 780; Width = 260; Height = 100 }
    )
    Edges = @(
      @{ From = 'tab'; To = 'module'; Label = '饮食展示'; ExitX = 1; ExitY = 0.45; EntryX = 0; EntryY = 0.28 },
      @{ From = 'plan'; To = 'module'; Label = '餐次规划'; ExitX = 1; ExitY = 0.50; EntryX = 0; EntryY = 0.50 },
      @{ From = 'selection'; To = 'module'; Label = '选食物 / 保存计划'; ExitX = 1; ExitY = 0.42; EntryX = 0; EntryY = 0.72 },
      @{ From = 'selection'; To = 'picker'; Label = '选择图片'; ExitX = 1; ExitY = 0.82; EntryX = 0; EntryY = 0.35 },
      @{ From = 'module'; To = 'cache'; Label = '读写本地饮食缓存'; ExitX = 1; ExitY = 0.20; EntryX = 0; EntryY = 0.42 },
      @{ From = 'module'; To = 'api'; Label = '食物 / 餐次查询'; ExitX = 1; ExitY = 0.52; EntryX = 0; EntryY = 0.35 },
      @{ From = 'module'; To = 'ai'; Label = 'AI 推荐'; ExitX = 1; ExitY = 0.82; EntryX = 0; EntryY = 0.32 },
      @{ From = 'module'; To = 'sync'; Label = '提交同步任务'; ExitX = 0.50; ExitY = 1; EntryX = 0.50; EntryY = 0 },
      @{ From = 'sync'; To = 'cache'; Label = '维护本地队列'; ExitX = 1; ExitY = 0.25; EntryX = 0; EntryY = 0.84 },
      @{ From = 'sync'; To = 'api'; Label = '写回食物与餐次'; ExitX = 1; ExitY = 0.55; EntryX = 0; EntryY = 0.82 }
    )
  },
  @{
    File = 'Ai assistant.drawio'
    Nodes = @(
      @{ Key = 'page'; Type = 'page'; Stereotype = 'Harmony ETS Page'; Name = 'AiAssistantTabPage.ets'; Detail = '聊天 / 快捷任务 / 导入计划'; X = 120; Y = 260; Width = 310; Height = 120 },
      @{ Key = 'shell'; Type = 'pack'; Stereotype = 'Harmony ETS Pack'; Name = 'appShell / contextProvider'; Detail = 'currentTabIndex / userProfile'; X = 520; Y = 90; Width = 320; Height = 110 },
      @{ Key = 'module'; Type = 'pack'; Stereotype = 'Harmony ETS Pack'; Name = 'assistantManage'; Detail = "AiAssistantHelper`ninferAiAssistantTaskFromPrompt"; X = 520; Y = 260; Width = 320; Height = 120 },
      @{ Key = 'config'; Type = 'store'; Stereotype = 'PersistentStorage'; Name = 'assistant-config-cache'; Detail = "aiApiEndpointText`naiApiKeyText`naiModelText`naiConversationHistoryText"; X = 980; Y = 70; Width = 350; Height = 170 },
      @{ Key = 'context'; Type = 'store'; Stereotype = 'PersistentStorage'; Name = 'health-plan-cache'; Detail = "weightRecordText`nworkoutRecordText`nsavedCustomWorkoutText`nworkoutPlanText / foodPlanText"; X = 980; Y = 310; Width = 360; Height = 170 },
      @{ Key = 'ai'; Type = 'ai'; Stereotype = 'Third-party AI API'; Name = 'BigModel Chat API'; Detail = '体重分析 / 训练计划 / 饮食计划 / 全套草案'; X = 980; Y = 570; Width = 350; Height = 120 }
    )
    Edges = @(
      @{ From = 'page'; To = 'shell'; Label = 'Tab / Profile 上下文'; ExitX = 1; ExitY = 0.20; EntryX = 0; EntryY = 0.70 },
      @{ From = 'page'; To = 'module'; Label = '对话与结果处理'; ExitX = 1; ExitY = 0.50; EntryX = 0; EntryY = 0.50 },
      @{ From = 'module'; To = 'config'; Label = '读取模型配置与会话历史'; ExitX = 1; ExitY = 0.15; EntryX = 0; EntryY = 0.42 },
      @{ From = 'module'; To = 'context'; Label = '读取健康上下文 / 写回计划'; ExitX = 1; ExitY = 0.52; EntryX = 0; EntryY = 0.35 },
      @{ From = 'module'; To = 'ai'; Label = '请求 AI'; ExitX = 1; ExitY = 0.84; EntryX = 0; EntryY = 0.35 }
    )
  },
  @{
    File = 'profile_auth.drawio'
    Nodes = @(
      @{ Key = 'login'; Type = 'page'; Stereotype = 'Harmony ETS Page'; Name = 'LoginPage.ets'; Detail = '登录 / 注册'; X = 90; Y = 170; Width = 290; Height = 110 },
      @{ Key = 'profile'; Type = 'page'; Stereotype = 'Harmony ETS Page'; Name = 'ProfileTabPage.ets'; Detail = '资料查看 / 编辑 / 退出登录'; X = 90; Y = 370; Width = 290; Height = 120 },
      @{ Key = 'module'; Type = 'pack'; Stereotype = 'Harmony ETS Pack'; Name = 'accountManage'; Detail = "AuthStorageHelper`nloginWithPassword / registerWithPassword`nfetchUserProfile / logoutSession"; X = 520; Y = 220; Width = 360; Height = 170 },
      @{ Key = 'sync'; Type = 'pack'; Stereotype = 'Harmony ETS Pack'; Name = 'syncCore'; Detail = '资料同步'; X = 520; Y = 470; Width = 300; Height = 110 },
      @{ Key = 'cache'; Type = 'store'; Stereotype = 'PersistentStorage'; Name = 'account-cache'; Detail = "authSessionText`napiBaseUrlText`nuserProfileText"; X = 1030; Y = 150; Width = 320; Height = 140 },
      @{ Key = 'api'; Type = 'backend'; Stereotype = 'HTTP Backend'; Name = 'auth-profile-api'; Detail = "POST /auth/login`nPOST /auth/register`nGET /user-profile`nPUT /user-profile"; X = 1030; Y = 390; Width = 340; Height = 160 }
    )
    Edges = @(
      @{ From = 'login'; To = 'module'; Label = '认证服务'; ExitX = 1; ExitY = 0.45; EntryX = 0; EntryY = 0.28 },
      @{ From = 'profile'; To = 'module'; Label = '资料管理'; ExitX = 1; ExitY = 0.38; EntryX = 0; EntryY = 0.72 },
      @{ From = 'module'; To = 'cache'; Label = '会话 / 资料缓存'; ExitX = 1; ExitY = 0.22; EntryX = 0; EntryY = 0.45 },
      @{ From = 'module'; To = 'api'; Label = '认证与资料查询'; ExitX = 1; ExitY = 0.68; EntryX = 0; EntryY = 0.35 },
      @{ From = 'module'; To = 'sync'; Label = '触发资料同步'; ExitX = 0.50; ExitY = 1; EntryX = 0.50; EntryY = 0 },
      @{ From = 'sync'; To = 'cache'; Label = '维护同步状态'; ExitX = 1; ExitY = 0.28; EntryX = 0; EntryY = 0.82 },
      @{ From = 'sync'; To = 'api'; Label = '资料写回'; ExitX = 1; ExitY = 0.60; EntryX = 0; EntryY = 0.82 }
    )
  }
)

foreach ($diagram in $diagrams) {
  Write-Diagram -Diagram $diagram -BaseDir $OutputDir
}
