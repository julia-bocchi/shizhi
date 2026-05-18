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

function Get-NodeStyle {
  param(
    [string]$Type
  )

  switch ($Type) {
    'client' {
      return 'shape=cube;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=18;fillColor=#ffffff;strokeColor=#000000;strokeWidth=2;align=center;verticalAlign=top;spacingTop=16;fontSize=24;fontStyle=1;'
    }
    'server' {
      return 'shape=cube;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=18;fillColor=#ffffff;strokeColor=#000000;strokeWidth=2;align=center;verticalAlign=top;spacingTop=16;fontSize=24;fontStyle=1;'
    }
    'db' {
      return 'shape=cube;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=18;fillColor=#ffffff;strokeColor=#000000;strokeWidth=2;align=center;verticalAlign=top;spacingTop=16;fontSize=24;fontStyle=1;'
    }
    'ai' {
      return 'shape=cube;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=18;fillColor=#efe3ff;strokeColor=#9673a6;strokeWidth=2;align=center;verticalAlign=top;spacingTop=16;fontSize=24;fontStyle=1;'
    }
    'cache' {
      return 'shape=cube;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=18;fillColor=#e9f7e7;strokeColor=#82b366;strokeWidth=2;align=center;verticalAlign=top;spacingTop=16;fontSize=24;fontStyle=1;'
    }
    default {
      return 'shape=cube;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=18;fillColor=#ffffff;strokeColor=#000000;strokeWidth=2;align=center;verticalAlign=top;spacingTop=16;fontSize=24;fontStyle=1;'
    }
  }
}

function Get-ArtifactStyle {
  return 'rounded=0;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;align=center;verticalAlign=middle;spacing=8;fontSize=16;'
}

function Get-EdgeStyle {
  param(
    [bool]$Dashed = $false
  )

  if ($Dashed) {
    return 'edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeWidth=2;dashed=1;endArrow=open;endFill=0;'
  }
  return 'edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeWidth=2;endArrow=none;'
}

function Get-RouteEdgeStyle {
  return 'edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;dashed=1;endArrow=blockThin;endFill=0;strokeColor=#666666;strokeWidth=1.5;'
}

function Normalize-Items {
  param(
    [Object[]]$Items
  )

  $normalized = @()
  $index = 0
  foreach ($item in $Items) {
    if ($item -is [string]) {
      $normalized += [ordered]@{
        Key = "item$index"
        Text = $item
      }
    } else {
      $normalized += [ordered]@{
        Key = $item.Key
        Text = $item.Text
      }
    }
    $index += 1
  }
  return $normalized
}

function Add-Node {
  param(
    [System.Text.StringBuilder]$Builder,
    [hashtable]$Node,
    [hashtable]$Refs
  )

  $items = Normalize-Items -Items $Node.Items
  $height = [Math]::Max([int]($Node.Height), 110 + ($items.Count * 62))
  $nodeId = New-CellId
  $node.Key | Out-Null
  $Refs[$Node.Key] = [ordered]@{
    Parent = $nodeId
    Children = @{}
  }

  [void]$Builder.AppendLine("        <mxCell id=""$nodeId"" value=""$(Escape-Xml $Node.Title)"" style=""$(Get-NodeStyle $Node.Type)"" parent=""1"" vertex=""1"">")
  [void]$Builder.AppendLine("          <mxGeometry x=""$($Node.X)"" y=""$($Node.Y)"" width=""$($Node.Width)"" height=""$height"" as=""geometry""/>")
  [void]$Builder.AppendLine('        </mxCell>')

  $itemY = 62
  foreach ($item in $items) {
    $childId = New-CellId
    $Refs[$Node.Key].Children[$item.Key] = $childId
    [void]$Builder.AppendLine("        <mxCell id=""$childId"" value=""$(Escape-Xml $item.Text)"" style=""$(Get-ArtifactStyle)"" parent=""$nodeId"" vertex=""1"">")
    [void]$Builder.AppendLine("          <mxGeometry x=""26"" y=""$itemY"" width=""$([int]$Node.Width - 52)"" height=""44"" as=""geometry""/>")
    [void]$Builder.AppendLine('        </mxCell>')
    $itemY += 58
  }
}

