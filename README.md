# THREEsize (TreeSize PowerShell Utility)

**THREEsize** is a fast, modern Windows desktop disk space analyzer and directory size visualizer built with **PowerShell**, **WPF (XAML)**, and embedded multithreaded **C# (`FastScannerV2`)**. 

It provides a dark-mode TreeSize-like graphical user interface to scan directories, inspect folder hierarchy disk usage, visualize relative storage distribution with progress bars, and quickly manage heavy files directly from the app.

---

## 🌟 Key Features

* **⚡ Ultra-Fast Multi-threaded Scanning**: Uses embedded C# (`FastScannerV2`) utilizing `DirectoryInfo.EnumerateFiles()` and `DirectoryInfo.EnumerateDirectories()` to rapidly scan large disk structures while safely skipping junction points/reparse points.
* **🎨 Modern Dark Mode UI**: Clean, responsive WPF user interface with blue accent highlights, custom window icons, and custom grid splitting for resizable navigation panes.
* **🌳 Interactive Folder Hierarchy**: Navigable TreeView layout displaying total subfolder sizes, item counts (folders & files), formatted in human-readable units (B, KB, MB, GB, TB).
* **📊 Visual Relative Storage Distribution**: Detailed ListView side-panel showing individual files and subdirectories with custom progress bars representing their percentage contribution to the parent folder.
* **🖱️ Explorer & File Operations**: Context menu actions to:
  * Open items directly in **Windows Explorer**.
  * View native Windows **Properties** dialog.
  * **Delete** unwanted large files or directories directly with confirmation prompts.
* **💻 Asynchronous UI**: Runs scans inside a separate background PowerShell Runspace so the interface remains smooth and responsive during long scans.

---

## 📋 Prerequisites & Requirements

* **Operating System**: Windows 10 / 11 or Windows Server (with Desktop Experience)
* **PowerShell**: Windows PowerShell 5.1 (or PowerShell 7+)
* **.NET Framework**: Built-in .NET Framework WPF libraries (`PresentationFramework`, `System.Xaml`, `WindowsBase`, `System.Windows.Forms`).

---

## 🚀 How to Run

1. Download or clone this repository to your local computer.
2. Open **PowerShell** (run as Administrator if scanning system folders like `C:\Program Files` or `C:\Windows`).
3. Navigate to the folder containing `THREEsize.ps1`:
   ```powershell
   cd "C:\Path\To\ThreeSize"
   ```
4. Run the script:
   ```powershell
   .\THREEsize.ps1
   ```

*Note: If PowerShell scripts are restricted on your execution policy, temporarily enable script execution for the current process:*
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\THREEsize.ps1
```

---

## 🛠️ How It Works

### 1. Embedded C# FastScanner V2 Engine
When `THREEsize.ps1` is launched, it dynamically compiles an optimized C# class `FastScannerV2` into memory using `Add-Type`. 

```
[PowerShell Script UI] ──(Asynchronous Runspace)──> [FastScannerV2 C# Engine]
                                                             │
                                                   Direct I/O Enumeration
                                                             │
                                                    [FolderNodeV2 Tree]
```

* **Data Structure**: Represents folders (`FolderNodeV2`) and files (`FileNodeV2`) with recursive properties for combined size, file counts, and subfolder lists.
* **Performance**: Skips junction points (`FileAttributes.ReparsePoint`) to avoid infinite loops and permission traps.
* **Sorting**: Automatically sorts child folders by total byte size descending so the largest consumers appear at the top.

### 2. WPF / XAML Presentation Layer
* **Tree View**: Dynamically populates nested folder nodes on demand with expand/collapse callbacks.
* **Detail Panel**: Renders items inside the selected directory, dynamically computing `(ItemSize / ParentSize) * 100` to display visual relative usage bars.
* **Shell Integration**: P/Invoke calls to `Shell32.dll` (`SHObjectProperties`) allow viewing native Windows file properties.

---

## 📄 License

This utility is free and open-source software provided under the [MIT License](LICENSE).
