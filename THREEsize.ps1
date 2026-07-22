# Ensure required Assemblies are loaded
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml, System.Windows.Forms

# Compiled C# FastScanner V2 classes for thread-safe scanning and root mapping
if (-not ("FastScannerV2" -as [type])) {
    $source = @'
    using System;
    using System.IO;
    using System.Collections.Generic;
    using System.Collections.Concurrent;

    public class FileNodeV2 {
        public string Name { get; set; }
        public string Path { get; set; }
        public long Size { get; set; }
        public string Type { get; set; }
    }

    public class FolderNodeV2 {
        public string Name { get; set; }
        public string Path { get; set; }
        public long Size { get; set; }
        public long FilesSize { get; set; }
        public int FilesCount { get; set; }
        public int FoldersCount { get; set; }
        public List<FolderNodeV2> SubFolders { get; set; }
        public List<FileNodeV2> Files { get; set; }

        public FolderNodeV2() {
            SubFolders = new List<FolderNodeV2>();
            Files = new List<FileNodeV2>();
        }

        public FolderNodeV2[] GetSubFoldersSafe() {
            lock (SubFolders) {
                return SubFolders.ToArray();
            }
        }

        public FileNodeV2[] GetFilesSafe() {
            lock (Files) {
                return Files.ToArray();
            }
        }
    }

    public class FastScannerV2 {
        public static FolderNodeV2 RootNode;

        public static FolderNodeV2 Scan(string path, string parentPath = null) {
            var node = new FolderNodeV2 {
                Path = path,
                Name = System.IO.Path.GetFileName(path)
            };
            if (string.IsNullOrEmpty(node.Name)) {
                node.Name = path;
            }

            if (parentPath == null) {
                RootNode = node;
            }

            try {
                var dirInfo = new DirectoryInfo(path);
                
                // Enumerate Files
                foreach (var file in dirInfo.EnumerateFiles()) {
                    node.FilesSize += file.Length;
                    node.FilesCount++;
                    lock (node.Files) {
                        node.Files.Add(new FileNodeV2 {
                            Name = file.Name,
                            Path = file.FullName,
                            Size = file.Length,
                            Type = file.Extension
                        });
                    }
                }
                node.Size += node.FilesSize;

                // Enumerate Directories
                foreach (var subDir in dirInfo.EnumerateDirectories()) {
                    if ((subDir.Attributes & FileAttributes.ReparsePoint) == FileAttributes.ReparsePoint) {
                        continue;
                    }
                    
                    var subNode = Scan(subDir.FullName, path);
                    lock (node.SubFolders) {
                        node.SubFolders.Add(subNode);
                    }
                    node.Size += subNode.Size;
                    node.FoldersCount += 1 + subNode.FoldersCount;
                    node.FilesCount += subNode.FilesCount;
                }

                // Sort subfolders by size descending
                lock (node.SubFolders) {
                    node.SubFolders.Sort((a, b) => b.Size.CompareTo(a.Size));
                }
            }
            catch (UnauthorizedAccessException) {}
            catch (Exception) {}

            return node;
        }
    }
'@
    Add-Type -TypeDefinition $source
}

