<#
.SYNOPSIS
This script generates command line enrollment scripts based on the provided parameters. These are intended to be used for automating the enrollment process for Windows devices into WS1
.DESCRIPTION
   Created by John Tomchick September 1st, 2026. 

.PARAMETER ParameterName
    Description of the parameter.

.EXAMPLE
    Example of how to use the script.
#>
[CmdletBinding()]
param()

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function Test-EnrollmentInput {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Answers
    )

    $errors = New-Object 'System.Collections.Generic.List[string]'
    foreach ($key in @('MsiPath', 'Server', 'GroupId', 'Username', 'Password')) {
        if ([string]::IsNullOrWhiteSpace([string]$Answers[$key])) {
            $errors.Add("$key is required.")
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Answers.Server) -and
        $Answers.Server -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*$') {
        $errors.Add('Enter the Device Services hostname only, without https:// or a trailing slash.')
    }

    if (-not [string]::IsNullOrWhiteSpace($Answers.MsiPath)) {
        if (-not (Test-Path -LiteralPath $Answers.MsiPath -PathType Leaf)) {
            $errors.Add('Select an existing AirWatchAgent.msi file.')
        }
        elseif ([System.IO.Path]::GetExtension($Answers.MsiPath) -ne '.msi') {
            $errors.Add('The selected installer must be an .msi file.')
        }
    }

    foreach ($key in @('MsiPath', 'GroupId', 'Username', 'Password')) {
        if ([string]$Answers[$key] -match '["\r\n]') {
            $errors.Add("$key cannot contain a double quote or a line break.")
        }
    }

    if ($Answers.AssignToLoggedInUser -notin @('Y', 'N')) {
        $errors.Add('Choose Y or N for assignment to the logged-in user.')
    }

    return $errors.ToArray()
}

function ConvertTo-BatchValue {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    '"' + $Value.Replace('%', '%%') + '"'
}

function New-EnrollmentScript {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Answers
    )

    $msiPath = ConvertTo-BatchValue -Value $Answers.MsiPath
    $server = ConvertTo-BatchValue -Value $Answers.Server
    $groupId = ConvertTo-BatchValue -Value $Answers.GroupId
    $username = ConvertTo-BatchValue -Value $Answers.Username
    $password = ConvertTo-BatchValue -Value $Answers.Password

    @"
@echo off
setlocal DisableDelayedExpansion
if not exist $msiPath (
    echo ERROR: AirWatchAgent.msi was not found at the configured path.
    exit /b 2
)

echo Starting Workspace ONE Intelligent Hub enrollment...
msiexec.exe /i $msiPath /q ENROLL=Y SERVER=$server LGName=$groupId USERNAME=$username PASSWORD=$password ASSIGNTOLOGGEDINUSER=$($Answers.AssignToLoggedInUser)
exit /b %ERRORLEVEL%
"@
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Workspace ONE Enrollment Batch Generator'
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object System.Drawing.Size(660, 490)
$form.Size = New-Object System.Drawing.Size(760, 550)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.InitialDelay = 500
$toolTip.ReshowDelay = 100
$toolTip.AutoPopDelay = 20000
$toolTip.ShowAlways = $true
$form.Add_FormClosed({ $toolTip.Dispose() })

$layout = New-Object System.Windows.Forms.TableLayoutPanel
$layout.Dock = 'Fill'
$layout.Padding = New-Object System.Windows.Forms.Padding(14)
$layout.ColumnCount = 3
$layout.RowCount = 9
$layout.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 155))
$layout.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100))
$layout.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 100))
$form.Controls.Add($layout)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Generate a silent enrollment batch file'
$title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 12)
$title.AutoSize = $true
$title.Margin = New-Object System.Windows.Forms.Padding(3, 5, 3, 12)
$layout.Controls.Add($title, 0, 0)
$layout.SetColumnSpan($title, 3)

$msiTextBox = New-Object System.Windows.Forms.TextBox
$msiTextBox.Dock = 'Fill'
$msiTextBox.Name = 'MsiPath'
$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = 'Browse...'
$browseButton.AutoSize = $true
$layout.Controls.Add($msiTextBox, 1, 1)
$layout.Controls.Add($browseButton, 2, 1)

$serverTextBox = New-Object System.Windows.Forms.TextBox
$serverTextBox.Dock = 'Fill'
$serverTextBox.Name = 'Server'
$layout.Controls.Add($serverTextBox, 1, 2)

$groupTextBox = New-Object System.Windows.Forms.TextBox
$groupTextBox.Dock = 'Fill'
$groupTextBox.Name = 'GroupId'
$layout.Controls.Add($groupTextBox, 1, 3)

$toolTip.SetToolTip($serverTextBox, "In the Workspace ONE UEM console, go to Groups & Settings > All Settings > System > Advanced > Site URLs.`nUse the hostname from the Device Services URL, without https:// or a path.`nExample: ds123.awmdm.com")
$toolTip.SetToolTip($groupTextBox, "Select the organization group used for enrollment, then go to Groups & Settings > Groups > Organization Groups > Details.`nCopy the Group ID, not the group name or numeric organization group ID.")