function Add-Connection {
  param(
    [System.Text.StringBuilder]$Builder,
    [hashtable]$Connection,
    [hashtable]$Refs
  )

  $edgeId = New-CellId
  $style = Get-EdgeStyle -Dashed ([bool]$Connection.Dashed)
  if ($Connection.ContainsKey('ExitX')) {
    $style += "exitX=$($Connection.ExitX);exitY=$($Connection.ExitY);exitDx=0;exitDy=0;"
  }
  if ($Connection.ContainsKey('EntryX')) {
    $style += "entryX=$($Connection.EntryX);entryY=$($Connection.EntryY);entryDx=0;entryDy=0;"
  }
  $label = Escape-Xml $Connection.Label
  $sourceId = $Refs[$Connection.From].Parent
  $targetId = $Refs[$Connection.To].Parent

  [void]$Builder.AppendLine("        <mxCell id=""$edgeId"" value=""$label"" style=""$style"" parent=""1"" source=""$sourceId"" target=""$targetId"" edge=""1"">")
  [void]$Builder.AppendLine('          <mxGeometry relative="1" as="geometry">')
  if ($Connection.ContainsKey('Points') -and $Connection.Points.Count -gt 0) {
    [void]$Builder.AppendLine('            <Array as="points">')
    foreach ($point in $Connection.Points) {
      [void]$Builder.AppendLine("              <mxPoint x=""$($point.X)"" y=""$($point.Y)""/>")
    }
    [void]$Builder.AppendLine('            </Array>')
  }
  [void]$Builder.AppendLine('          </mxGeometry>')
  [void]$Builder.AppendLine('        </mxCell>')
}

function Add-Route {
  param(
    [System.Text.StringBuilder]$Builder,
    [hashtable]$Route,
    [hashtable]$Refs
  )

  $edgeId = New-CellId
  $sourceId = $Refs[$Route.Node].Children[$Route.From]
  $targetId = $Refs[$Route.Node].Children[$Route.To]
  $label = Escape-Xml $Route.Label

  [void]$Builder.AppendLine("        <mxCell id=""$edgeId"" value=""$label"" style=""$(Get-RouteEdgeStyle)"" parent=""1"" source=""$sourceId"" target=""$targetId"" edge=""1"">")
  [void]$Builder.AppendLine('          <mxGeometry relative="1" as="geometry"/>')
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
  [void]$sb.AppendLine('    <mxGraphModel dx="1600" dy="1000" grid="0" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="2200" pageHeight="1600" math="0" shadow="0">')
  [void]$sb.AppendLine('      <root>')
  [void]$sb.AppendLine('        <mxCell id="0"/>')
  [void]$sb.AppendLine('        <mxCell id="1" parent="0"/>')

  foreach ($node in $Diagram.Nodes) {
    Add-Node -Builder $sb -Node $node -Refs $refs
  }

  foreach ($connection in $Diagram.Connections) {
    Add-Connection -Builder $sb -Connection $connection -Refs $refs
  }

  foreach ($route in $Diagram.Routes) {
    Add-Route -Builder $sb -Route $route -Refs $refs
  }

  [void]$sb.AppendLine('      </root>')
  [void]$sb.AppendLine('    </mxGraphModel>')
  [void]$sb.AppendLine('  </diagram>')
  [void]$sb.AppendLine('</mxfile>')
  return $sb.ToString()
}