# XAML for the Modern Dark-Mode GUI
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="THREEsize" Height="700" Width="1100"
        Background="#181818" Foreground="#E1E1E1" FontSize="13"
        WindowStartupLocation="CenterScreen" SnapsToDevicePixels="True">
    
    <Window.Resources>
        <!-- Color Palette -->
        <SolidColorBrush x:Key="BgDark" Color="#181818"/>
        <SolidColorBrush x:Key="BgMedium" Color="#222222"/>
        <SolidColorBrush x:Key="BgLight" Color="#2D2D2D"/>
        <SolidColorBrush x:Key="AccentBlue" Color="#007ACC"/>
        <SolidColorBrush x:Key="AccentBlueHover" Color="#0098FF"/>
        <SolidColorBrush x:Key="TextLight" Color="#E1E1E1"/>
        <SolidColorBrush x:Key="TextMuted" Color="#858585"/>
        <SolidColorBrush x:Key="BorderColor" Color="#333333"/>
        
        <!-- Button Style -->
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2D2D2D"/>
            <Setter Property="Foreground" Value="#E1E1E1"/>
            <Setter Property="BorderBrush" Value="#333333"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Resources>
                <Style TargetType="Border">
                    <Setter Property="CornerRadius" Value="4"/>
                </Style>
            </Style.Resources>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#3D3D3D"/>
                    <Setter Property="BorderBrush" Value="#007ACC"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Foreground" Value="#666666"/>
                    <Setter Property="Background" Value="#202020"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- TextBox Style -->
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#222222"/>
            <Setter Property="Foreground" Value="#E1E1E1"/>
            <Setter Property="BorderBrush" Value="#333333"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="6"/>
            <Setter Property="CaretBrush" Value="#E1E1E1"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Style.Resources>
                <Style TargetType="Border">
                    <Setter Property="CornerRadius" Value="4"/>
                </Style>
            </Style.Resources>
            <Style.Triggers>
                <Trigger Property="IsFocused" Value="True">
                    <Setter Property="BorderBrush" Value="#007ACC"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- TreeView & ListView common styling -->
        <Style TargetType="TreeView">
            <Setter Property="Background" Value="#222222"/>
            <Setter Property="Foreground" Value="#E1E1E1"/>
            <Setter Property="BorderBrush" Value="#333333"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style TargetType="TreeViewItem">
            <Setter Property="Foreground" Value="#E1E1E1"/>
            <Style.Resources>
                <SolidColorBrush x:Key="{x:Static SystemColors.HighlightBrushKey}" Color="#007ACC"/>
                <SolidColorBrush x:Key="{x:Static SystemColors.InactiveSelectionHighlightBrushKey}" Color="#2D2D2D"/>
            </Style.Resources>
        </Style>

        <!-- ListView Header Styling -->
        <Style TargetType="GridViewColumnHeader">
            <Setter Property="Background" Value="#2D2D2D"/>
            <Setter Property="Foreground" Value="#E1E1E1"/>
            <Setter Property="BorderBrush" Value="#333333"/>
            <Setter Property="BorderThickness" Value="0,0,1,1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
        </Style>

        <!-- ListView Item Styling -->
        <Style TargetType="ListView">
            <Setter Property="Background" Value="#222222"/>
            <Setter Property="Foreground" Value="#E1E1E1"/>
            <Setter Property="BorderBrush" Value="#333333"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style TargetType="ListViewItem">
            <Setter Property="Foreground" Value="#E1E1E1"/>
            <Setter Property="Height" Value="28"/>
            <Style.Resources>
                <SolidColorBrush x:Key="{x:Static SystemColors.HighlightBrushKey}" Color="#007ACC"/>
                <SolidColorBrush x:Key="{x:Static SystemColors.InactiveSelectionHighlightBrushKey}" Color="#2D2D2D"/>
            </Style.Resources>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- Header / Toolbar -->
            <RowDefinition Height="*"/>    <!-- Main content split -->
            <RowDefinition Height="Auto"/> <!-- Status bar -->
        </Grid.RowDefinitions>

        <!-- Top Navigation / Search bar -->
        <Border Grid.Row="0" Background="#222222" Padding="12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Text="Target Folder:" VerticalAlignment="Center" Foreground="#E1E1E1" Margin="0,0,8,0" FontSize="14" FontWeight="SemiBold"/>
                <TextBox x:Name="TxtPath" Grid.Column="1" Height="32" FontSize="13"/>
                <Button x:Name="BtnBrowse" Grid.Column="2" Content="Browse..." Height="32" Margin="8,0,0,0"/>
                <Button x:Name="BtnScan" Grid.Column="3" Content="Scan" Background="#007ACC" Foreground="White" BorderBrush="#007ACC" Height="32" Width="80" FontWeight="Bold" Margin="8,0,0,0"/>
            </Grid>
        </Border>

        <!-- Main Body -->
        <Grid Grid.Row="1" Margin="12,4,12,12">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="3*" MinWidth="250"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="5*" MinWidth="400"/>
            </Grid.ColumnDefinitions>

            <!-- Tree View Structure -->
            <TreeView x:Name="FolderTree" Grid.Column="0"/>

            <!-- Resizable GridSplitter -->
            <GridSplitter Grid.Column="1" Width="6" HorizontalAlignment="Center" VerticalAlignment="Stretch" Background="#181818"/>

            <!-- List View Details -->
            <ListView x:Name="DetailList" Grid.Column="2" Margin="6,0,0,0" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                <ListView.ContextMenu>
                    <ContextMenu Background="#2D2D2D" Foreground="#E1E1E1" BorderBrush="#333333">
                        <MenuItem x:Name="MenuOpen" Header="Open in Explorer" Icon="&#x1F4C2;"/>
                        <MenuItem x:Name="MenuProperties" Header="Properties" Icon="&#x1F4C4;"/>
                        <Separator Background="#333333"/>
                        <MenuItem x:Name="MenuDelete" Header="Delete" Icon="&#x274C;"/>
                    </ContextMenu>
                </ListView.ContextMenu>
                <ListView.View>
                    <GridView>
                        <GridViewColumn Header="Name" Width="240">
                            <GridViewColumn.CellTemplate>
                                <DataTemplate>
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <TextBlock Text="{Binding Icon}" Margin="0,0,6,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="{Binding Name}" TextTrimming="CharacterEllipsis" Width="200" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </DataTemplate>
                            </GridViewColumn.CellTemplate>
                        </GridViewColumn>
                        <GridViewColumn Header="Size" Width="100">
                            <GridViewColumn.CellTemplate>
                                <DataTemplate>
                                    <TextBlock Text="{Binding FormattedSize}" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                                </DataTemplate>
                            </GridViewColumn.CellTemplate>
                        </GridViewColumn>
                        <GridViewColumn Header="Type" Width="80">
                            <GridViewColumn.CellTemplate>
                                <DataTemplate>
                                    <TextBlock Text="{Binding Type}" VerticalAlignment="Center" Foreground="#858585"/>
                                </DataTemplate>
                            </GridViewColumn.CellTemplate>
                        </GridViewColumn>
                        <GridViewColumn Header="Relative Size" Width="160">
                            <GridViewColumn.CellTemplate>
                                <DataTemplate>
                                    <Grid Width="140" Height="16">
                                        <ProgressBar Value="{Binding Percentage}" Minimum="0" Maximum="100" Background="#2D2D2D" Foreground="#007ACC" BorderThickness="0"/>
                                        <TextBlock Text="{Binding FormattedPercentage}" HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="White" FontSize="10" FontWeight="Bold"/>
                                    </Grid>
                                </DataTemplate>
                            </GridViewColumn.CellTemplate>
                        </GridViewColumn>
                        <GridViewColumn Header="Path" Width="300">
                            <GridViewColumn.CellTemplate>
                                <DataTemplate>
                                    <TextBlock Text="{Binding Path}" TextTrimming="CharacterEllipsis" Foreground="#858585" VerticalAlignment="Center"/>
                                </DataTemplate>
                            </GridViewColumn.CellTemplate>
                        </GridViewColumn>
                    </GridView>
                </ListView.View>
            </ListView>
        </Grid>

        <!-- Footer / Status Bar -->
        <StatusBar Grid.Row="2" Background="#222222" BorderBrush="#333333" BorderThickness="0,1,0,0" Padding="8,4">
            <StatusBarItem>
                <TextBlock x:Name="StatusText" Text="Ready" Foreground="#858585"/>
            </StatusBarItem>
            <StatusBarItem HorizontalAlignment="Right">
                <ProgressBar x:Name="ScanProgress" IsIndeterminate="True" Width="120" Height="8" Visibility="Collapsed" Background="#2D2D2D" Foreground="#007ACC" BorderThickness="0"/>
            </StatusBarItem>
        </StatusBar>
    </Grid>
