Add-Type -AssemblyName PresentationFramework
[xml]$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Title='PerformanceSuite-Windows Anleitung' Height='600' Width='800'>
  <Grid>
    <TextBox Name='txt' Margin='10' TextWrapping='Wrap' VerticalScrollBarVisibility='Auto' IsReadOnly='True' FontFamily='Consolas' FontSize='12' />
    <Button Name='btn' Content='Schließen' Height='30' Width='80' HorizontalAlignment='Right' VerticalAlignment='Bottom' Margin='10' />
  </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$txt = $window.FindName('txt')
$btn = $window.FindName('btn')
$readmePath = "$env:ProgramData\PerformanceSuite-Windows\README.txt"
if (Test-Path $readmePath) { $txt.Text = Get-Content $readmePath -Raw } else { $txt.Text = "README nicht gefunden." }
$btn.Add_Click({ $window.Close() })
$window.ShowDialog() | Out-Null