$usernameTextBox = New-Object System.Windows.Forms.TextBox
$usernameTextBox.Dock = 'Fill'
$usernameTextBox.Name = 'Username'
$layout.Controls.Add($usernameTextBox, 1, 4)

$passwordTextBox = New-Object System.Windows.Forms.TextBox
$passwordTextBox.Dock = 'Fill'
$passwordTextBox.Name = 'Password'
$passwordTextBox.UseSystemPasswordChar = $true
$layout.Controls.Add($passwordTextBox, 1, 5)

$assignmentCombo = New-Object System.Windows.Forms.ComboBox
$assignmentCombo.DropDownStyle = 'DropDownList'
$assignmentCombo.Items.AddRange(@('Y - switch to current user', 'N - switch at next logon'))
$assignmentCombo.SelectedIndex = 1
$assignmentCombo.Width = 275
$layout.Controls.Add($assignmentCombo, 1, 6)

$labels = @(
    @{ Row = 1; Text = 'AirWatchAgent.msi' },
    @{ Row = 2; Text = 'Device Services hostname' },
    @{ Row = 3; Text = 'Group ID' },
    @{ Row = 4; Text = 'Staging username' },
    @{ Row = 5; Text = 'Staging password' },
    @{ Row = 6; Text = 'Assign to logged-in user' }
)
foreach ($item in $labels) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $item.Text
    $label.AutoSize = $true
    $label.Anchor = 'Left'
    $label.Margin = New-Object System.Windows.Forms.Padding(3, 8, 3, 3)
    $layout.Controls.Add($label, 0, $item.Row)
    if ($item.Row -eq 2) {
        $toolTip.SetToolTip($label, $toolTip.GetToolTip($serverTextBox))
    }
    elseif ($item.Row -eq 3) {
        $toolTip.SetToolTip($label, $toolTip.GetToolTip($groupTextBox))
    }
}

$securityWarning = New-Object System.Windows.Forms.Label
$securityWarning.Text = 'The generated .bat contains the staging password in plain text. Restrict access to it and delete it after use.'
$securityWarning.ForeColor = [System.Drawing.Color]::DarkRed
$securityWarning.AutoSize = $true
$securityWarning.MaximumSize = New-Object System.Drawing.Size(650, 0)
$layout.Controls.Add($securityWarning, 0, 7)
$layout.SetColumnSpan($securityWarning, 3)

$buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$buttonPanel.Dock = 'Fill'
$buttonPanel.FlowDirection = 'RightToLeft'
$buttonPanel.AutoSize = $true
$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Text = 'Create .bat'
$saveButton.AutoSize = $true
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = 'Cancel'
$cancelButton.AutoSize = $true
$buttonPanel.Controls.Add($cancelButton)
$buttonPanel.Controls.Add($saveButton)
$layout.Controls.Add($buttonPanel, 0, 8)
$layout.SetColumnSpan($buttonPanel, 3)

$browseButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = 'Select the Workspace ONE Intelligent Hub installer'
    $dialog.Filter = 'Windows Installer (*.msi)|*.msi|All files (*.*)|*.*'
    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $msiTextBox.Text = $dialog.FileName
    }
})

$cancelButton.Add_Click({ $form.Close() })
$saveButton.Add_Click({
    $answers = @{
        MsiPath = $msiTextBox.Text.Trim()
        Server = $serverTextBox.Text.Trim()
        GroupId = $groupTextBox.Text.Trim()
        Username = $usernameTextBox.Text.Trim()
        Password = $passwordTextBox.Text
        AssignToLoggedInUser = ([string]$assignmentCombo.SelectedItem).Substring(0, 1)
    }

    $errors = Test-EnrollmentInput -Answers $answers
    if ($errors.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            [string]::Join([Environment]::NewLine, $errors),
            'Check enrollment information',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        'The batch file will contain the staging password in plain text. Continue?',
        'Sensitive information warning',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }

    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Title = 'Save enrollment batch file'
    $saveDialog.Filter = 'Batch file (*.bat)|*.bat'
    $saveDialog.FileName = 'WorkspaceOneEnrollment.bat'
    $saveDialog.DefaultExt = 'bat'
    $saveDialog.AddExtension = $true
    if ($saveDialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            $scriptContent = New-EnrollmentScript -Answers $answers
            $encoding = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($saveDialog.FileName, $scriptContent, $encoding)
            [System.Windows.Forms.MessageBox]::Show(
                "Batch file created:`n$($saveDialog.FileName)",
                'Enrollment script created',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Could not create the batch file:`n$($_.Exception.Message)",
                'Save failed',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    }
})

$form.AcceptButton = $saveButton
$form.CancelButton = $cancelButton
[void]$form.ShowDialog()