</Window>
'@

# Read XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml.OuterXml))
$Window = [System.Windows.Markup.XamlReader]::Load($reader)

# Apply dynamic custom window icon "3" inside a blue circle
try {
    $drawingVisual = New-Object System.Windows.Media.DrawingVisual
    $drawingContext = $drawingVisual.RenderOpen()
    
    # Draw Background circle
    $blueBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(0, 122, 204)) # AccentBlue
    $drawingContext.DrawEllipse($blueBrush, $null, [System.Windows.Point]::new(16, 16), 16, 16)
    
    # Draw number "3" text
    $typeface = New-Object System.Windows.Media.Typeface("Segoe UI Black")
    $formattedText = New-Object System.Windows.Media.FormattedText(
        "3",
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Windows.FlowDirection]::LeftToRight,
        $typeface,
        22,
        [System.Windows.Media.Brushes]::White
    )
    $drawingContext.DrawText($formattedText, [System.Windows.Point]::new(10, 2))
    $drawingContext.Close()
    
    # Set Window Icon
    $drawingImage = New-Object System.Windows.Media.DrawingImage($drawingVisual.Drawing)
    $Window.Icon = $drawingImage
}
catch {}

# Get controls by Name
$TxtPath       = $Window.FindName("TxtPath")
$BtnBrowse     = $Window.FindName("BtnBrowse")
$BtnScan       = $Window.FindName("BtnScan")
$FolderTree    = $Window.FindName("FolderTree")
$DetailList    = $Window.FindName("DetailList")
$StatusText    = $Window.FindName("StatusText")
$ScanProgress  = $Window.FindName("ScanProgress")
$MenuOpen      = $Window.FindName("MenuOpen")
$MenuProperties = $Window.FindName("MenuProperties")
$MenuDelete    = $Window.FindName("MenuDelete")

