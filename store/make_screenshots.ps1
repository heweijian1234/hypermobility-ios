Add-Type -AssemblyName System.Drawing
$W = 1290; $H = 2796

function New-Canvas([int]$w, [int]$h, [int]$c1, [int]$c2, [int]$c3, [int]$c4) {
    $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::FromArgb($c1,$c2,$c3), [System.Drawing.Color]::FromArgb($c2,$c3,$c4), 60)
    $g.FillRectangle($bg, $rect)
    return @($bmp, $g)
}

function Draw-Card($g, [int]$x, [int]$y, [int]$w, [int]$h) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = 36
    $path.AddArc($x, $y, $r, $r, 180, 90); $path.AddArc($x+$w-$r, $y, $r, $r, 270, 90)
    $path.AddArc($x+$w-$r, $y+$h-$r, $r, $r, 0, 90); $path.AddArc($x, $y+$h-$r, $r, $r, 90, 90)
    $path.CloseFigure()
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235, 255, 255, 255))
    $g.FillPath($brush, $path)
}

function Draw-Text($g, [string]$text, [int]$x, [int]$y, [float]$size, [bool]$bold, [int]$r, [int]$gr, [int]$b) {
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $font = New-Object System.Drawing.Font('Segoe UI', $size, $style)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($r, $gr, $b))
    $g.DrawString($text, $font, $brush, $x, $y)
}

# 图1：主列表
$c = New-Canvas $W $H 40 22 50 70; $bmp = $c[0]; $g = $c[1]
Draw-Text $g 'HyperLog' 90 140 64 $true 255 255 255
Draw-Text $g '记录你的关节' 92 240 40 $false 255 255 255
$cards = @(
    @('膝盖 · 明显', '疼一两小时 · 自己复位的', '诱因：运动'),
    @('肩膀 · 严重（半脱位）', '疼几分钟 · 去医院复位的', '诱因：搬重物'),
    @('手指 · 轻微', '疼半小时左右 · 没复位', '诱因：说不清')
)
$y = 380
foreach ($card in $cards) {
    Draw-Card $g 70 $y ($W-140) 300
    Draw-Text $g $card[0] 130 ($y+56) 44 $true 45 35 50
    Draw-Text $g $card[1] 130 ($y+140) 34 $false 110 100 120
    Draw-Text $g $card[2] 130 ($y+210) 30 $false 150 140 160
    $y += 350
}
Draw-Card $g 70 $y ($W-140) 180
Draw-Text $g '+  快记：发作时一拍即记，疼过再补细节' 130 ($y+60) 36 $true 122 82 168
$bmp.Save('E:\AI-Projects\个人成长\10-项目\SaaS项目\hypermobility-ios\store\shot1.png', [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

# 图2：医生报告
$c = New-Canvas $W $H 40 22 50 70; $bmp = $c[0]; $g = $c[1]
Draw-Text $g '报告分享' 90 140 64 $true 255 255 255
Draw-Text $g '给医生看的 PDF：统计 + 图表 + 照片 + 明细' 92 240 36 $false 255 255 255
Draw-Card $g 70 380 ($W-140) 420
Draw-Text $g '最近 30 天' 130 430 40 $true 45 35 50
Draw-Text $g '38 次发作' 130 500 90 $true 122 82 168
Draw-Text $g '严重 6 次 · 就医复位 2 次 · 最频繁：肩膀' 130 640 32 $false 110 100 120
$y = 880
foreach ($row in @(@('肩膀', 420), @('膝盖', 300), @('手指', 180), @('背部', 120))) {
    Draw-Card $g 70 $y ($W-140) 160
    Draw-Text $g $row[0] 130 ($y+56) 40 $true 45 35 50
    $barBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(122, 82, 168))
    $g.FillRectangle($barBrush, 360, ($y+60), $row[1], 44)
    $y += 190
}
Draw-Card $g 70 $y ($W-140) 200
Draw-Text $g '📄 导出 PDF — 邮件直接发给医生' 130 ($y+70) 38 $true 122 82 168
$bmp.Save('E:\AI-Projects\个人成长\10-项目\SaaS项目\hypermobility-ios\store\shot2.png', [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

# 图3：隐私
$c = New-Canvas $W $H 45 25 55 75; $bmp = $c[0]; $g = $c[1]
$shield = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 200, 160, 90))
$g.FillEllipse($shield, 445, 700, 400, 400)
$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 34)
$g.DrawEllipse($pen, 545, 800, 200, 200)
Draw-Text $g '你的数据' 0 1300 100 $true 255 255 255
Draw-Text $g '永不出手机' 0 1450 100 $true 255 200 160
$fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
$font = New-Object System.Drawing.Font('Segoe UI', 100, [System.Drawing.FontStyle]::Bold)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$rectF = New-Object System.Drawing.RectangleF(0, 1280, $W, 200)
$g.DrawString('你的数据', $font, $brush, $rectF, $fmt)
$rectF2 = New-Object System.Drawing.RectangleF(0, 1440, $W, 200)
$brush2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 200, 160, 90))
$g.DrawString('永不出手机', $font, $brush2, $rectF2, $fmt)
$lines = @('无账号 · 无云端 · 无广告', '照片与记录只存在本机', 'Beighton 自评 · 关节分组 · PDF 报告')
$ly = 1900
foreach ($ln in $lines) {
    $rectL = New-Object System.Drawing.RectangleF(0, $ly, $W, 80)
    $g.DrawString($ln, (New-Object System.Drawing.Font('Segoe UI', 44, [System.Drawing.FontStyle]::Regular)), (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 255, 255, 255))), $rectL, $fmt)
    $ly += 110
}
$bmp.Save('E:\AI-Projects\个人成长\10-项目\SaaS项目\hypermobility-ios\store\shot3.png', [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output 'DONE 3 shots'
