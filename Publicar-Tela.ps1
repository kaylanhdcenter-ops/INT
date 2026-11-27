#requires -Version 5.1
[CmdletBinding()]
param([string[]]$Terminais, [string]$Imagem, [string]$Downloads, [string]$PastaRelatorios,
      [ValidatePattern('^(?:[01]\d|2[0-3]):[0-5]\d$')][string]$Inicio = '00:00',
      [ValidatePattern('^(?:(?:[01]\d|2[0-3]):[0-5]\d|24:00)$')][string]$Fim = '24:00',
      [string]$Dias = 'todos os dias')
$ErrorActionPreference = 'Stop'
$script:interface = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $PSScriptRoot 'painel.js')
$script:seq = 0
$script:screen = @('Screen Display','Exibição da tela','Exibição de tela','Tela de exibição')
$script:preferences = @('Preference','Preferences','Preferência','Preferências')
$script:configuration = @('Configuration','Configuração','Configurações')
$script:notice = @('Notice Publication','Publicação de avisos','Publicação de aviso')
$script:library = @('Media Library Management','Gerenciamento da biblioteca de mídia','Biblioteca de mídia')
$script:agenda = @('Schedule Management','Gerenciamento de horários','Gerenciamento de agenda','Programação de horários')

function Get-TerminalAddress([string]$value) {
<<<<<<< Updated upstream
    $value = $value.Trim()
    if (!$value) { throw 'Endereço vazio.' }
    $value = $value -replace '^https?://', ''
    if ($value -notmatch '^(?:[a-z0-9][a-z0-9.-]*|\[[a-f0-9:]+\])(?::\d+)?(?:[/?#][^\s"\\]*)?\z' -or
        $value -match '^[^/?#]+://') { throw "Endereço inválido: $value" }
    # Na entrada do operador, IP/porta e IP:porta indicam a mesma porta de rede.
=======
    $value = $value.Trim() -replace '^https?://', ''
    if ($value -notmatch '^(?:[a-z0-9][a-z0-9.-]*|\[[a-f0-9:]+\])(?::\d+)?(?:[/?#][^\s"\\]*)?\z') { throw "Endereço inválido: $value" }
>>>>>>> Stashed changes
    if ($value -match '^(?<host>\[[^\]]+\]|[^/:?#]+)/(?<porta>\d+)(?<resto>[/?#].*)?$') {
        $value = $Matches.host + ':' + $Matches.porta + $Matches.resto
    }
    $uri = $null
<<<<<<< Updated upstream
    if (![Uri]::TryCreate(('tcp://' + $value), [UriKind]::Absolute, [ref]$uri) -or
        !$uri.Host -or $uri.Port -eq 0) { throw "Endereço ou porta inválidos: $value" }
=======
    if (![Uri]::TryCreate(('tcp://' + $value), [UriKind]::Absolute, [ref]$uri) -or !$uri.Host -or $uri.Port -eq 0) {
        throw "Endereço ou porta inválidos: $value"
    }
>>>>>>> Stashed changes
    return $value
}