# Set Default path to User Profile folder
$TxtPath.Text = $Home

# Size Formatter helper
function Format-Size {
    param ([long]$Bytes)
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "{0} B" -f $Bytes
}

# The background runspace script block
$ScanScript = {
    param ($RootPath)
    [FastScannerV2]::RootNode = $null
    [FastScannerV2]::Scan($RootPath)
}

# Add TreeViewItem Helper
function New-TreeItem {
    param (
        $DataNode
    )
    $tvi = New-Object System.Windows.Controls.TreeViewItem
    $tvi.Tag = $DataNode
    
    # Custom Header layout (Folder Icon, Name, Size)
    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $stack.Margin = "2"
    
    $icon = New-Object System.Windows.Controls.TextBlock
    $icon.Text = "$([char]::ConvertFromUtf32(0x1F4C1)) "
    $icon.Foreground = [System.Windows.Media.Brushes]::Orange
    
    $nameText = New-Object System.Windows.Controls.TextBlock
    $nameText.Text = $DataNode.Name
    $nameText.FontWeight = [System.Windows.FontWeights]::SemiBold
    
    $sizeText = New-Object System.Windows.Controls.TextBlock
    $sizeText.Text = " (Calculating...)"
    $sizeText.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(133, 133, 133)) # TextMuted
    
    $stack.Children.Add($icon) | Out-Null
    $stack.Children.Add($nameText) | Out-Null
    $stack.Children.Add($sizeText) | Out-Null
    
    $tvi.Header = $stack
    
    $tvi.Items.Add($null) | Out-Null
    
    return $tvi
}

# Update Size on TreeViewItem header
function Update-TreeItemHeader {
    param (
        $TreeViewItem,
        $DataNode
    )
    $stack = $TreeViewItem.Header
    if ($stack -ne $null -and $stack.Children.Count -ge 3) {
        $sizeText = $stack.Children[2]
        $formatted = Format-Size $DataNode.Size
        if ($sizeText.Text -ne " ($formatted)") {
            $sizeText.Text = " ($formatted)"
        }
    }
}

