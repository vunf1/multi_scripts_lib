import os
import platform
import subprocess
import psutil
import ctypes
import wmi
import tkinter as tk
from tkinter import messagebox
from tkinter import font
import GPUtil

def get_system_info():
    info = {}
    info['Windows Version'] = platform.win32_ver()[0]
    info['Authenticated'] = ctypes.windll.shell32.IsUserAnAdmin()
    info['Total RAM'] = f"{round(psutil.virtual_memory().total / (1024**3))} GB"
    
    # Disk information
    disk_info = []
    for disk in psutil.disk_partitions():
        if 'fixed' in disk.opts:
            usage = psutil.disk_usage(disk.mountpoint)
            disk_info.append(f"{disk.device} - {round(usage.total / (1024**3))} GB")
    info['Disks'] = disk_info

    # CPU information
    try:
        w = wmi.WMI()
        for cpu in w.Win32_Processor():
            cpu_name = cpu.Name
            cpu_cores = cpu.NumberOfCores
            cpu_threads = cpu.NumberOfLogicalProcessors
            cpu_max_speed = cpu.MaxClockSpeed
            info['CPU'] = (
                f"{cpu_name}\n"
                f" {cpu_max_speed / 1000:.2f} GHz, {cpu_cores} Core(s), \n"
                f"{cpu_threads} Logical Processor(s)".splitlines()
            )
    except Exception as e:
        info['CPU'] = f"Error fetching CPU info: {str(e)}"

    # GPU information
    try:
        gpus = GPUtil.getGPUs()
        gpu_info = []
        for gpu in gpus:
            gpu_info.append(f"{gpu.name} - {gpu.memoryTotal / 1024:.2f} GB")
        info['GPUs'] = gpu_info if gpu_info else ["No GPUs found"]
    except Exception as e:
        info['GPUs'] = [f"Error fetching GPU info: {str(e)}"]

    return info

def create_tech_folder():
    desktop_path = os.path.join(os.path.join(os.environ['USERPROFILE']), 'Desktop')
    tech_folder_path = os.path.join(desktop_path, 'tech')

    if not os.path.exists(tech_folder_path):
        os.makedirs(tech_folder_path)
        messagebox.showinfo("Info", "Folder 'tech' created on the desktop.")
    else:
        messagebox.showinfo("Info", "Folder 'tech' already exists on the desktop.")

    # Turn off real-time protection
    subprocess.run('powershell.exe Set-MpPreference -DisableRealtimeMonitoring $true', check=True)
    messagebox.showinfo("Info", "Real-time protection turned off.")

    # Add the 'tech' folder to the Windows Defender exclusion list
    subprocess.run(f'powershell.exe Add-MpPreference -ExclusionPath "{tech_folder_path}"', check=True)
    messagebox.showinfo("Info", "Folder 'tech' added to exclusion list.")

def delete_tech_folder():
    desktop_path = os.path.join(os.path.join(os.environ['USERPROFILE']), 'Desktop')
    tech_folder_path = os.path.join(desktop_path, 'tech')

    if os.path.exists(tech_folder_path):
        os.rmdir(tech_folder_path)
        messagebox.showinfo("Info", "Folder 'tech' deleted from the desktop.")
    else:
        messagebox.showinfo("Info", "Folder 'tech' does not exist on the desktop.")

    # Turn on real-time protection
    subprocess.run('powershell.exe Set-MpPreference -DisableRealtimeMonitoring $false', check=True)
    messagebox.showinfo("Info", "Real-time protection turned on.")

def display_system_info(info, text_widget):
    text_widget.delete('1.0', tk.END)
    text_widget.tag_configure('center', justify='center')
    text_widget.tag_configure('bold', font=('Courier', 10, 'bold'))
    text_widget.tag_configure('info', font=('Courier', 10))

    text_widget.insert(tk.END, "System Information\n", 'bold center')
    text_widget.insert(tk.END, "===============================\n", 'center')
    for key, value in info.items():
        if isinstance(value, list):
            text_widget.insert(tk.END, f"{key}:\n", 'bold center')
            for item in value:
                text_widget.insert(tk.END, f"  - {item}\n", 'info center')
        else:
            text_widget.insert(tk.END, f"{key}: {value}\n", 'info center')
    text_widget.insert(tk.END, "===============================\n", 'center')

def main():
    # Ensure the script is run with administrative privileges
    if not ctypes.windll.shell32.IsUserAnAdmin():
        messagebox.showerror("Error", "This script requires administrative privileges. Please run it as an administrator.")
        return

    system_info = get_system_info()

    # Create main window
    root = tk.Tk()
    root.title("Tech Folder Management")

    # Monospace font for table-like display
    text_font = font.Font(family='Courier', size=10)

    # System Info Text Box
    text_widget = tk.Text(root, height=20, width=80, font=text_font, bg='black', fg='white')
    text_widget.pack(padx=10, pady=10)
    display_system_info(system_info, text_widget)

    # Buttons
    btn_create = tk.Button(root, text="Create 'tech' folder and disable real-time protection", command=create_tech_folder, bg='green', fg='white')
    btn_create.pack(padx=10, pady=5)

    btn_delete = tk.Button(root, text="Delete 'tech' folder and enable real-time protection", command=delete_tech_folder, bg='red', fg='white')
    btn_delete.pack(padx=10, pady=5)

    btn_exit = tk.Button(root, text="Exit", command=root.quit, bg='gray', fg='white')
    btn_exit.pack(padx=10, pady=5)

    root.mainloop()

if __name__ == "__main__":
    main()
