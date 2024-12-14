import os
import platform
import subprocess
import psutil
import ctypes
import wmi
import sys
from PyQt5 import QtWidgets, QtGui, QtCore
import shutil
import GPUtil
import win32com.client

# Function to check for open files in a directory and return the process names
def get_open_files_in_directory(directory):
    open_files_processes = []
    for proc in psutil.process_iter(['pid', 'name', 'open_files']):
        try:
            open_files = proc.info['open_files']
            if open_files:
                for file in open_files:
                    if file.path.startswith(directory):
                        open_files_processes.append(proc.info['name'])
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue
    return open_files_processes

# Slow method to fetch windows action status using powershell
def get_windows_activation_status10():
    try:
        script = (
            "(Get-WmiObject -Query 'select * from SoftwareLicensingProduct where PartialProductKey is not null and LicenseStatus=1').LicenseStatus"
        )
        output = subprocess.check_output(['powershell', '-Command', script], text=True, creationflags=subprocess.CREATE_NO_WINDOW)
        if "1" in output.strip():
            return "Activated"
        else:
            return "Not Activated"
    except Exception as e:
        return f"Error: {str(e)}"

# 3/4s method
def get_windows_activation_status():
    try:
        wmi = win32com.client.Dispatch("WbemScripting.SWbemLocator")
        conn = wmi.ConnectServer(".", "root\\cimv2")
        query = "SELECT LicenseStatus FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL AND LicenseStatus=1"
        products = conn.ExecQuery(query)
        for product in products:
            if product.LicenseStatus == 1:
                return "Activated"
        return "Not Activated"
    except Exception as e:
        return f"Error: {str(e)}"

# Using subprocess 4/5s
def get_windows_activation_status66():
    try:
        result = subprocess.check_output(
            'wmic path SoftwareLicensingProduct where "PartialProductKey is not null and LicenseStatus=1" get LicenseStatus',
            shell=True,
            text=True,
            creationflags=subprocess.CREATE_NO_WINDOW
        )
        if "1" in result:
            return "Activated"
        else:
            return "Not Activated"
    except subprocess.CalledProcessError as e:
        return f"Error: {str(e)}"

# 4/5s method
def get_windows_activation_status55():
    try:
        c = wmi.WMI()
        products = c.query("SELECT LicenseStatus FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL AND LicenseStatus=1")
        for product in products:
            if product.LicenseStatus == 1:
                return "Activated"
        return "Not Activated"
    except Exception as e:
        return f"Error: {str(e)}"

def get_system_info():
    info = {}
    info['Windows Version'] = platform.win32_ver()[0]
    info['Windows Activation'] = get_windows_activation_status()
    info['User has administrative rights'] = "YES" if ctypes.windll.shell32.IsUserAnAdmin() else "NO"
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
                f" {cpu_max_speed / 1000:.2f} GHz, {cpu_cores} Core(s) \n"
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

