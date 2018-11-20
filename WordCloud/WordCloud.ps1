﻿using namespace System.Drawing
using namespace System.Collections.Generic
using namespace System.Numerics

# PowerShell Core uses System.Drawing.Common assembly instead of System.Drawing
if ($PSEdition -eq 'Core') {
    Add-Type -AssemblyName 'System.Drawing.Common'
}
else {
    Add-Type -AssemblyName 'System.Drawing'
}

enum FileFormat {
    Bmp  = 0x0
    Emf  = 0x1
    Exif = 0x2
    Gif  = 0x3
    Jpeg = 0x4
    Png  = 0x5
    Tiff = 0x6
    Wmf  = 0x7
}

function ConvertTo-ImageFormat {
    [CmdletBinding()]
    [OutputType([Imaging.ImageFormat])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [FileFormat]
        $Format
    )
    process {
        switch ($Format) {
            ([FileFormat]::Bmp)  { [Imaging.ImageFormat]::Bmp  }
            ([FileFormat]::Emf)  { [Imaging.ImageFormat]::Emf  }
            ([FileFormat]::Exif) { [Imaging.ImageFormat]::Exif }
            ([FileFormat]::Gif)  { [Imaging.ImageFormat]::Gif  }
            ([FileFormat]::Jpeg) { [Imaging.ImageFormat]::Jpeg }
            ([FileFormat]::Png)  { [Imaging.ImageFormat]::Png  }
            ([FileFormat]::Tiff) { [Imaging.ImageFormat]::Tiff }
            ([FileFormat]::Wmf)  { [Imaging.ImageFormat]::Wmf  }
        }
    }
}

function Convert-ToRadians {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [double]
        $Degrees
    )
    process {
        ([Math]::PI / 180) * ($Degrees % 360)
    }
}