# Expand TreeViewItem Event (Lazy Loading)
$FolderTree.AddHandler([System.Windows.Controls.TreeViewItem]::ExpandedEvent, [System.Windows.RoutedEventHandler]{
    param($sender, $e)
    $tvi = $e.OriginalSource
    if ($tvi.Items.Count -eq 1 -and $tvi.Items[0] -eq $null) {
        $tvi.Items.Clear()
        $data = $tvi.Tag
        if ($data -ne $null) {
            $subFolders = $data.GetSubFoldersSafe()
            foreach ($sub in $subFolders) {
                $childTvi = New-TreeItem -DataNode $sub
                $tvi.Items.Add($childTvi) | Out-Null
            }
        }
    }
})

# Show details in ListView when TreeView selection changes
$FolderTree.add_SelectedItemChanged({
    param($sender, $e)
    $tvi = $e.NewValue
    if ($tvi -ne $null) {
        $data = $tvi.Tag
        Show-FolderDetails -DataNode $data
    }
})

# Display files & folders under selected folder in the ListView
function Show-FolderDetails {
    param ($DataNode)
    $DetailList.Items.Clear()
    if ($DataNode -eq $null) { return }

    $totalSize = [double]$DataNode.Size
    if ($totalSize -eq 0) { $totalSize = 1 }

    # Collect subfolders (thread-safe copy)
    $subfolders = $DataNode.GetSubFoldersSafe()
    foreach ($sub in $subfolders) {
        $pct = ($sub.Size / $totalSize) * 100
        $item = [PSCustomObject]@{
            Icon = [char]::ConvertFromUtf32(0x1F4C1)
            Name = $sub.Name
            Size = $sub.Size
            FormattedSize = Format-Size $sub.Size
            Type = "Folder"
            Percentage = $pct
            FormattedPercentage = "{0:F1}%" -f $pct
            Path = $sub.Path
            Tag = $sub
            IsFolder = $true
        }
        $DetailList.Items.Add($item) | Out-Null
    }

    # Collect files (thread-safe copy)
    $files = $DataNode.GetFilesSafe()
    foreach ($file in $files) {
        $pct = ($file.Size / $totalSize) * 100
        $item = [PSCustomObject]@{
            Icon = [char]::ConvertFromUtf32(0x1F4C4)
            Name = $file.Name
            Size = $file.Size
            FormattedSize = Format-Size $file.Size
            Type = $file.Type
            Percentage = $pct
            FormattedPercentage = "{0:F1}%" -f $pct
            Path = $file.Path
            Tag = $file
            IsFolder = $false
        }
        $DetailList.Items.Add($item) | Out-Null
    }
}

# Recursively update only the expanded items in the TreeView
function Update-TreeViewItemRecursive {
    param ($Tvi)
    if ($Tvi -eq $null) { return }

    $data = $Tvi.Tag
    if ($data -ne $null) {
        # 1. Update size header
        Update-TreeItemHeader -TreeViewItem $Tvi -DataNode $data

        # Only check/expand subfolders if the TreeViewItem is currently expanded
        if ($Tvi.IsExpanded) {
            $subFolders = $data.GetSubFoldersSafe()
            
            if ($Tvi.Items.Count -eq 1 -and $Tvi.Items[0] -eq $null) {
                $Tvi.Items.Clear()
            }

            # Map existing children paths
            $existingPaths = @{}
            foreach ($child in $Tvi.Items) {
                if ($child -ne $null -and $child.Tag -ne $null) {
                    $existingPaths[$child.Tag.Path] = $true
                }
            }

            # Add newly discovered subfolders
            foreach ($sub in $subFolders) {
                if (-not $existingPaths.ContainsKey($sub.Path)) {
                    $childTvi = New-TreeItem -DataNode $sub
                    $Tvi.Items.Add($childTvi) | Out-Null
                }
            }

            # 3. Recursively update children
            foreach ($child in $Tvi.Items) {
                if ($child -ne $null) {
                    Update-TreeViewItemRecursive -Tvi $child
                }
            }
        }
    }
}

