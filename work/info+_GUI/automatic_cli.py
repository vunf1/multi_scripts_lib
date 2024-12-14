import os
import platform
import subprocess
import psutil
import ctypes
import wmi

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
    info['CPU'] = platform.processor()
    info['CPU Cores'] = psutil.cpu_count(logical=False)
    info['CPU Threads'] = psutil.cpu_count(logical=True)
    info['CPU Frequency'] = f"{psutil.cpu_freq().max:.2f} MHz"
    
    # GPU information
    try:
        wmi_obj = wmi.WMI()
        gpu_info = []
        for gpu in wmi_obj.Win32_VideoController():
            gpu_info.append(f"{gpu.Name} - {gpu.AdapterRAM / (1024**3):.2f} GB")
        info['GPUs'] = gpu_info
    except:
        info['GPUs'] = ["Unable to fetch GPU info"]

    return info

def display_system_info(info):
    print("\n===============================")
    print("       System Information")
    print("===============================")
    for key, value in info.items():
        if isinstance(value, list):
            print(f"{key}:")
            for item in value:
                print(f"  - {item}")
        else:
            print(f"{key}: {value}")
    print("===============================\n")

def create_tech_folder():
    desktop_path = os.path.join(os.path.join(os.environ['USERPROFILE']), 'Desktop')
    tech_folder_path = os.path.join(desktop_path, 'tech')

    if not os.path.exists(tech_folder_path):
        os.makedirs(tech_folder_path)
        print(f"Folder 'tech' created on the desktop.")
    else:
        print(f"Folder 'tech' already exists on the desktop.")

    # Turn off real-time protection
    subprocess.run('powershell.exe Set-MpPreference -DisableRealtimeMonitoring $true', check=True)
    print("Real-time protection turned off.")

    # Add the 'tech' folder to the Windows Defender exclusion list
    subprocess.run(f'powershell.exe Add-MpPreference -ExclusionPath "{tech_folder_path}"', check=True)
    print("Folder 'tech' added to exclusion list.")

def delete_tech_folder():
    desktop_path = os.path.join(os.path.join(os.environ['USERPROFILE']), 'Desktop')
    tech_folder_path = os.path.join(desktop_path, 'tech')

    if os.path.exists(tech_folder_path):
        os.rmdir(tech_folder_path)
        print(f"Folder 'tech' deleted from the desktop.")
    else:
        print(f"Folder 'tech' does not exist on the desktop.")

    # Turn on real-time protection
    subprocess.run('powershell.exe Set-MpPreference -DisableRealtimeMonitoring $false', check=True)
    print("Real-time protection turned on.")

def menu():
    system_info = get_system_info()
    while True:
        display_system_info(system_info)
        print("1: Create 'tech' folder, disable real-time protection, and add folder to exclusions")
        print("2: Delete 'tech' folder, enable real-time protection")
        print("3: Exit")
        print("===============================")

        choice = input("Enter your choice: ")

        if choice == '1':
            create_tech_folder()
        elif choice == '2':
            delete_tech_folder()
        elif choice == '3':
            print("Exiting program.")
            break
        else:
            print("Invalid choice, please select 1, 2, or 3.")

if __name__ == "__main__":
    # Ensure the script is run with administrative privileges
    if ctypes.windll.shell32.IsUserAnAdmin():
        menu()
    else:
        print("This script requires administrative privileges. Please run it as an administrator.")
