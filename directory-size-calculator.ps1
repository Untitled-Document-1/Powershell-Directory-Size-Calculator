Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#----------------------------------------------------------
# Helper Functions
#----------------------------------------------------------

function Format-Size {
    param([Int64]$Bytes)

    switch ($Bytes) {
        { $_ -ge 1TB } { "{0:N2} TB" -f ($Bytes / 1TB); break }
        { $_ -ge 1GB } { "{0:N2} GB" -f ($Bytes / 1GB); break }
        { $_ -ge 1MB } { "{0:N2} MB" -f ($Bytes / 1MB); break }
        { $_ -ge 1KB } { "{0:N2} KB" -f ($Bytes / 1KB); break }
        default { "$Bytes Bytes" }
    }
}

function Get-FolderSize {

    param(
        [string]$Path,
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [System.Windows.Forms.Label]$StatusLabel
    )

    $script:FolderCount++

    if ($script:FolderCount % 25 -eq 0) {
        $StatusLabel.Text = "Scanning: $Path"
        [System.Windows.Forms.Application]::DoEvents()
    }

    $size = 0

    try {

        Get-ChildItem -LiteralPath $Path -File -Force -ErrorAction SilentlyContinue |
        ForEach-Object {
            $size += $_.Length
        }

        $children = New-Object 'System.Collections.Generic.List[object]'

        Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue |
        Sort-Object Name |
        ForEach-Object {

            $child = Get-FolderSize $_.FullName $ProgressBar $StatusLabel

            $children.Add($child)

            $size += $child.Size
        }

        [PSCustomObject]@{
            Name     = Split-Path $Path -Leaf
            Path     = $Path
            Size     = $size
            Children = $children
        }

    }
    catch {
        [PSCustomObject]@{
            Name     = Split-Path $Path -Leaf
            Path     = $Path
            Size     = 0
            Children = @()
        }
    }
}

function Add-TreeNode {

    param(
        $TreeCollection,
        $Folder,
        [Int64]$TotalSize
    )

    if ($TotalSize -eq 0) {
        $percent = 0
    }
    else {
        $percent = ($Folder.Size / $TotalSize) * 100
    }

    $text = "{0}    [{1}]    ({2:N2}%)" -f `
    $(if ($Folder.Name) { $Folder.Name }else { $Folder.Path }),
    (Format-Size $Folder.Size),
    $percent

    $node = New-Object System.Windows.Forms.TreeNode
    $node.Text = $text

    $TreeCollection.Add($node) | Out-Null

    foreach ($child in $Folder.Children) {
        Add-TreeNode $node.Nodes $child $TotalSize
    }
}

#----------------------------------------------------------
# GUI
#----------------------------------------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "Directory Size Calculator"
$form.Size = New-Object System.Drawing.Size(1000, 700)
$form.StartPosition = "CenterScreen"

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Choose Folder"
$btnBrowse.Location = New-Object System.Drawing.Point(10, 10)
$btnBrowse.Size = New-Object System.Drawing.Size(120, 30)

$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.Location = New-Object System.Drawing.Point(140, 14)
$txtFolder.Width = 720

$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "Scan"
$btnScan.Location = New-Object System.Drawing.Point(870, 10)
$btnScan.Size = New-Object System.Drawing.Size(90, 30)

$tree = New-Object System.Windows.Forms.TreeView
$tree.Location = New-Object System.Drawing.Point(10, 80)
$tree.Size = New-Object System.Drawing.Size(950, 540)
$tree.Font = New-Object System.Drawing.Font("Consolas", 10)

$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(10, 50)
$status.Size = New-Object System.Drawing.Size(800, 20)
$status.Text = "Ready"

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(820, 50)
$progress.Size = New-Object System.Drawing.Size(140, 20)
$progress.Style = "Marquee"

$form.Controls.AddRange(@(
        $btnBrowse,
        $txtFolder,
        $btnScan,
        $tree,
        $status,
        $progress))

$progress.Visible = $false

#----------------------------------------------------------
# Browse
#----------------------------------------------------------

$btnBrowse.Add_Click({

        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.ShowNewFolderButton = $false

        if ($dialog.ShowDialog() -eq "OK") {
            $txtFolder.Text = $dialog.SelectedPath
        }

    })

#----------------------------------------------------------
# Scan
#----------------------------------------------------------

$btnScan.Add_Click({

        if (!(Test-Path $txtFolder.Text)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please choose a valid folder."
            )
            return
        }

        $tree.Nodes.Clear()

        $progress.Visible = $true
        $status.Text = "Scanning..."
        $form.Refresh()

        $script:FolderCount = 0

        $root = Get-FolderSize `
            -Path $txtFolder.Text `
            -ProgressBar $progress `
            -StatusLabel $status

        $tree.BeginUpdate()

        Add-TreeNode `
            -TreeCollection $tree.Nodes `
            -Folder $root `
            -TotalSize $root.Size

        $tree.EndUpdate()

        if ($tree.Nodes.Count -gt 0) {
            $tree.Nodes[0].Expand()
        }

        $progress.Visible = $false

        $status.Text = "Finished. Total Size: $(Format-Size $root.Size)"

    })

#----------------------------------------------------------

[void]$form.ShowDialog()