# Helper to reset Scan Button style
function Set-ScanButtonState {
    param (
        [string]$Mode # "Scan" or "Stop"
    )
    $bc = New-Object System.Windows.Media.BrushConverter
    if ($Mode -eq "Stop") {
        $BtnScan.Content = "Stop"
        $BtnScan.Background = $bc.ConvertFromString("#D23F3F")
        $BtnScan.BorderBrush = $bc.ConvertFromString("#D23F3F")
    } else {
        $BtnScan.Content = "Scan"
        $BtnScan.Background = $bc.ConvertFromString("#007ACC")
        $BtnScan.BorderBrush = $bc.ConvertFromString("#007ACC")
    }
}

# Start directory scan
function Start-Scan {
    # If currently scanning, the button acts as a Stop button
    if ($BtnScan.Content -eq "Stop") {
        if ($Global:CurrentBackgroundPowerShell -ne $null) {
            try {
                $Global:CurrentBackgroundPowerShell.Stop()
            }
            catch {}
        }
        $StatusText.Text = "Interrupting scan..."
        return
    }

    $path = $TxtPath.Text
    if (-not (Test-Path -Path $path -PathType Container)) {
        [System.Windows.MessageBox]::Show("Please enter a valid directory path.", "Invalid Path", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return
    }
    $script:ScanRootPath = $path

    # Disable other navigation inputs, change Scan button to Stop button
    Set-ScanButtonState -Mode "Stop"
    $BtnBrowse.IsEnabled = $false
    $TxtPath.IsEnabled = $false
    $ScanProgress.Visibility = [System.Windows.Visibility]::Visible
    $StatusText.Text = "Initializing scan..."
    
    $FolderTree.Items.Clear()
    $DetailList.Items.Clear()

    # Pre-create root placeholder
    $script:RootNode = [FolderNodeV2]::new()
    $script:RootNode.Path = $path
    $script:RootNode.Name = [System.IO.Path]::GetFileName($path)
    if ([string]::IsNullOrEmpty($script:RootNode.Name)) { $script:RootNode.Name = $path }

    $rootTvi = New-TreeItem -DataNode $script:RootNode
    $FolderTree.Items.Add($rootTvi) | Out-Null
    $rootTvi.IsExpanded = $true

    # Create background PowerShell instance
    $Global:CurrentBackgroundPowerShell = [PowerShell]::Create()
    $Global:CurrentBackgroundPowerShell.AddScript($ScanScript).AddArgument($path) | Out-Null

    # Begin execution
    $script:CurrentAsyncResult = $Global:CurrentBackgroundPowerShell.BeginInvoke()

    # Set up polling timer to update UI at regular intervals
    $script:ScanTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:ScanTimer.Interval = [TimeSpan]::FromMilliseconds(200)
    $script:ScanTimer.Add_Tick({
        # 0. Check if background root has been initialized in C# memory, swap if so
        if ($FolderTree.Items.Count -gt 0 -and $FolderTree.Items[0].Tag -eq $script:RootNode) {
            if ([FastScannerV2]::RootNode -ne $null) {
                $FolderTree.Items[0].Tag = [FastScannerV2]::RootNode
            }
        }

        # 1. Update expanded TreeView Items from the root
        if ($FolderTree.Items.Count -gt 0) {
            Update-TreeViewItemRecursive -Tvi $FolderTree.Items[0]
        }

        # 2. Update ListView details for selected item
        $selectedTvi = $FolderTree.SelectedItem
        if ($selectedTvi -ne $null) {
            Show-FolderDetails -DataNode $selectedTvi.Tag
        }

        # 3. Check if background job finished or interrupted
        if ($script:CurrentAsyncResult.IsCompleted) {
            $script:ScanTimer.Stop()
            
            try {
                $results = $Global:CurrentBackgroundPowerShell.EndInvoke($script:CurrentAsyncResult)
                $finalRoot = $results[0]
                
                if ($finalRoot -ne $null) {
                    $FolderTree.Items[0].Tag = $finalRoot
                    Update-TreeViewItemRecursive -Tvi $FolderTree.Items[0]

                    # Trigger final listview update
                    $selectedTvi = $FolderTree.SelectedItem
                    if ($selectedTvi -ne $null) {
                        Show-FolderDetails -DataNode $selectedTvi.Tag
                    }

                    $totFolders = $finalRoot.FoldersCount
                    $totFiles = $finalRoot.FilesCount
                    $totSize = Format-Size $finalRoot.Size
                    $StatusText.Text = "Scan Complete: $totFolders Folders, $totFiles Files ($totSize)"
                } else {
                    # If stopped or returned nothing
                    if ($FolderTree.Items.Count -gt 0) {
                        $currentRoot = $FolderTree.Items[0].Tag
                        $StatusText.Text = "Scan Interrupted: (Partial results shown)"
                    } else {
                        $StatusText.Text = "Scan finished with no results."
                    }
                }
            }
            catch {
                $StatusText.Text = "Scan halted."
            }
            finally {
                $Global:CurrentBackgroundPowerShell.Dispose()
                $Global:CurrentBackgroundPowerShell = $null
                
                # Restore UI state
                Set-ScanButtonState -Mode "Scan"
                $BtnBrowse.IsEnabled = $true
                $TxtPath.IsEnabled = $true
                $ScanProgress.Visibility = [System.Windows.Visibility]::Collapsed
            }
        }
    })
    $script:ScanTimer.Start()
}

$BtnScan.Add_Click({
    Start-Scan
})

# Enter key on path textbox starts scan
$TxtPath.Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        Start-Scan
    }
})

