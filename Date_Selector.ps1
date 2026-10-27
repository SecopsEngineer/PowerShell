<#
.SYNOPSIS
Display a Windows date picker and return the selected DateTime (nothing on cancel).
.DESCRIPTION
Requires an interactive Windows desktop and an STA PowerShell session.
.EXAMPLE
$date = .\Date_Selector.ps1
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'The date picker requires Windows.' }
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { throw 'Run PowerShell with -STA to use the date picker.' }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$form = [Windows.Forms.Form]::new()
try {
    $form.StartPosition = 'CenterScreen'
    $form.ClientSize = [Drawing.Size]::new(250,230)
    $form.Text = 'Select a Date'
    $calendar = [Windows.Forms.MonthCalendar]::new()
    $calendar.MaxSelectionCount = 1
    $form.Controls.Add($calendar)
    $ok = [Windows.Forms.Button]::new()
    $ok.Location = [Drawing.Point]::new(38,190)
    $ok.Text = 'OK'
    $ok.DialogResult = 'OK'
    $form.Controls.Add($ok)
    $form.AcceptButton = $ok
    $cancel = [Windows.Forms.Button]::new()
    $cancel.Location = [Drawing.Point]::new(133,190)
    $cancel.Text = 'Cancel'
    $cancel.DialogResult = 'Cancel'
    $form.Controls.Add($cancel)
    $form.CancelButton = $cancel
    if ($form.ShowDialog() -eq 'OK') { $calendar.SelectionStart }
} finally { $form.Dispose() }