class MainWindow(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()

        self.tray_icon = QtWidgets.QSystemTrayIcon(self)
        self.tray_icon.setIcon(QtGui.QIcon('icon_info.ico'))

        show_action = QtWidgets.QAction("Show", self)
        quit_action = QtWidgets.QAction("Exit", self)
        hide_action = QtWidgets.QAction("Hide", self)

        show_action.triggered.connect(self.show)
        quit_action.triggered.connect(QtWidgets.qApp.quit)
        hide_action.triggered.connect(self.hide)

        tray_menu = QtWidgets.QMenu()
        tray_menu.addAction(show_action)
        tray_menu.addAction(hide_action)
        tray_menu.addAction(quit_action)

        self.tray_icon.setContextMenu(tray_menu)
        self.tray_icon.show()

        self.initUI()

    def initUI(self):
        self.setWindowTitle("Info")
        self.setGeometry(100, 100, 800, 600)

        # Set the window icon
        self.setWindowIcon(QtGui.QIcon('icon_info.ico'))

        layout = QtWidgets.QVBoxLayout()

        self.info_text = QtWidgets.QTextEdit(self)
        self.info_text.setReadOnly(True)
        self.info_text.setFont(QtGui.QFont('Courier', 10))
        self.info_text.setStyleSheet("background-color: black; color: white;")
        layout.addWidget(self.info_text)

        self.update_info_button = QtWidgets.QPushButton("Update System Info", self)
        self.update_info_button.clicked.connect(self.update_system_info)
        layout.addWidget(self.update_info_button)

        self.create_button = QtWidgets.QPushButton("Create 'tech' folder and add exception", self)
        self.create_button.setStyleSheet("background-color: green; color: white;")
        self.create_button.clicked.connect(self.create_tech_folder)
        layout.addWidget(self.create_button)

        self.delete_button = QtWidgets.QPushButton("Delete 'tech' folder and remove exception", self)
        self.delete_button.setStyleSheet("background-color: red; color: white;")
        self.delete_button.clicked.connect(self.delete_tech_folder)
        layout.addWidget(self.delete_button)

        self.status_label = QtWidgets.QLabel(self)
        self.status_label.setFont(QtGui.QFont('Arial', 12))
        self.status_label.setAlignment(QtCore.Qt.AlignCenter)
        layout.addWidget(self.status_label)

        self.exit_button = QtWidgets.QPushButton("Exit", self)
        self.exit_button.setStyleSheet("background-color: gray; color: white;")
        self.exit_button.clicked.connect(self.close)
        layout.addWidget(self.exit_button)

        self.setLayout(layout)

        self.update_system_info()

    def update_system_info(self):
        system_info = get_system_info()
        self.info_text.clear()

        self.info_text.append("<center>System Information</center>")
        self.info_text.append("<center>===============================</center>")
        for key, value in system_info.items():
            if isinstance(value, list):
                self.info_text.append(f"<center>{key}:</center>")
                for item in value:
                    self.info_text.append(f"<center>{item}</center>")
            else:
                self.info_text.append(f"<center>{key}: {value}</center>")
        self.info_text.append("<center>===============================</center>")
        self.status_label.setText("System info updated")

    def create_tech_folder(self):
        desktop_path = os.path.join(os.path.join(os.environ['USERPROFILE']), 'Desktop')
        tech_folder_path = os.path.join(desktop_path, 'tech')

        try:
            if not os.path.exists(tech_folder_path):
                os.makedirs(tech_folder_path)
                self.status_label.setText("Folder 'tech' created on the desktop. OK")
            else:
                self.status_label.setText("Folder 'tech' already exists on the desktop. OK")

            # Turn off real-time protection
            subprocess.run('powershell.exe Set-MpPreference -DisableRealtimeMonitoring $true', check=True, creationflags=subprocess.CREATE_NO_WINDOW)
            self.status_label.setText("Real-time protection turned off. OK")

            # Add the 'tech' folder to the Windows Defender exclusion list
            subprocess.run(f'powershell.exe Add-MpPreference -ExclusionPath "{tech_folder_path}"', check=True, creationflags=subprocess.CREATE_NO_WINDOW)
            self.status_label.setText("Folder 'tech' added to exclusion list. OK")
        except subprocess.CalledProcessError as e:
            QtWidgets.QMessageBox.critical(self, "Error", f"Failed to execute command: {str(e)}")
        except Exception as e:
            self.status_label.setText(f"Error: {str(e)} NOT")

    def delete_tech_folder(self):
        desktop_path = os.path.join(os.path.join(os.environ['USERPROFILE']), 'Desktop')
        tech_folder_path = os.path.join(desktop_path, 'tech')

        try:
            if os.path.exists(tech_folder_path):
                # Check for open files in the folder
                open_files_processes = get_open_files_in_directory(tech_folder_path)

                if open_files_processes:
                    # Display warning message
                    processes_list = "\n".join(open_files_processes)
                    QtWidgets.QMessageBox.critical(self, "Critical", f"The following programs have open files in the 'tech' folder:\n\n{processes_list}\n\nPlease close them before proceeding.")
                    return

                # Remove the directory and its contents
                shutil.rmtree(tech_folder_path)
                self.status_label.setText("Folder 'tech' deleted from the desktop. OK")
            else:
                self.status_label.setText("Folder 'tech' does not exist on the desktop. OK")

            # Turn on real-time protection
            subprocess.run('powershell.exe Set-MpPreference -DisableRealtimeMonitoring $false', check=True, creationflags=subprocess.CREATE_NO_WINDOW)
            self.status_label.setText("Real-time protection turned on. OK")

            # Remove the 'tech' folder from the Windows Defender exclusion list
            subprocess.run(f'powershell.exe Remove-MpPreference -ExclusionPath "{tech_folder_path}"', check=True, creationflags=subprocess.CREATE_NO_WINDOW)
            self.status_label.setText("Folder 'tech' removed from exclusion list. OK")
        except subprocess.CalledProcessError as e:
            QtWidgets.QMessageBox.critical(self, "Error", f"Failed to execute command: {str(e)}")
        except Exception as e:
            QtWidgets.QMessageBox.critical(self, "Error", f"Failed to execute command: {str(e)}")

def main():
    # Ensure the script is run with administrative privileges
    if not ctypes.windll.shell32.IsUserAnAdmin():
        QtWidgets.QMessageBox.critical(None, "Error", "This script requires administrative privileges. Please run it as an administrator.")
        return

    app = QtWidgets.QApplication(sys.argv)

    main_window = MainWindow()
    
    main_window.show()
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