# Browse Button Click Handler
$BtnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.SelectedPath = $TxtPath.Text
    $dialog.Description = "Select target folder to scan"
    
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TxtPath.Text = $dialog.SelectedPath
        Start-Scan
    }
})

# Helper to open items in Explorer
function Open-ItemInExplorer {
    $selected = $DetailList.SelectedItem
    if ($selected -ne $null) {
        try {
            if ($selected.IsFolder) {
                Start-Process explorer.exe -ArgumentList $selected.Path
            } else {
                # Select file in Explorer
                Start-Process explorer.exe -ArgumentList "/select,`"$($selected.Path)`""
            }
        }
        catch {
            [System.Windows.MessageBox]::Show("Could not open path: $($_.Exception.Message)", "Error")
        }
    }
}

# Double click in DetailList opens in Explorer
$DetailList.Add_MouseDoubleClick({
    param($sender, $e)
    Open-ItemInExplorer
})

# Context Menu handlers
$MenuOpen.Add_Click({
    Open-ItemInExplorer
})

$MenuProperties.Add_Click({
    $selected = $DetailList.SelectedItem
    if ($selected -ne $null) {
        try {
            $shell = New-Object -ComObject Shell.Application
            $folder = $shell.NameSpace([System.IO.Path]::GetDirectoryName($selected.Path))
            $item = $folder.ParseName([System.IO.Path]::GetFileName($selected.Path))
            $item.InvokeVerb("Properties")
        }
        catch {
            # Fallback using shell command
            Start-Process -FilePath $selected.Path -Verb properties -ErrorAction SilentlyContinue
        }
    }
})

$MenuDelete.Add_Click({
    $selected = $DetailList.SelectedItem
    if ($selected -ne $null) {
        $confirm = [System.Windows.MessageBox]::Show("Are you sure you want to delete '$($selected.Name)'? This action cannot be undone.", "Confirm Delete", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
            try {
                if ($selected.IsFolder) {
                    [System.IO.Directory]::Delete($selected.Path, $true)
                } else {
                    [System.IO.File]::Delete($selected.Path)
                }
                # Remove from ListView
                $DetailList.Items.Remove($selected)
                $StatusText.Text = "Deleted '$($selected.Name)' successfully."
            }
            catch {
                [System.Windows.MessageBox]::Show("Could not delete item: $($_.Exception.Message)", "Delete Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        }
    }
})

# Show the GUI Window
$Window.ShowDialog() | Out-Null