function Select-ImageFile([string]$path, [string]$folder) {
    $types = @('.png','.jpg','.jpeg','.bmp','.gif','.webp','.tif','.tiff','.ico','.jfif')
    $auto = !$path
<<<<<<< Updated upstream
    $namePattern = '^HDCENTER(?:\s*\(\d+\))?$'
=======
>>>>>>> Stashed changes
    if (!$path) {
        if (!$folder) {
            $folder = (Get-ItemProperty -ErrorAction SilentlyContinue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders').'{374DE290-123F-4565-9164-39C4925E467B}'
            if ($folder) { $folder = [Environment]::ExpandEnvironmentVariables($folder) }
            else { $folder = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads' }
        }
        $files = @(Get-ChildItem -File -LiteralPath $folder | Where-Object {
<<<<<<< Updated upstream
            $_.BaseName -match $namePattern -and $_.Extension -in $types -and $_.Length -gt 0
=======
            $_.BaseName -match '^HDCENTER(?:\s*\(\d+\))?$' -and $_.Extension -in $types -and $_.Length -gt 0
>>>>>>> Stashed changes
        } | Sort-Object LastWriteTimeUtc -Descending)
        if (!$files.Count) { throw "Nenhuma imagem HDCENTER encontrada em $folder." }
        if ($files.Count -eq 1 -or $files[0].LastWriteTimeUtc -ne $files[1].LastWriteTimeUtc) {
            $path = $files[0].FullName
        } else { Write-Host 'Há imagens HDCENTER com a mesma data. Escolha a cópia desejada.' }
    }
    while ($true) {
        if (!$path) {
            Write-Host 'Escolha a imagem do lote na janela de arquivos.'
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object Windows.Forms.OpenFileDialog
            try {
                $dialog.Filter = 'Imagens|' + (($types | ForEach-Object { '*' + $_ }) -join ';')
                if ($folder -and (Test-Path -LiteralPath $folder -PathType Container)) { $dialog.InitialDirectory = $folder }
                if ($dialog.ShowDialog() -ne 'OK') { throw 'Seleção da imagem cancelada.' }
                $path = $dialog.FileName
            } finally { $dialog.Dispose() }
        }
        $item = Get-Item -ErrorAction SilentlyContinue -LiteralPath $path
        if ($item -is [IO.FileInfo] -and $item.Extension -in $types -and $item.Length -gt 0) {
<<<<<<< Updated upstream
            if (!$auto -or $item.BaseName -match $namePattern) { return $item.FullName }
            Write-Host 'Selecione uma imagem com o nome HDCENTER.'
=======
            if (!$auto -or $item.BaseName -match '^HDCENTER(?:\s*\(\d+\))?$') { return $item.FullName }
            Write-Host 'Escolha uma imagem chamada HDCENTER.'
>>>>>>> Stashed changes
            $path = $null
            continue
        }
        Write-Host "Arquivo ausente, vazio ou com extensão de imagem desconhecida: $path"
        $path = $null
    }
}

function Send-Cdp([string]$method, [hashtable]$parameters = @{}) {
    $script:seq++
    $id = $script:seq
    $cts = New-Object Threading.CancellationTokenSource
    $cts.CancelAfter(15000)
    try {
        $json = ConvertTo-Json -Compress -Depth 12 -InputObject @{id=$id;method=$method;params=$parameters}
        $bytes = [Text.Encoding]::UTF8.GetBytes($json)
        $task = $script:ws.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token)
        $null = $task.GetAwaiter().GetResult()
        $buffer = New-Object byte[] 16384
        do {
            $stream = New-Object IO.MemoryStream
            try {
                do {
                    $chunk = $script:ws.ReceiveAsync([ArraySegment[byte]]::new($buffer),$cts.Token).GetAwaiter().GetResult()
                    if ($chunk.MessageType -eq 'Close') { throw 'A aba do navegador foi fechada.' }
                    $stream.Write($buffer,0,$chunk.Count)
                } until ($chunk.EndOfMessage)
                $response = [Text.Encoding]::UTF8.GetString($stream.ToArray()) | ConvertFrom-Json
<<<<<<< Updated upstream
                if ($response.method -eq 'Page.fileChooserOpened') {
                    $script:chooserNode = $response.params.backendNodeId
                }
=======
                if ($response.method -eq 'Page.fileChooserOpened') { $script:chooserNode = $response.params.backendNodeId }
>>>>>>> Stashed changes
            } finally { $stream.Dispose() }
        } until ($response.id -eq $id)
        if ($response.error) { throw "$method - $($response.error.message)" }
        return $response.result
    } finally { $cts.Dispose() }
}

function Connect-Tab($tab) {
    if (!$tab) {
        $tab = Invoke-RestMethod -Method Put -DisableKeepAlive -Body ([byte[]]@()) -UseBasicParsing -TimeoutSec 5 -Uri "$script:local/json/new?about:blank"
    }
    $script:tabId = $tab.id
    $script:ws = New-Object Net.WebSockets.ClientWebSocket
    $cts = New-Object Threading.CancellationTokenSource
    try {
        $cts.CancelAfter(5000)
        $null = $script:ws.ConnectAsync([uri]$tab.webSocketDebuggerUrl,$cts.Token).GetAwaiter().GetResult()
    } finally { $cts.Dispose() }
    $null = Send-Cdp 'Page.bringToFront'
}

function Invoke-Panel([string]$action,[hashtable]$data = @{},[switch]$Object) {
    $data.endereco = $script:address
    $data.nome = $script:fileName
    $data.biblioteca = $script:library
    $arg = ConvertTo-Json -Compress -Depth 6 -InputObject $data
    $expr = '(' + $script:interface + ')(' + (ConvertTo-Json $action) + ',' + $arg + ')'
    $reply = Send-Cdp 'Runtime.evaluate' @{expression=$expr;returnByValue=(!$Object);userGesture=$true}
    if ($reply.exceptionDetails) { throw "Falha ao ler o painel: $($reply.exceptionDetails.exception.description)" }
    if ($Object) { return $reply.result.objectId }
    return $reply.result.value
}

function Wait-Panel([string]$action, [hashtable]$data = @{}, [int]$seconds = 3) {
    $limit = [DateTime]::UtcNow.AddSeconds($seconds)
    do {
        if (Invoke-Panel $action $data) { return $true }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $limit)
    return $false
}

function Ask-Step([string]$instruction) {
    Write-Host "`n$instruction" -ForegroundColor Yellow
    while ($true) {
        switch ((Read-Host '[C] Concluído e conferido   [P] Etapa pendente   [I] Pular este IP').Trim().ToUpperInvariant()) {
            'C' { return }
            'P' { $why = Read-Host 'Motivo da pendência'; throw "Etapa pendente. $why" }
            'I' { $why = Read-Host 'Motivo para pular o IP'; throw "PULAR IP. $why" }
        }
    }
}

function Ask-Yes([string]$text) {
    while ($true) {
        $answer = (Read-Host "$text [S/N]").Trim()
        if ($answer -in 'S','N') { return ($answer -eq 'S') }
    }
}

function Open-Section([array]$steps) {
    $last = $steps[-1].labels
    if (Invoke-Panel 'active' @{rotulos=$last}) { return $true }
    foreach ($step in $steps) {
        if (Invoke-Panel 'active' @{rotulos=$last}) { return $true }
        if (Invoke-Panel 'click' @{rotulos=$step.labels}) { Start-Sleep -Milliseconds 450 }
    }
    return (Wait-Panel 'active' @{rotulos=$last} 2)
}

<<<<<<< Updated upstream
function Open-MenuPath([array]$path) {
    if (Invoke-Panel 'menuReached' $path[-1]) { return $true }
=======
function Open-Screen {
    $menuTimeoutSeconds = 30
    $path = @(
        @{rotulos=$script:configuration; proximos=$script:preferences},
        @{rotulos=$script:preferences; proximos=$script:screen; preference=$true},
        @{rotulos=$script:screen; proximos=@()}
    )
    if (Invoke-Panel 'screenReached' $path[-1]) { return $true }
>>>>>>> Stashed changes
    foreach ($step in $path) {
        if (Invoke-Panel 'screenReached' $step) { continue }
        $name = $step.rotulos[0]
        Write-Host "Abrindo $name..."
<<<<<<< Updated upstream
        $limit = [DateTime]::UtcNow.AddSeconds(8)
        do {
            $point = Invoke-Panel 'menuPoint' $step
            if ($point) { break }
            Start-Sleep -Milliseconds 250
        } while ([DateTime]::UtcNow -lt $limit)
        if ($point) {
            $null = Send-Cdp 'Input.dispatchMouseEvent' @{type='mouseMoved';x=$point.x;y=$point.y}
            $null = Send-Cdp 'Input.dispatchMouseEvent' @{type='mousePressed';button='left';buttons=1;clickCount=1;x=$point.x;y=$point.y}
            $null = Send-Cdp 'Input.dispatchMouseEvent' @{type='mouseReleased';button='left';buttons=0;clickCount=1;x=$point.x;y=$point.y}
            if (Wait-Panel 'menuReached' $step 8) { continue }
=======
        if (Wait-Panel 'clickScreenMenu' $step $menuTimeoutSeconds) {
            $step.clicado = $true
            if ($step.proximos.Count) { Write-Host "Aguardando $($step.proximos[0])..." }
            if (Wait-Panel 'screenReached' $step $menuTimeoutSeconds) { continue }
            if ($step.proximos.Count) {
                $next = $step.proximos[0]
                Ask-Step "Não consegui acessar $next. Se necessário, abra $name e aguarde $next aparecer. Digite C quando $next estiver disponível."
                continue
            }
>>>>>>> Stashed changes
        }
        Ask-Step "Não consegui confirmar a abertura de $name. Clique em $name no painel e digite C para o script continuar."
    }
    return (Wait-Panel 'screenReached' $path[-1] 3)
}
function Open-Notice {
    $tab = @{rotulos=$script:notice; tela=$script:screen}
    if (Invoke-Panel 'noticeReached' $tab) { return $true }
    Write-Host 'Abrindo a aba Notice Publication...'
    if (!(Wait-Panel 'clickNotice' $tab 30)) { return $false }
    return (Wait-Panel 'noticeReached' $tab 30)
}
<<<<<<< Updated upstream
function Open-Screen {
    return (Open-MenuPath @(
        @{rotulos=$script:configuration; proximos=$script:preferences},
        @{rotulos=$script:preferences; proximos=$script:screen},
        @{rotulos=$script:screen; tela='screen'}
    ))
}
function Open-Notice { return (Open-Section @(@{labels=$script:notice})) }
function Open-Library {
    return (Open-MenuPath @(
        @{rotulos=$script:notice; proximos=$script:library},
        @{rotulos=$script:library; tela='library'}
    ))
=======
function Open-Library {
    $library = @{rotulos=$script:library}
    if (Invoke-Panel 'active' $library) { return $true }
    if (!(Open-Notice)) { return $false }
    if (Invoke-Panel 'active' $library) { return $true }
    Write-Host 'Abrindo Media Library Management...'
    if (!(Wait-Panel 'clickScreenMenu' $library 30)) { return $false }
    return (Wait-Panel 'active' $library 30)
}
function Open-Agenda {
    return (Open-Section @(@{rotulos=$script:notice; proximos=$script:agenda},@{rotulos=$script:agenda}))
>>>>>>> Stashed changes
}
function Open-Agenda { return (Open-Section @(@{labels=$script:notice},@{labels=$script:agenda})) }

function Reload-Panel {
    # Espera pela substituição do documento mesmo quando a URL continua igual.
    $mark = 'hd' + [guid]::NewGuid().ToString('N')
    $null = Send-Cdp 'Runtime.evaluate' @{expression="window['$mark']=1"}
    $null = Send-Cdp 'Page.reload'
    $limit = [DateTime]::UtcNow.AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 250
        $read = Send-Cdp 'Runtime.evaluate' @{expression="!window['$mark'] && document.readyState === 'complete'";returnByValue=$true}
        if ($read.result.value -and (Invoke-Panel 'ready')) { return }
    } while ([DateTime]::UtcNow -lt $limit)
    throw 'Não foi possível reabrir e confirmar os dados no terminal.'
}

function Wait-Save {
    if (!(Wait-Panel 'success' @{} 3)) {
        Ask-Step 'Aguarde a resposta do terminal. Confirme C somente se a gravação terminou sem erro. Em caso de dúvida, indique P.'
    }
}

function Set-Screen {
    $confirmed = $false
    $opened = Open-Screen
    if (!$opened) { throw 'A abertura de Preference > Screen Display não foi confirmada.' }
    if (!(Wait-Panel 'sleepReady' @{} 5)) {
        if (!(Invoke-Panel 'screenReached' @{rotulos=$script:screen})) { throw 'Screen Display deixou de estar aberto.' }
        Ask-Step 'Em Screen Display, confira Sleep, desative se necessário e clique em Save. Aguarde a confirmação.'
        $confirmed = $true
    } else {
        if (Invoke-Panel 'sleep') {
            Write-Host 'Desativando Sleep...'
            $null = Invoke-Panel 'disable'
        }
        if (!(Wait-Panel 'sleepOff' @{} 5) -or !(Wait-Panel 'saveSleep' @{} 3)) {
            if (!(Invoke-Panel 'screenReached' @{rotulos=$script:screen})) { throw 'Screen Display deixou de estar aberto.' }
            Ask-Step 'Em Screen Display, confirme Sleep desativado, salve a seção e aguarde a confirmação.'
            $confirmed = $true
        } else {
            Write-Host 'Clique em Save enviado.'
            $limit = [DateTime]::UtcNow.AddSeconds(5)
            do {
                $result = Invoke-Panel 'screenSaveResult'
                if ($result -eq 'falha') { throw 'O painel informou falha ao salvar Screen Display.' }
                if ($result -eq 'salvo') { $confirmed = $true; break }
                Start-Sleep -Milliseconds 200
            } while ([DateTime]::UtcNow -lt $limit)
        }
    }
<<<<<<< Updated upstream
=======
    if ($confirmed) {
        if ((Invoke-Panel 'sleep') -eq $true) { throw 'Sleep continuou ativado após salvar.' }
        return 'Confirmado no salvamento'
    }
    Write-Host 'Conferindo o Sleep gravado antes de abrir Notice Publication...'
>>>>>>> Stashed changes
    Reload-Panel
    $opened = Open-Screen
    if ($opened -and (Wait-Panel 'sleepReady' @{} 5)) {
        $state = Invoke-Panel 'sleep'
        if ($state -eq $false) { return 'Confirmado na releitura' }
        if ($state -eq $true) { throw 'Sleep continuou ativado após reabrir a tela.' }
    }
    Ask-Step 'Após a recarga, reabra Screen Display e confira se Sleep está desativado.'
    return 'Conferido pelo operador após recarga'
}

function Import-Media {
    if (!(Open-Library)) { Ask-Step 'Abra Notice Publication > Media Library Management. Confira que a biblioteca está visível.' }
    if (Invoke-Panel 'media') {
        if (Ask-Yes "A biblioteca contém '$script:fileName'. A miniatura corresponde à imagem deste lote?") { return }
        throw 'Já existe outra mídia com esse nome. Use um arquivo com nome distinto para evitar associação incorreta.'
    }
    Write-Host "Importando $script:fileName na biblioteca..."
<<<<<<< Updated upstream
    $fileId = Invoke-Panel 'file' @{} -Object
    $script:chooserNode = $null
    $intercept = $false
    $selected = $false
    try {
        if (!$fileId) {
            $null = Send-Cdp 'Page.enable'
            $null = Send-Cdp 'Page.setInterceptFileChooserDialog' @{enabled=$true}
            $intercept = $true
            if (Wait-Panel 'openImport' @{} 3) {
                $limit = [DateTime]::UtcNow.AddSeconds(5)
                do {
                    $fileId = Invoke-Panel 'file' @{} -Object
                    if ($script:chooserNode -or $fileId) { break }
                    Start-Sleep -Milliseconds 200
                } while ([DateTime]::UtcNow -lt $limit)
            }
        }
        $params = @{files=@($script:imagePath)}
        if ($script:chooserNode) { $params.backendNodeId = $script:chooserNode }
        elseif ($fileId) { $params.objectId = $fileId }
        if ($script:chooserNode -or $fileId) {
            $null = Send-Cdp 'DOM.setFileInputFiles' $params
            $selected = $true
        }
=======
    $fileId = $null
    $script:chooserNode = $null
    $intercept = $false
    try {
        $null = Send-Cdp 'Page.enable'
        $null = Send-Cdp 'Page.setInterceptFileChooserDialog' @{enabled=$true}
        $intercept = $true
        $null = Wait-Panel 'openImport' @{} 5
        $plusClicked = $false
        $limit = [DateTime]::UtcNow.AddSeconds(8)
        do {
            $fileId = Invoke-Panel 'file' @{} -Object
            if ($script:chooserNode -or $fileId) { break }
            if (!$plusClicked) { $plusClicked = Invoke-Panel 'uploadPlus' }
            Start-Sleep -Milliseconds 200
        } while ([DateTime]::UtcNow -lt $limit)
        $params = @{files=@($script:imagePath)}
        if ($script:chooserNode) { $params.backendNodeId = $script:chooserNode }
        elseif ($fileId) { $params.objectId = $fileId }
        if ($params.Count -gt 1) { $null = Send-Cdp 'DOM.setFileInputFiles' $params }
>>>>>>> Stashed changes
    } finally {
        if ($intercept) { $null = Send-Cdp 'Page.setInterceptFileChooserDialog' @{enabled=$false} }
        if ($fileId) { $null = Send-Cdp 'Runtime.releaseObject' @{objectId=$fileId} }
        $script:chooserNode = $null
    }
<<<<<<< Updated upstream
    if (!$selected) {
        Ask-Step "Em Media Library Management, use Import para selecionar '$script:imagePath'. Confirme quando a imagem aparecer na biblioteca."
        return
    }
    if (!(Wait-Panel 'media' @{} 2)) {
        $null = Invoke-Panel 'confirmImport'
        if (!(Wait-Panel 'media' @{} 15)) {
            Ask-Step "O arquivo já foi selecionado. Confira o andamento da importação e confirme quando '$script:fileName' aparecer na biblioteca."
=======
    if ($params.Count -eq 1) {
        Ask-Step "Em Media Library Management, clique em Import ou no ícone + e selecione '$script:imagePath'. Confirme quando a imagem aparecer na biblioteca."
    } elseif (!(Wait-Panel 'media' @{} 2)) {
        $null = Invoke-Panel 'confirmImport'
        if (!(Wait-Panel 'media' @{} 15)) {
            Ask-Step "Confira o andamento da importação e confirme quando '$script:fileName' aparecer na biblioteca."
>>>>>>> Stashed changes
        }
    }
}

function Set-Program {
    if (!(Invoke-Panel 'editor')) {
        if (Invoke-Panel 'closeLibrary') { $null = Wait-Panel 'programList' @{} 3 }
        if (!(Invoke-Panel 'programList')) {
            $null = Open-Notice
            if (!(Wait-Panel 'programList' @{} 5)) { Ask-Step 'Em Notice Publication, exiba a lista de programas.' }
        }
        if (Invoke-Panel 'openHD') {
            if (!(Wait-Panel 'editor' @{} 8)) { Ask-Step 'Abra a edição do programa HD existente.' }
        } else {
            $create = $true
            if (Invoke-Panel 'checkProgramList') {
                $create = !(Ask-Yes 'Confira a lista completa de programas. Já existe HD?')
            }
            if ($create) {
                Write-Host 'Abrindo Add Program e preenchendo o nome HD...'
                if (!(Wait-Panel 'addProgram' @{} 5) -or !(Wait-Panel 'nameHD' @{} 8)) {
                    Ask-Step 'Abra Add Program, preencha o nome HD e deixe o editor aberto.'
                } else { $null = Invoke-Panel 'confirmName' }
            } else { Ask-Step 'Abra o programa HD existente para edição.' }
            if (!(Wait-Panel 'editor' @{} 8)) {
                Ask-Step 'Confirme o nome HD e abra o editor desse programa.'
            }
        }
    }
    if (!(Invoke-Panel 'inProgram')) {
        $picked = $false
        Write-Host "Adicionando '$script:fileName' pelo botão + do programa HD..."
        if (Wait-Panel 'addImage' @{} 8) {
            $picked = Wait-Panel 'pick' @{} 10
            if ($picked -and !(Wait-Panel 'inProgram' @{} 1)) { $null = Wait-Panel 'acceptPicker' @{} 4 }
        }
        if (!$picked -or !(Wait-Panel 'inProgram' @{} 8)) {
            Ask-Step "No editor de HD, confira as imagens já associadas. Se '$script:fileName' estiver ausente, use + para incluí-la uma vez. Confira a miniatura no programa."
        }
    }
    if (Invoke-Panel 'saveProgram') { Wait-Save }
    else { Ask-Step 'Salve a edição de HD e, se a interface exigir, também Notice Publication. Aguarde a confirmação.' }
}

function Set-Agenda {
    if (!(Open-Agenda)) { Ask-Step 'Abra Notice Publication > Schedule Management.' }
    $weekly = $Inicio -eq '00:00' -and $Fim -eq '24:00' -and $Dias -eq 'todos os dias'
    $plan = if ($weekly) { Invoke-Panel 'schedule' }
    if ($plan -and !$plan.ok -and $plan.editable) {
        $conflicts = @($plan.conflicts | Where-Object { $_ })
        if ($conflicts.Count -and !(Ask-Yes ("Substituir por HD os períodos conflitantes de " + ($conflicts -join ', ') + ' nesta semana de programação?'))) {
            throw 'Substituição da programação recusada.'
        }
        $filled = Invoke-Panel 'fillSchedule' @{aprovados=$conflicts}
        if ($filled) { $plan = Invoke-Panel 'schedule' } else { $plan = $null }
    }
    if ($plan -and $plan.ok -and (Invoke-Panel 'saveSchedule')) { Wait-Save; return }
    Write-Host "Confira a grade de $Inicio a $Fim ($Dias) antes de editar." -ForegroundColor Yellow
    if (Ask-Yes 'Há outro programa em algum trecho do período solicitado?') {
        if (!(Ask-Yes 'Autoriza substituir esses intervalos por HD?')) { throw 'Substituição da programação recusada.' }
    }
    Ask-Step "Selecione HD e marque de $Inicio até $Fim ($Dias). Preserve os períodos fora desse intervalo. Confira os limites, salve Notice Publication e aguarde a confirmação."
}

function Confirm-Program {
    $opened = (Invoke-Panel 'programList') -or (Open-Notice)
    if ($opened -and (Invoke-Panel 'openHD') -and (Wait-Panel 'inProgram')) { return 'Confirmado na releitura' }
    Ask-Step "Na tela recarregada, abra o programa HD e confira '$script:fileName' entre as imagens salvas nele."
    return 'Conferido pelo operador após recarga'
}

function Confirm-Agenda {
    $opened = Open-Agenda
    $plan = if ($Inicio -eq '00:00' -and $Fim -eq '24:00' -and $Dias -eq 'todos os dias') { Invoke-Panel 'schedule' }
    if ($opened -and $plan -and $plan.ok) { return 'Confirmada na releitura' }
    if ($opened -and $plan -and !$plan.ok) { throw 'Na releitura, HD não cobria 00–24 nos sete dias.' }
    Ask-Step "Na tela recarregada, abra Schedule Management e confira que HD cobre $Inicio a $Fim ($Dias) e que os demais períodos foram preservados."
    return 'Conferida pelo operador após recarga'
}

function Start-PanelBrowser([string]$profile) {
    $app = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (!$app) { throw 'Instale o Microsoft Edge ou Google Chrome para abrir o painel dos terminais.' }
    $script:browserExe = $app
    $script:browserProfile = $profile
    $null = [IO.Directory]::CreateDirectory($profile)
    $portFile = Join-Path $profile 'DevToolsActivePort'
    $previous = if (Test-Path -LiteralPath $portFile) { [IO.File]::ReadAllText($portFile) }
    $argsList = @("--user-data-dir=`"$profile`"",'--remote-debugging-address=127.0.0.1','--remote-debugging-port=0',
        '--no-first-run','--no-default-browser-check','--disable-background-mode','--disable-sync')
    $script:browser = Start-Process -PassThru -FilePath $app -ArgumentList ($argsList + 'about:blank')
    $limit = [DateTime]::UtcNow.AddSeconds(25)
    do {
        Start-Sleep -Milliseconds 250
        if (Test-Path -LiteralPath $portFile) {
            try {
                $activePort = [IO.File]::ReadAllText($portFile)
                if ($activePort -ne $previous -and ($activePort -split '\r?\n')[0] -match '^\d+$') {
                    $endpoint = 'http://127.0.0.1:' + ($activePort -split '\r?\n')[0]
                    $version = Invoke-RestMethod -DisableKeepAlive -UseBasicParsing -TimeoutSec 2 -Uri "$endpoint/json/version"
                    if (([Uri]$version.webSocketDebuggerUrl).AbsolutePath -ne ($activePort.Trim() -split '\r?\n')[1]) { continue }
                    $script:local = $endpoint
                    return
                }
            } catch { continue }
        }
    } while ([DateTime]::UtcNow -lt $limit)
    throw 'Falha ao iniciar o navegador de publicação. Feche a janela de publicação anterior e verifique se a política do navegador permite depuração local.'
}

function Close-Tab {
    if ($script:ws) { $script:ws.Dispose(); $script:ws = $null }
    if ($script:tabId) {
        try { $null = Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 -Uri "$script:local/json/close/$script:tabId" } catch {}
        $script:tabId = $null
    }
}

function Wait-Access([switch]$AfterLogin) {
    $until = [DateTime]::UtcNow.AddSeconds(12)
    do {
        $state = Invoke-Panel 'access'
        if ($state -eq 'panel' -or (!$AfterLogin -and $state -eq 'login')) { return $state }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $until)
    return $state
}

function Read-TerminalPassword {
    return (Read-Host "Senha de admin para $script:target" -AsSecureString)
}

function Enter-Terminal {
    $state = Wait-Access
    if ($state -eq 'panel') { return }
    if ($state -eq 'login') {
        $handler = Invoke-Panel 'loginHandler' @{} -Object
        if ($handler) {
            $password = $null
            $address = [IntPtr]::Zero
            try {
                $password = Read-TerminalPassword
                if (!$password -or !$password.Length) { throw 'Senha de admin em branco. Login cancelado para este terminal.' }
                $address = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
                $argument = @{value=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($address)}
                try {
                    $reply = Send-Cdp 'Runtime.callFunctionOn' @{objectId=$handler;functionDeclaration='function(p){return this(p)}';
                        arguments=@($argument);returnByValue=$true;awaitPromise=$true;userGesture=$true}
                    $sent = !$reply.exceptionDetails -and $reply.result.value -eq $true
                } catch { $sent = $false }
                finally { $argument.Clear() }
            } finally {
                if ($address -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($address) }
                if ($password) { $password.Dispose() }
                try { $null = Send-Cdp 'Runtime.releaseObject' @{objectId=$handler} } catch {}
            }
            $state = Wait-Access -AfterLogin
            if ($state -eq 'panel') { Write-Host 'Login de admin confirmado.'; return }
            if ($sent -and $state -eq 'login') {
                throw 'O formulário de login continua aberto após o envio. Confira a senha de admin e a mensagem do terminal.'
            }
        }
    }
    Ask-Step 'Confira a aba do terminal. Se aparecer uma tela de autenticação diferente, entre como admin. Digite C somente quando o painel estiver aberto.'
    if (!(Invoke-Panel 'ready') -or (Invoke-Panel 'access') -eq 'login') { throw 'O acesso ao painel não foi confirmado.' }
}

function Open-Terminal {
    $list = "$script:local/json/list"
    $oldIds = (Invoke-RestMethod -UseBasicParsing -TimeoutSec 5 -Uri $list).id
    $expected = [Uri]('tcp://' + $script:address)
<<<<<<< Updated upstream
    # O navegador interpreta o argumento sem prefixo e abre a aba no perfil do lote.
=======
>>>>>>> Stashed changes
    Start-Process -FilePath $script:browserExe -ArgumentList @(
        "--user-data-dir=`"$script:browserProfile`"", "`"$script:address`"")
    $limit = [DateTime]::UtcNow.AddSeconds(20)
    do {
        $tabs = Invoke-RestMethod -UseBasicParsing -TimeoutSec 5 -Uri $list
        foreach ($tab in $tabs) {
            if ($tab.type -ne 'page' -or $tab.id -in $oldIds) { continue }
            $actual = $null
            if (![Uri]::TryCreate($tab.url,[UriKind]::Absolute,[ref]$actual) -or
                $actual.Scheme -notin 'http','https' -or $actual.Host -ne $expected.Host) { continue }
            if ($expected.Port -eq -1 -and !$actual.IsDefaultPort) { continue }
            if ($expected.Port -ne -1 -and $expected.Port -ne $actual.Port) { continue }
            Connect-Tab $tab
            Enter-Terminal
            return
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $limit)
    throw "O navegador não abriu uma aba no endereço e porta de $script:address."
}

function Publish-Batch {
    if ([string]::CompareOrdinal($Inicio,$Fim) -ge 0 -or [string]::IsNullOrWhiteSpace($Dias)) { throw 'Indique os dias e um intervalo com início anterior ao fim.' }
    if (!$Terminais) {
<<<<<<< Updated upstream
        $inputAddress = Read-Host 'IP dos terminais (Enter para 177.74.189.75). Use IP:porta ou IP/porta. Separe vários por espaço, vírgula ou ponto e vírgula'
=======
        $inputAddress = Read-Host 'IP dos terminais (Enter para 177.74.189.75). Use IP:porta ou IP/porta'
>>>>>>> Stashed changes
        $Terminais = if ($inputAddress.Trim()) { $inputAddress } else { '177.74.189.75' }
    }
    $targets = [ordered]@{}
    foreach ($entry in ($Terminais -split '[\s,;]+' | Where-Object { $_ })) {
        $address = Get-TerminalAddress $entry
        if (!$targets.Contains($address)) { $targets[$address] = $entry }
    }
    if (!$targets.Count) { throw 'Informe pelo menos um endereço.' }
    $script:imagePath = Select-ImageFile $Imagem $Downloads
    $script:fileName = [IO.Path]::GetFileName($script:imagePath)
    Write-Host "Imagem do lote: $script:imagePath"
    Write-Host ("Terminais: " + ($targets.Values -join ', '))
    Write-Host "Programa HD | $Inicio até $Fim | $Dias"
    if (!(Ask-Yes 'Iniciar a publicação com essa imagem?')) { Write-Host 'Lote cancelado.'; return }
    if (!$PastaRelatorios) { $PastaRelatorios = Join-Path $PSScriptRoot 'Relatorios' }
    $null = [IO.Directory]::CreateDirectory($PastaRelatorios)
    $report = Join-Path $PastaRelatorios ('Publicacao-{0:yyyyMMdd-HHmmss}-{1}.csv' -f (Get-Date),([guid]::NewGuid().ToString('N').Substring(0,6)))
    $lock = New-Object Threading.Mutex($false,'Local\PublicacaoTelaFacialHD')
    $held = $false
    $script:local = $null
    $script:browser = $null
    $fileLock = $null
    try {
        try { $held = $lock.WaitOne(0) } catch [Threading.AbandonedMutexException] { $held = $true }
        if (!$held) { throw 'Outro lote está em andamento neste computador.' }
        $fileLock = [IO.File]::Open($script:imagePath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        Start-PanelBrowser (Join-Path $env:LOCALAPPDATA 'PublicacaoTelaHD\Navegador')
<<<<<<< Updated upstream
=======
        $batchHasPending = $false
>>>>>>> Stashed changes
        foreach ($script:address in $targets.Keys) {
            $script:target = $targets[$script:address]
            Write-Host "`nTerminal $script:target" -ForegroundColor Cyan
            $stage = 'Acesso'
            $row = [ordered]@{Terminal=$script:target; Imagem=$script:fileName; Periodo="$Inicio a $Fim ($Dias)"; Sleep='Pendente'; Biblioteca='Pendente'; ProgramaHD='Pendente'; Agenda='Pendente'; Motivo=''}
            try {
                Open-Terminal
                $stage = 'Screen Display'
                $row.Sleep = Set-Screen
                $stage = 'Biblioteca'
                Import-Media
                $row.Biblioteca = 'Imagem identificada'
                $stage = 'Programa HD'
                Set-Program
                $row.ProgramaHD = 'Gravado, releitura pendente'
                # Confirme o programa antes de alterar a agenda.
                Reload-Panel
                $row.ProgramaHD = Confirm-Program
                $stage = 'Agenda'
                Set-Agenda
                $row.Agenda = 'Gravada, releitura pendente'
                Reload-Panel
                $row.Agenda = Confirm-Agenda
            } catch {
                $row.Motivo = (@($row.Motivo,("$stage - " + $_.Exception.Message)) | Where-Object { $_ }) -join ' | '
            } finally { Close-Tab }
            $record = [pscustomobject]$row
            $record | Export-Csv -LiteralPath $report -Delimiter ';' -NoTypeInformation -Encoding UTF8 -Append
            $record | Format-List | Out-Host
        }
        Write-Host "Relatório do lote: $report"
    } finally {
        if ($script:local) {
            try { Connect-Tab; $null = Send-Cdp 'Browser.close' } catch {} finally { Close-Tab }
        }
        if ($fileLock) { $fileLock.Dispose() }
        if ($held) { $lock.ReleaseMutex() }
        $lock.Dispose()
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try { Publish-Batch }
    catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
}