function Write-DiagramFile {
  param(
    [hashtable]$Diagram,
    [string]$BaseDir
  )

  $outputPath = Join-Path $BaseDir $Diagram.File
  $content = Build-DrawioXml -Diagram $Diagram
  [System.IO.File]::WriteAllText($outputPath, $content, [System.Text.UTF8Encoding]::new($false))
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$diagrams = @(
  @{
    File = 'home_deployment.drawio'
    Nodes = @(
      @{ Key = 'client'; Title = '客户端'; Type = 'client'; X = 40; Y = 250; Width = 360; Height = 260; Items = @(
        @{ Key = 'index'; Text = 'Index.ets' },
        @{ Key = 'home'; Text = 'HomeTabPage.ets' },
        @{ Key = 'nav'; Text = 'MainBottomNavigation.ets' }
      )},
      @{ Key = 'cache'; Title = '本地缓存'; Type = 'cache'; X = 520; Y = 350; Width = 380; Height = 300; Items = @(
        'PersistentStorage',
        'userProfileText / weightRecordText',
        'foodPlanText / workoutRecordText',
        'dailyFoodCalorieTargetText'
      )},
      @{ Key = 'server'; Title = '上游业务服务器'; Type = 'server'; X = 520; Y = 40; Width = 380; Height = 320; Items = @(
        'mock-backend/server.js',
        'GET /user-profile',
        'GET /weight-records /summary',
        'GET /food-plans / workout-records/daily-summary'
      )},
      @{ Key = 'db'; Title = '业务数据存储'; Type = 'db'; X = 1040; Y = 110; Width = 340; Height = 260; Items = @(
        'mock-backend/data.json',
        'user profile',
        'weight / food / workout summary'
      )}
    )
    Connections = @(
      @{ From = 'client'; To = 'cache'; Label = 'StorageLink / PersistentStorage'; Dashed = $false; ExitX = 1; ExitY = 0.78; EntryX = 0; EntryY = 0.30 },
      @{ From = 'server'; To = 'db'; Label = 'JSON File I/O'; Dashed = $false; ExitX = 1; ExitY = 0.45; EntryX = 0; EntryY = 0.45 },
      @{ From = 'client'; To = 'server'; Label = '间接数据来源（由其他业务页同步）'; Dashed = $true; ExitX = 1; ExitY = 0.24; EntryX = 0; EntryY = 0.72 }
    )
    Routes = @()
  },
  @{
    File = 'record_deployment.drawio'
    Nodes = @(
      @{ Key = 'client'; Title = '客户端'; Type = 'client'; X = 40; Y = 260; Width = 360; Height = 220; Items = @(
        @{ Key = 'record'; Text = 'RecordTabPage.ets' }
      )},
      @{ Key = 'cache'; Title = '本地缓存'; Type = 'cache'; X = 500; Y = 300; Width = 380; Height = 280; Items = @(
        'PersistentStorage',
        'weightRecordText',
        'pendingSyncQueueText',
        'lastSyncAttemptText / lastSyncSuccessText'
      )},
      @{ Key = 'server'; Title = '业务服务器'; Type = 'server'; X = 500; Y = 40; Width = 400; Height = 320; Items = @(
        'mock-backend/server.js',
        'GET /weight-records',
        'GET /weight-records/summary',
        'PUT /weight-records/{date}'
      )},
      @{ Key = 'db'; Title = '业务数据存储'; Type = 'db'; X = 1040; Y = 110; Width = 340; Height = 260; Items = @(
        'mock-backend/data.json',
        'weightRecords',
        'user-scoped sync state'
      )}
    )
    Connections = @(
      @{ From = 'client'; To = 'cache'; Label = 'StorageLink / 本地队列'; Dashed = $false; ExitX = 1; ExitY = 0.72; EntryX = 0; EntryY = 0.30 },
      @{ From = 'client'; To = 'server'; Label = 'HTTP/JSON'; Dashed = $false; ExitX = 1; ExitY = 0.25; EntryX = 0; EntryY = 0.70 },
      @{ From = 'server'; To = 'db'; Label = 'JSON File I/O'; Dashed = $false; ExitX = 1; ExitY = 0.45; EntryX = 0; EntryY = 0.45 }
    )
    Routes = @()
  },
  @{
    File = 'exercise_deployment.drawio'
    Nodes = @(
      @{ Key = 'client'; Title = '客户端'; Type = 'client'; X = 40; Y = 220; Width = 360; Height = 280; Items = @(
        @{ Key = 'tab'; Text = 'ExerciseTabPage.ets' },
        @{ Key = 'detail'; Text = 'ExerciseDetailPage.ets' }
      )},
      @{ Key = 'cache'; Title = '本地缓存'; Type = 'cache'; X = 500; Y = 360; Width = 400; Height = 360; Items = @(
        'savedCustomWorkoutText',
        'workoutPlanText / workoutPlanMetaText',
        'workoutRecordText',
        'currentExerciseDraftText / currentExerciseProfileText',
        'exerciseRecommendationCacheText'
      )},
      @{ Key = 'server'; Title = '业务服务器'; Type = 'server'; X = 500; Y = 40; Width = 420; Height = 360; Items = @(
        'mock-backend/server.js',
        'GET /workout-types',
        'GET/POST/PUT/DELETE /workout-templates',
        'GET/POST/DELETE /workout-plans',
        'GET/POST /workout-records',
        'GET /workout-records/daily-summary'
      )},
      @{ Key = 'db'; Title = '业务数据存储'; Type = 'db'; X = 1090; Y = 80; Width = 350; Height = 320; Items = @(
        'mock-backend/data.json',
        'workoutTemplates',
        'workoutPlans',
        'workoutRecords'
      )},
      @{ Key = 'ai'; Title = '大模型 API'; Type = 'ai'; X = 1090; Y = 470; Width = 350; Height = 250; Items = @(
        'BigModel / Chat Completions',
        'AI recommendation ranking'
      )}
    )
    Connections = @(
      @{ From = 'client'; To = 'cache'; Label = 'PersistentStorage'; Dashed = $false; ExitX = 1; ExitY = 0.80; EntryX = 0; EntryY = 0.25 },
      @{ From = 'client'; To = 'server'; Label = 'HTTP/JSON'; Dashed = $false; ExitX = 1; ExitY = 0.22; EntryX = 0; EntryY = 0.72 },
      @{ From = 'client'; To = 'ai'; Label = 'HTTPS/JSON'; Dashed = $false; ExitX = 1; ExitY = 0.58; EntryX = 0; EntryY = 0.52; Points = @(@{ X = 980; Y = 360 }) },
      @{ From = 'server'; To = 'db'; Label = 'JSON File I/O'; Dashed = $false; ExitX = 1; ExitY = 0.45; EntryX = 0; EntryY = 0.45 }
    )
    Routes = @()
  },
  @{
    File = 'food_deployment.drawio'
    Nodes = @(
      @{ Key = 'client'; Title = '客户端'; Type = 'client'; X = 40; Y = 180; Width = 360; Height = 360; Items = @(
        @{ Key = 'tab'; Text = 'FoodTabPage.ets' },
        @{ Key = 'plan'; Text = 'FoodPlanPage.ets' },
        @{ Key = 'selection'; Text = 'FoodSelectionPage.ets' }
      )},
      @{ Key = 'cache'; Title = '本地缓存'; Type = 'cache'; X = 500; Y = 380; Width = 420; Height = 360; Items = @(
        'foodPlanText',
        'customFoodOptionText',
        'currentFoodPlanDateText / currentFoodPlanMealTypeText',
        'dailyFoodCalorieTargetText',
        'foodRecommendationCacheText'
      )},
      @{ Key = 'server'; Title = '业务服务器'; Type = 'server'; X = 500; Y = 40; Width = 420; Height = 330; Items = @(
        'mock-backend/server.js',
        'GET /food-options',
        'POST/PUT/DELETE /food-options/custom/*',
        'GET/POST/PUT/DELETE /food-plans'
      )},
      @{ Key = 'db'; Title = '业务数据存储'; Type = 'db'; X = 1090; Y = 80; Width = 350; Height = 270; Items = @(
        'mock-backend/data.json',
        'customFoodOptions',
        'foodPlans'
      )},
      @{ Key = 'ai'; Title = '大模型 API'; Type = 'ai'; X = 1090; Y = 430; Width = 350; Height = 250; Items = @(
        'BigModel / Chat Completions',
        'food + exercise recommendation ranking'
      )}
    )
    Connections = @(
      @{ From = 'client'; To = 'cache'; Label = 'PersistentStorage'; Dashed = $false; ExitX = 1; ExitY = 0.82; EntryX = 0; EntryY = 0.25 },
      @{ From = 'client'; To = 'server'; Label = 'HTTP/JSON'; Dashed = $false; ExitX = 1; ExitY = 0.22; EntryX = 0; EntryY = 0.72 },
      @{ From = 'client'; To = 'ai'; Label = 'HTTPS/JSON'; Dashed = $false; ExitX = 1; ExitY = 0.63; EntryX = 0; EntryY = 0.52; Points = @(@{ X = 980; Y = 350 }) },
      @{ From = 'server'; To = 'db'; Label = 'JSON File I/O'; Dashed = $false; ExitX = 1; ExitY = 0.45; EntryX = 0; EntryY = 0.45 }
    )
    Routes = @()
  },
  @{
    File = 'assistant_deployment.drawio'
    Nodes = @(
      @{ Key = 'client'; Title = '客户端'; Type = 'client'; X = 60; Y = 220; Width = 360; Height = 240; Items = @(
        @{ Key = 'assistant'; Text = 'AiAssistantTabPage.ets' }
      )},
      @{ Key = 'config'; Title = 'AI 配置与历史缓存'; Type = 'cache'; X = 520; Y = 40; Width = 380; Height = 320; Items = @(
        'aiApiEndpointText',
        'aiApiKeyText',
        'aiModelText',
        'aiConversationHistoryText'
      )},
      @{ Key = 'context'; Title = '健康上下文缓存'; Type = 'cache'; X = 520; Y = 390; Width = 400; Height = 360; Items = @(
        'weightRecordText',
        'workoutRecordText',
        'savedCustomWorkoutText',
        'workoutPlanText',
        'foodPlanText',
        'dailyFoodCalorieTargetText'
      )},
      @{ Key = 'ai'; Title = '大模型 API'; Type = 'ai'; X = 1080; Y = 220; Width = 350; Height = 270; Items = @(
        'BigModel / Chat Completions',
        '体重分析 / 训练计划 / 饮食计划',
        '整套运动与饮食草案生成'
      )}
    )
    Connections = @(
      @{ From = 'client'; To = 'config'; Label = 'PersistentStorage'; Dashed = $false; ExitX = 1; ExitY = 0.24; EntryX = 0; EntryY = 0.70 },
      @{ From = 'client'; To = 'context'; Label = '本地上下文读取/写回'; Dashed = $false; ExitX = 1; ExitY = 0.76; EntryX = 0; EntryY = 0.28 },
      @{ From = 'client'; To = 'ai'; Label = 'HTTPS/JSON'; Dashed = $false; ExitX = 1; ExitY = 0.50; EntryX = 0; EntryY = 0.50 }
    )
    Routes = @()
  },
  @{
    File = 'profile_auth_deployment.drawio'
    Nodes = @(
      @{ Key = 'client'; Title = '客户端'; Type = 'client'; X = 40; Y = 240; Width = 360; Height = 280; Items = @(
        @{ Key = 'login'; Text = 'LoginPage.ets' },
        @{ Key = 'profile'; Text = 'ProfileTabPage.ets' }
      )},
      @{ Key = 'cache'; Title = '本地缓存'; Type = 'cache'; X = 500; Y = 340; Width = 390; Height = 310; Items = @(
        'authSessionText',
        'apiBaseUrlText',
        'userProfileText',
        'lastSyncAttemptText / lastSyncSuccessText'
      )},
      @{ Key = 'server'; Title = '业务服务器'; Type = 'server'; X = 500; Y = 40; Width = 420; Height = 320; Items = @(
        'mock-backend/server.js',
        'POST /auth/login',
        'POST /auth/register',
        'GET /user-profile',
        'PUT /user-profile'
      )},
      @{ Key = 'db'; Title = '业务数据存储'; Type = 'db'; X = 1070; Y = 110; Width = 350; Height = 280; Items = @(
        'mock-backend/data.json',
        'users',
        'profiles',
        'token / userId mapping'
      )}
    )
    Connections = @(
      @{ From = 'client'; To = 'cache'; Label = 'PersistentStorage'; Dashed = $false; ExitX = 1; ExitY = 0.76; EntryX = 0; EntryY = 0.28 },
      @{ From = 'client'; To = 'server'; Label = 'HTTP/JSON'; Dashed = $false; ExitX = 1; ExitY = 0.24; EntryX = 0; EntryY = 0.72 },
      @{ From = 'server'; To = 'db'; Label = 'JSON File I/O'; Dashed = $false; ExitX = 1; ExitY = 0.45; EntryX = 0; EntryY = 0.45 }
    )
    Routes = @()
  }
)

foreach ($diagram in $diagrams) {
  Write-DiagramFile -Diagram $diagram -BaseDir $OutputDir
}
