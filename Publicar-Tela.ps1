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

function Get-TerminalUrl([string]$value) {
    $value = $value.Trim()
    if (!$value) { throw 'Endereço vazio.' }
    if ($value -notmatch '^[a-z][a-z\d+.-]*://') { $value = 'http://' + $value }
    $uri = $null
    if (![Uri]::TryCreate($value, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -notin 'http','https' -or
        !$uri.Host -or $uri.UserInfo -or $value -match '[\s\\]') { throw "Endereço inválido: $value" }
    # Uma URL com caminho numérico também pode ser válida. O operador decide.
    if ($value -match '^https?://(?:\[[^\]]+\]|[^/:?#]+)/(?<porta>[0-9]{1,5})/?$') {
        $port = [int]$Matches.porta
        if ($port -ge 1 -and $port -le 65535) {
            $alternative = [UriBuilder]::new($uri)
            $alternative.Port = $port
            $alternative.Path = '/'
            Write-Host "Com a barra, o endereço é $($uri.AbsoluteUri). Usando a porta $port, fica $($alternative.Uri.AbsoluteUri)." -ForegroundColor Yellow
            if (Ask-Yes "Usar a porta $port neste terminal? Responda N para manter a barra.") {
                return $alternative.Uri.AbsoluteUri
            }
        }
    }
    return $uri.AbsoluteUri
}

function Select-ImageFile([string]$path, [string]$folder) {
    $types = @('.png','.jpg','.jpeg','.bmp','.gif','.webp','.tif','.tiff','.ico','.jfif')
    if (!$path) {
        if (!$folder) {
            $folder = (Get-ItemProperty -ErrorAction SilentlyContinue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders').'{374DE290-123F-4565-9164-39C4925E467B}'
            if ($folder) { $folder = [Environment]::ExpandEnvironmentVariables($folder) }
            else { $folder = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads' }
        }
        try {
            $files = @(Get-ChildItem -File -LiteralPath $folder | Where-Object {
                $_.Extension -notin '.tmp','.crdownload','.part','.partial','.download' -and $_.Name -notlike '~*'
            } | Sort-Object LastWriteTimeUtc -Descending)
            if ($files.Count -gt 0 -and ($files.Count -eq 1 -or $files[0].LastWriteTimeUtc -ne $files[1].LastWriteTimeUtc) -and
                $files[0].Extension -in $types) { $path = $files[0].FullName }
        } catch { Write-Host "Falha ao ler Downloads: $($_.Exception.Message)" }
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
        if ($item -is [IO.FileInfo] -and $item.Extension -in $types -and $item.Length -gt 0) { return $item.FullName }
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
            } finally { $stream.Dispose() }
        } until ($response.id -eq $id)
        if ($response.error) { throw "$method - $($response.error.message)" }
        return $response.result
    } finally { $cts.Dispose() }
}

function Connect-Tab {
    $tab = Invoke-RestMethod -Method Put -DisableKeepAlive -Body ([byte[]]@()) -UseBasicParsing -TimeoutSec 5 -Uri "$script:local/json/new?about:blank"
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
    $data.url = $script:target
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

function Open-Screen {
    if (Invoke-Panel 'menuSelected' @{rotulos=$script:screen}) { return $true }
    $path = @(
        @{rotulos=$script:configuration; proximos=$script:preferences},
        @{rotulos=$script:preferences; proximos=$script:screen},
        @{rotulos=$script:screen; proximos=@()}
    )
    foreach ($step in $path) {
        if (Invoke-Panel 'menuSelected' @{rotulos=$step.rotulos}) { continue }
        $name = $step.rotulos[0]
        Write-Host "Abrindo $name..."
        $limit = [DateTime]::UtcNow.AddSeconds(8)
        do {
            $point = Invoke-Panel 'menuPoint' @{rotulos=$step.rotulos}
            if ($point) { break }
            Start-Sleep -Milliseconds 250
        } while ([DateTime]::UtcNow -lt $limit)
        if ($point) {
            $null = Send-Cdp 'Input.dispatchMouseEvent' @{type='mouseMoved';x=$point.x;y=$point.y}
            $null = Send-Cdp 'Input.dispatchMouseEvent' @{type='mousePressed';button='left';buttons=1;clickCount=1;x=$point.x;y=$point.y}
            $null = Send-Cdp 'Input.dispatchMouseEvent' @{type='mouseReleased';button='left';buttons=0;clickCount=1;x=$point.x;y=$point.y}
            if (Wait-Panel 'menuReached' $step 8) { continue }
        }
        Ask-Step "Não consegui confirmar a abertura de $name. Clique em $name no painel e digite C para o script continuar."
    }
    return (Wait-Panel 'menuReached' $path[-1] 3)
}
function Open-Notice { return (Open-Section @(@{labels=$script:notice})) }
function Open-Library { return (Open-Section @(@{labels=$script:notice},@{labels=$script:library})) }
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
    $opened = Open-Screen
    $state = Invoke-Panel 'sleep'
    if (!$opened -or $null -eq $state) {
        Ask-Step 'Em Screen Display, confira Sleep, desative se necessário e clique em Save. Aguarde a confirmação.'
    } else {
        if ($state) {
            $clicked = Invoke-Panel 'disable'
            if ($clicked) { Start-Sleep -Milliseconds 350 }
        }
        if (!(Invoke-Panel 'saveSleep')) {
            Ask-Step 'Em Screen Display, confirme Sleep desativado, salve a seção e aguarde a confirmação.'
        } else { Wait-Save }
    }
    Reload-Panel
    $opened = Open-Screen
    $state = Invoke-Panel 'sleep'
    if ($opened -and $null -ne $state -and !$state) { return 'Confirmado na releitura' }
    if ($opened -and $state -eq $true) { throw 'Sleep continuou ativado após reabrir a tela.' }
    Ask-Step 'Após a recarga, reabra Screen Display e confira se Sleep está desativado.'
    return 'Conferido pelo operador após recarga'
}

function Import-Media {
    if (!(Open-Library)) { Ask-Step 'Abra Notice Publication > Media Library Management. Confira que a biblioteca está visível.' }
    if (Invoke-Panel 'media') {
        if (Ask-Yes "A biblioteca contém '$script:fileName'. A miniatura corresponde à imagem deste lote?") { return }
        throw 'Já existe outra mídia com esse nome. Use um arquivo com nome distinto para evitar associação incorreta.'
    }
    # O navegador recebe exatamente o caminho escolhido, sem digitação simulada.
    $fileId = Invoke-Panel 'file' @{} -Object
    if ($fileId) {
        try { $null = Send-Cdp 'DOM.setFileInputFiles' @{objectId=$fileId;files=@($script:imagePath)} }
        finally { $null = Send-Cdp 'Runtime.releaseObject' @{objectId=$fileId} }
        if (!(Wait-Panel 'media' @{} 4)) {
            Ask-Step "O arquivo foi selecionado. Conclua a importação, se o painel pedir, e confira '$script:fileName' na biblioteca antes de continuar."
        }
    } else {
        Ask-Step "Confira a biblioteca. Se a mesma imagem já estiver disponível, reutilize-a. Caso contrário, use Import para selecionar '$script:imagePath'. Aguarde a conclusão e confira o nome e a miniatura."
    }
}

function Set-Program {
    $opened = Open-Notice
    if (!$opened) { Ask-Step 'Abra Notice Publication e exiba a lista de programas.' }
    $existing = (Invoke-Panel 'openHD') -and (Wait-Panel 'editor')
    if (!$existing) {
        if (Ask-Yes 'Confira a lista completa, inclusive outras páginas. Já existe o programa HD?') {
            Ask-Step 'Abra o programa HD existente para edição.'
        } else {
            $added = Invoke-Panel 'click' @{rotulos=@('Add Program','Adicionar programa')}
            if ($added) { Start-Sleep -Milliseconds 350 }
            if (!$added -or !(Invoke-Panel 'nameHD') -or !(Wait-Panel 'editor')) {
                Ask-Step 'Abra Add Program, dê o nome HD ao novo programa e deixe o editor aberto.'
            }
        }
    }
    if (!(Invoke-Panel 'inProgram')) {
        $picked = $false
        if (Invoke-Panel 'addImage') {
            Start-Sleep -Milliseconds 350
            $picked = Invoke-Panel 'pick'
            if ($picked -and !(Wait-Panel 'inProgram' @{} 1)) { $null = Invoke-Panel 'acceptPicker' }
        }
        if (!$picked -or !(Wait-Panel 'inProgram')) {
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
    $opened = Open-Notice
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
    Connect-Tab
    $navigation = Send-Cdp 'Page.navigate' @{url=$script:target}
    if ($navigation.errorText -like 'net::ERR_CERT_*') {
        Ask-Step 'O navegador pediu a verificação do certificado. Confira o endereço e resolva o aviso no navegador segundo o procedimento do equipamento.'
    } elseif ($navigation.errorText -eq 'net::ERR_BLOCKED_BY_CLIENT') {
        $failure = "O navegador bloqueou a abertura de $script:target ($($navigation.errorText))."
        try {
            Ask-Step "$failure Na mesma aba, abra esse endereço pela barra do navegador. Digite C quando o painel ou o login aparecer, ou P se o bloqueio continuar."
        } catch { throw "$failure $($_.Exception.Message)" }
        if (!(Wait-Panel 'ready' @{} 5)) { throw "$failure A aba ainda não carregou o endereço do terminal." }
    } elseif ($navigation.errorText) { throw "Falha ao abrir o terminal: $($navigation.errorText)" }
    Enter-Terminal
}

function Publish-Batch {
    if ([string]::CompareOrdinal($Inicio,$Fim) -ge 0 -or [string]::IsNullOrWhiteSpace($Dias)) { throw 'Indique os dias e um intervalo com início anterior ao fim.' }
    if (!$Terminais) { $Terminais = @((Read-Host 'IPs ou URLs dos terminais (ex.: 192.168.1.50:8686; HTTP por padrão). Separe os endereços por espaço, vírgula ou ponto e vírgula')) }
    $targets = @($Terminais -split '[\s,;]+' | Where-Object { $_ } | ForEach-Object { Get-TerminalUrl $_ } | Select-Object -Unique)
    if (!$targets.Count) { throw 'Informe pelo menos um endereço.' }
    $script:imagePath = Select-ImageFile $Imagem $Downloads
    $script:fileName = [IO.Path]::GetFileName($script:imagePath)
    Write-Host "Imagem do lote: $script:imagePath"
    Write-Host ("Terminais: " + ($targets -join ', '))
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
        foreach ($script:target in $targets) {
            Write-Host "`nTerminal $script:target" -ForegroundColor Cyan
            $stage = 'Acesso'
            $row = [ordered]@{Terminal=$script:target; Imagem=$script:fileName; Periodo="$Inicio a $Fim ($Dias)"; Sleep='Pendente'; Biblioteca='Pendente'; ProgramaHD='Pendente'; Agenda='Pendente'; Motivo=''}
            try {
                Open-Terminal
                $stage = 'Screen Display'
                try { $row.Sleep = Set-Screen } catch {
                    if ($_.Exception.Message -like 'PULAR IP.*') { throw }
                    $row.Motivo = "Screen Display - $($_.Exception.Message)"
                    Write-Host $row.Motivo -ForegroundColor Yellow
                }
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