function New-WordCloud {
    [CmdletBinding()]
    [Alias('wordcloud', 'wcloud')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [Alias('Text', 'String', 'Words', 'Document', 'Page')]
        [AllowEmptyString()]
        [string[]]
        $InputString,

        [Parameter(Mandatory, Position = 1)]
        [Alias('OutFile', 'ExportPath', 'ImagePath')]
        [ValidateScript(
            { Test-Path -IsValid $_ -PathType Leaf }
        )]
        [string[]]
        $Path,

        [Parameter()]
        [Alias('ColourSet')]
        [KnownColor[]]
        $ColorSet = [Enum]::GetValues([KnownColor]),

        [Parameter()]
        [Alias('MaxColours')]
        [int]
        $MaxColors,

        [Parameter()]
        [Alias('FontFace')]
        [string]
        $FontFamily = 'Consolas',

        [Parameter()]
        [FontStyle]
        $FontStyle = [FontStyle]::Regular,

        [Parameter()]
        [ValidateRange(512, 16384)]
        [Alias('ImagePixelSize')]
        [int]
        $ImageSize = 2048,

        [Parameter()]
        [ValidateRange(1, 20)]
        $DistanceStep = 5,

        [Parameter()]
        [ValidateRange(1, 50)]
        $RadialGranularity = 15,

        [Parameter()]
        [AllowNull()]
        [Alias('BackgroundColour')]
        [Nullable[KnownColor]]
        $BackgroundColor = [KnownColor]::Black,

        [Parameter()]
        [switch]
        [Alias('Greyscale', 'Grayscale')]
        $Monochrome,

        [Parameter()]
        [Alias('ImageFormat', 'Format')]
        [FileFormat]
        $OutputFormat = [FileFormat]::Png
    )
    begin {
        if (-not (Test-Path -Path $Path)) {
            $Path = (New-Item -ItemType File -Path $Path).FullName
        }
        else {
            $Path = (Get-Item -Path $Path).FullName
        }

        $Noise = [Random]::new()

        $ExportFormat = $OutputFormat | ConvertTo-ImageFormat
        Write-Verbose "Export Format: $ExportFormat"

        $ExcludedWords = @(
            'a', 'about', 'above', 'after', 'again', 'against', 'all', 'also', 'am', 'an', 'and', 'any', 'are', 'aren''t', 'as',
            'at', 'be', 'because', 'been', 'before', 'being', 'below', 'between', 'both', 'but', 'by', 'can', 'can''t',
            'cannot', 'com', 'could', 'couldn''t', 'did', 'didn''t', 'do', 'does', 'doesn''t', 'doing', 'don''t', 'down',
            'during', 'each', 'else', 'ever', 'few', 'for', 'from', 'further', 'get', 'had', 'hadn''t', 'has', 'hasn''t',
            'have', 'haven''t', 'having', 'he', 'he''d', 'he''ll', 'he''s', 'hence', 'her', 'here', 'here''s', 'hers',
            'herself', 'him', 'himself', 'his', 'how', 'how''s', 'however', 'http', 'i', 'i''d', 'i''ll', 'i''m', 'i''ve', 'if',
            'in', 'into', 'is', 'isn''t', 'it', 'it''s', 'its', 'itself', 'just', 'k', 'let''s', 'like', 'me', 'more', 'most',
            'mustn''t', 'my', 'myself', 'no', 'nor', 'not', 'of', 'off', 'on', 'once', 'only', 'or', 'other', 'otherwise',
            'ought', 'our', 'ours', 'ourselves', 'out', 'over', 'own', 'r', 'same', 'shall', 'shan''t', 'she', 'she''d',
            'she''ll', 'she''s', 'should', 'shouldn''t', 'since', 'so', 'some', 'such', 'than', 'that', 'that''s', 'the',
            'their', 'theirs', 'them', 'themselves', 'then', 'there', 'there''s', 'therefore', 'these', 'they', 'they''d',
            'they''ll', 'they''re', 'they''ve', 'this', 'those', 'through', 'to', 'too', 'under', 'until', 'up', 'very', 'was',
            'wasn''t', 'we', 'we''d', 'we''ll', 'we''re', 'we''ve', 'were', 'weren''t', 'what', 'what''s', 'when', 'when''s',
            'where', 'where''s', 'which', 'while', 'who', 'who''s', 'whom', 'why', 'why''s', 'with', 'won''t', 'would',
            'wouldn''t', 'www', 'you', 'you''d', 'you''ll', 'you''re', 'you''ve', 'your', 'yours', 'yourself', 'yourselves'
        ) -join '|'

        $SplitChars = [char[]]" `n.,`"?!{}[]:()`“`”™"
        $WordList = [List[string]]::new()

        $WordHeightTable = @{}
        $WordSizeTable = @{}

        $MaxColors = if ($PSBoundParameters.ContainsKey('MaxColors')) { $MaxColors } else { [int]::MaxValue }
        $MinSaturation = if ($Monochrome) { 0 } else { 0.5 }

        $ColorList = $ColorSet |
            Sort-Object {Get-Random} |
            Select-Object -First $MaxColors |
            ForEach-Object {
                if (-not $Monochrome) {
                    [Color]::FromKnownColor($_)
                }
                else {
                    [int]$Brightness = [Color]::FromKnownColor($_).GetBrightness() * 255
                    [Color]::FromArgb($Brightness, $Brightness, $Brightness)
                }
            } | Where-Object {
                if ($BackgroundColor) {
                    $_.Name -notmatch $BackgroundColor -and
                    $_.GetSaturation() -ge $MinSaturation
                }
                else {
                    $_.GetSaturation() -ge $MinSaturation
                }
            } | Sort-Object -Descending {
                $Value = $_.GetBrightness()
                $Random = (-$Value..$Value | Get-Random) / (1 - $_.GetSaturation())
                $Value + $Random
            }

        $RectangleList = [List[RectangleF]]::new()

        $ColorIndex = 0
        $RadialDistance = 0
    }
    process {
        $WordList.AddRange(
            $InputString.Split($SplitChars, [StringSplitOptions]::RemoveEmptyEntries).Where{
                $_ -notmatch "^($ExcludedWords)s?$|^[^a-z]+$|[^a-z0-9'_-]" -and $_.Length -gt 1
            } -replace "^'|'$" -as [string[]]
        )
    }
    end {
        # Count occurrence of each word
        $RemoveList = [List[string]]::new()
        switch ($WordList) {
            { $WordHeightTable[($_ -replace 's$')] } {
                $WordHeightTable[($_ -replace 's$')] += 1
                continue
            }
            { $WordHeightTable[("${_}s")] } {
                $WordHeightTable[($_)] = $WordHeightTable[("${_}s")] + 1
                $RemoveList.Add("${_}s")
                continue
            }
            default {
                $WordHeightTable[($_)] += 1
                continue
            }
        }
        foreach ($Word in $RemoveList) {
            $WordHeightTable.Remove($Word)
        }

        $SortedWordList = $WordHeightTable.GetEnumerator().Name |
            Sort-Object -Descending {
                $WordHeightTable[$_]
            } | Select-Object -First 100

        $HighestFrequency, $AverageFrequency = $WordHeightTable.PSObject.BaseObject.Values |
            Measure-Object -Average -Maximum |
            ForEach-Object {$_.Maximum, $_.Average}

        $MaxFontSize = [Math]::Round($ImageSize / ($HighestFrequency / $AverageFrequency) )
        Write-Verbose "Unique Words Count: $($WordHeightTable.PSObject.BaseObject.Count)"
        Write-Verbose "Highest Word Frequency: $HighestFrequency; Average: $AverageFrequency"
        Write-Verbose "Max Font Size: $MaxFontSize"

        try {
            # Create a graphics object to measure the text's width and height.
            $DummyImage = [Bitmap]::new(1, 1)
            $Graphics = [Graphics]::FromImage($DummyImage)

            foreach ($Word in $SortedWordList) {
                $WordHeightTable[$Word] = [Math]::Round( ($WordHeightTable[$Word] / $HighestFrequency) * $MaxFontSize)
                if ($WordHeightTable[$Word] -lt 8) { continue }

                $Font = [Font]::new(
                    $FontFamily,
                    $WordHeightTable[$Word],
                    $FontStyle,
                    [GraphicsUnit]::Pixel
                )

                $MeasuredSize = $Graphics.MeasureString($Word, $Font)
                $WordSizeTable[$Word] = [SizeF]::new([float]$MeasuredSize.Width, [float]$MeasuredSize.Height)
            }
            $WordHeightTable | Out-String | Write-Verbose
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        finally {
            if ($Graphics) {
                $Graphics.Dispose()
            }
            if ($DummyImage) {
                $DummyImage.Dispose()
            }
        }

        #[SizeF]$FocalWord = $WordSizeTable[$SortedWordList[0]]
        #$WordSizeTable[$SortedWordList[0]] = [SizeF]::new($FocalWord.Width, $FocalWord.Height * 0.6)

        $CentrePoint = [PointF]::new($ImageSize / 2, $ImageSize / 2)
        Write-Verbose "Final Image size will be $ImageSize with centrepoint $CentrePoint"

        try {
            $WordCloudImage = [Bitmap]::new($ImageSize, $ImageSize)
            $DrawingSurface = [Graphics]::FromImage($WordCloudImage)

            if ($BackgroundColor) {
                $DrawingSurface.Clear([Color]::FromKnownColor($BackgroundColor))
            }
            $DrawingSurface.SmoothingMode = [Drawing2D.SmoothingMode]::AntiAlias
            $DrawingSurface.TextRenderingHint = [Text.TextRenderingHint]::AntiAlias

            $RadialScanCount = 0
            :words foreach ($Word in $SortedWordList) {
                $Font = [Font]::new(
                    $FontFamily,
                    $WordHeightTable[$Word],
                    $FontStyle,
                    [GraphicsUnit]::Pixel
                )

                $RadialScanCount /= 3
                $WordRectangle = $null
                do {
                    if ( $RadialDistance -gt ($ImageSize / 2) ) {
                        continue words
                    }
                    $IsColliding = $false

                    $AngleIncrement = 360 / ( ($RadialDistance + 1) * $RadialGranularity / 10 )
                    switch ([int]$RadialScanCount -band 7) {
                        0 {
                            $Start = 0
                            $End = 360
                        }
                        1 {
                            $Start = -90
                            $End = 270
                        }
                        2 {
                            $Start = -180
                            $End = 180
                        }
                        3 {
                            $Start = -270
                            $End = 90
                        }
                        4 {
                            $AngleIncrement = - $AngleIncrement
                            $Start = 360
                            $End = 0
                        }
                        5 {
                            $AngleIncrement = - $AngleIncrement
                            $Start = 270
                            $End = -90
                        }
                        6 {
                            $AngleIncrement = - $AngleIncrement
                            $Start = 180
                            $End = -180
                        }
                        7 {
                            $AngleIncrement = - $AngleIncrement
                            $Start = 90
                            $End = -270
                        }
                    }

                    for (
                        $Angle = $Start;
                        $( if ($Start -lt $End) {$Angle -le $End} else {$End -le $Angle} );
                        $Angle += $AngleIncrement
                    ) {
                        $Radians = Convert-ToRadians -Degrees $Angle
                        $Complex = [Complex]::FromPolarCoordinates($RadialDistance, $Radians)

                        # Target center of text on target point
                        #$CentreOffset = Get-Random -Minimum 0.0 -Maximum 1.0
                        $OffsetX = $WordSizeTable[$Word].Width * $Noise.NextDouble()
                        $OffsetY = $WordSizeTable[$Word].Height * $Noise.NextDouble()
                        $DrawLocation = [PointF]::new(
                            $Complex.Real + $CentrePoint.X - $OffsetX,
                            $Complex.Imaginary + $CentrePoint.Y - $OffsetY
                        )

                        $WordRectangle = [RectangleF]::new($DrawLocation, $WordSizeTable[$Word])

                        foreach ($Rectangle in $RectangleList) {
                            $IsColliding = (
                                $WordRectangle.IntersectsWith($Rectangle) -or
                                $WordRectangle.Top -lt 0 -or
                                $WordRectangle.Bottom -gt $ImageSize -or
                                $WordRectangle.Left -lt 0 -or
                                $WordRectangle.Right -gt $ImageSize
                            )

                            if ($IsColliding) {
                                break
                            }
                        }

                        if (!$IsColliding) {
                            break
                        }
                    }

                    if ($IsColliding) {
                        $RadialDistance += $DistanceStep
                        $RadialScanCount++
                    }
                } while ($IsColliding)

                $RectangleList.Add($WordRectangle)
                $Color = $ColorList[$ColorIndex]

                $ColorIndex++
                if ($ColorIndex -ge $ColorList.Count) {
                    $ColorIndex = 0
                }

                $DrawingSurface.DrawString($Word, $Font, [SolidBrush]::new($Color), $DrawLocation)


                $RadialDistance -= $DistanceStep * ($RadialScanCount / 2)
            }

            $DrawingSurface.Flush()
            $WordCloudImage.Save($Path, $ExportFormat)
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        finally {
            $DrawingSurface.Dispose()
            $WordCloudImage.Dispose()
        }
    }
}