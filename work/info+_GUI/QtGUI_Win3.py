import os
import platform
import subprocess
import xml.etree.ElementTree as ET
import psutil
import ctypes
import wmi
import sys
import shutil
import GPUtil
import win32com.client
from PyQt5 import QtWidgets, QtGui, QtCore
from PyQt5.QtGui import QIcon, QPixmap
from PyQt5.QtCore import QTimer
# Function to check for open files in a directory and return the process names

def get_value_or_fallback(wmi_class, attribute, fallback_function=None):
    try:
        wmi = win32com.client.Dispatch("WbemScripting.SWbemLocator")
        conn = wmi.ConnectServer(".", "root\\cimv2")
        query = f"SELECT {attribute} FROM {wmi_class}"
        items = conn.ExecQuery(query)
        
        for item in items:
            value = getattr(item, attribute).strip()
            if value and value.lower() != attribute.lower() and "o.e.m." not in value.lower():
                return value

        if fallback_function:
            return fallback_function()

        return f"{attribute} not found"
    except Exception as e:
        return f"Error retrieving {attribute}: {str(e)}"

def get_pc_model_fallback():
    try:
        wmi = win32com.client.GetObject("winmgmts:")
        system_items = wmi.ExecQuery("Select Model from Win32_ComputerSystem")
        
        for system in system_items:
            model = system.Model.strip()
            if model and "o.e.m." not in model.lower():
                return model

        return "PC model not found in fallback method"
    except Exception as e:
        return f"Error in fallback method: {str(e)}"

def get_windows_activation_status():
    try:
        script = (
            "Get-WmiObject -Query 'select LicenseStatus from SoftwareLicensingProduct "
            "where PartialProductKey is not null and LicenseStatus=1' | "
            "Select-Object -ExpandProperty LicenseStatus"
        )
        result = subprocess.check_output(
            ['powershell', '-Command', script],
            text=True,
            creationflags=subprocess.CREATE_NO_WINDOW
        ).strip()
        
        return "Activated" if "1" in result else "Not Activated"
    except Exception as e:
        return f"Error: {str(e)}"

def get_windows_edition():
    return get_value_or_fallback('Win32_OperatingSystem', 'Caption')

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

def get_ram_info(wmi_obj):
    ram_details = []
    ram_types = {
        '20': 'DDR', '21': 'DDR2', '22': 'DDR2 FB-DIMM', 
        '24': 'DDR3', '26': 'DDR4', '27': 'DDR5', '0': 'Unknown',
    }

    try:
        for memory in wmi_obj.Win32_PhysicalMemory():
            memory_type = ram_types.get(str(memory.SMBIOSMemoryType), "Unknown")
            manufacturer = memory.Manufacturer.strip() if memory.Manufacturer else "Unknown Manufacturer"
            speed = memory.Speed if memory.Speed else "Unknown Speed"
            capacity = round(int(memory.Capacity) / (1024**3)) if memory.Capacity else "Unknown Capacity"

            ram_details.append(
                f"Manuf.: {manufacturer}, "
                f"{memory_type} "
                f"{capacity}GB "
                f"{speed} MHz"
            )

    except Exception as e:
        return [f"Error retrieving RAM information: {str(e)}"]

    return ram_details if ram_details else ["No RAM information found"]

def get_pci_lanes_info():
    pci_info = {'GPU': []}
    seen_device_ids = set()

    try:
        gpus = GPUtil.getGPUs()
        for gpu in gpus:
            device_id = gpu.uuid
            if device_id not in seen_device_ids:
                pci_info['GPU'].append(f"{gpu.name} {gpu.memoryTotal / 1024:.2f} GB")
                seen_device_ids.add(device_id)
        if not pci_info['GPU']:
            raise ValueError("No GPUs found using GPUtil.")
    except (Exception, ValueError) as e:
        pci_info['GPU'].append(get_gpu_info_fallback())

    return pci_info

def get_gpu_info_fallback():
    try:
        gpus = GPUtil.getGPUs()
        return [f"{gpu.name} - {gpu.memoryTotal / 1024:.2f} GB" for gpu in gpus] or ["No GPUs found using fallback method."]
    except Exception as e:
        return [f"Error fetching GPU info using fallback method: {str(e)}"]

def get_cpu_info(wmi_obj):
    cpu_details = []

    try:
        for cpu in wmi_obj.Win32_Processor():
            color = 'red' if 'AMD' in cpu.Name else 'LightBlue' if 'Intel' in cpu.Name else 'white'
            cpu_details.append(
                f"<span style='color: {color};'>{cpu.Name}</span>\n"
                f"{cpu.MaxClockSpeed / 1000:.2f} GHz, "
                f"Cores: {cpu.NumberOfCores}, "
                f"Threads: {cpu.NumberOfLogicalProcessors}"
            )
    except Exception as e:
        return [f"Error fetching CPU info: {str(e)}"]

    return cpu_details if cpu_details else ["No CPU Data found"]

def get_disks():
    disk_details = []

    try:
        for disk in psutil.disk_partitions():
            if 'fixed' in disk.opts:
                usage = psutil.disk_usage(disk.mountpoint)
                disk_details.append(
                    f"{disk.device} | {disk.fstype} | "
                    f"{round(usage.total / (1024**3), 2)}GB | "
                    f"{round(usage.free / (1024**3), 2)}GB free | "
                    f"{round(usage.used / (1024**3), 2)}GB used"
                )
    except Exception as e:
        return [f"Error fetching disk info: {str(e)}"]

    return disk_details if disk_details else ["No Disks found"]

def get_system_info():
    info = {}    

    try:
        wmi_obj = wmi.WMI()

        # Fetch PC Model and Serial Number

        # Windows Edition and Activation Status
        # Model and Serial Number
        info['Model'] = get_value_or_fallback('Win32_ComputerSystem', 'Model', fallback_function=get_pc_model_fallback)
        info['S/N'] = get_value_or_fallback('Win32_BIOS', 'SerialNumber')

        # Windows Info
        info['Edition'] = get_windows_edition()
        info['Architecture'] = platform.architecture()[0]
        info['Windows Activation'] = get_windows_activation_status()
        info['User has administrative rights'] = "YES" if ctypes.windll.shell32.IsUserAnAdmin() else "NO"  

        # RAM Info
        info['RAM'] = get_ram_info(wmi_obj)

        # CPU Info
        info['CPU'] = get_cpu_info(wmi_obj)

        # Disk Info
        info['Disks'] = get_disks()

        # PCI and GPU Info
        pci_info = get_pci_lanes_info()
        info['GPU'] = pci_info.get('GPU', ["No GPUs found"])

    except Exception as e:
        info["Error"] = f"Error retrieving system information: {str(e)}"

    return info

class MainWindow(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()        
        self.initUI()

    def initUI(self):
        self.setWindowTitle("PC Info")
        self.setGeometry(100, 100, 600, 700)
        # Load the icon or image
        icon_path = self.resource_path("icon_info.ico")  # Use the bundled icon
        self.setWindowIcon(QIcon(icon_path))
        #Tooltip colors
        self.setStyleSheet("QToolTip { color: black; background-color: white; border: 1px solid black; }")


        #cant execute other tasks while operation action, not worth it 
        # Set up a QTimer to call refresh_system_info every 6 seconds
        # self.timer = QTimer(self)
        # self.timer.timeout.connect(self.refresh_system_info)
        # self.timer.start(6000)

        # Set the window icon and main layout
        layout = QtWidgets.QVBoxLayout()
        self.pc_info_text = QtWidgets.QTextEdit(self)
        self.pc_info_text.setReadOnly(False)
        self.pc_info_text.setFont(QtGui.QFont('Courier', 10))
        self.pc_info_text.setStyleSheet("background-color: black; color: white;")
        layout.addWidget(self.pc_info_text)

        self.refresh_info_button = QtWidgets.QPushButton("Refresh System Info", self)
        self.refresh_info_button.setStyleSheet("background-color: grey; color: black;")
        layout.addWidget(self.refresh_info_button)
        self.refresh_info_button.clicked.connect(self.refresh_system_info)

        self.create_button = QtWidgets.QPushButton("Create 'tech' folder and add exception", self)
        self.create_button.setStyleSheet("background-color: green; color: white;")
        self.create_button.clicked.connect(self.create_tech_folder)
        layout.addWidget(self.create_button)

        self.delete_button = QtWidgets.QPushButton("Delete 'tech' folder and remove exception", self)
        self.delete_button.setStyleSheet("background-color: red; color: white;")
        self.delete_button.clicked.connect(self.delete_tech_folder)
        layout.addWidget(self.delete_button)

        self.kms_exp_command = QtWidgets.QPushButton("KMS Exclude", self)
        self.kms_exp_command.setStyleSheet("background-color: brown; color: white;")
        self.kms_exp_command.clicked.connect(self.kms_security_bypass)
        layout.addWidget(self.kms_exp_command)


        # design open Edge in private mode button
        self.edge_button = QtWidgets.QPushButton(self)
        self.edge_button.setIcon(self.style().standardIcon(QtWidgets.QStyle.SP_ComputerIcon))
        self.edge_button.setIconSize(QtCore.QSize(32, 32))
        self.edge_button.setToolTip("Keyboard Test (Beta) Internet required")
        self.edge_button.setStyleSheet("background-color: blue; color: white;")
        self.edge_button.clicked.connect(self.open_edge_private)

        # design fast shutdown button
        self.shutdown_button = QtWidgets.QPushButton(self)
        self.shutdown_button.setIcon(self.style().standardIcon(QtWidgets.QStyle.SP_TitleBarCloseButton))
        self.shutdown_button.setIconSize(QtCore.QSize(32, 32))
        self.shutdown_button.setToolTip("Click to shut down the system immediately")
        self.shutdown_button.setStyleSheet("background-color: red; color: white;")
        self.shutdown_button.clicked.connect(self.confirm_shutdown)

        # design fast restart button
        self.restart_button = QtWidgets.QPushButton(self)
        self.restart_button.setIcon(self.style().standardIcon(QtWidgets.QStyle.SP_MessageBoxWarning))
        self.restart_button.setIconSize(QtCore.QSize(32, 32))
        self.restart_button.setToolTip("Click to restart the system immediately")
        self.restart_button.setStyleSheet("background-color: orange; color: white;")
        self.restart_button.clicked.connect(self.confirm_restart)
       
        # Create a horizontal layout for the three buttons
        buttons_layout_edgeShutRest = QtWidgets.QHBoxLayout()
        # Connect button signals to their respective slots
        buttons_layout_edgeShutRest.addWidget(self.edge_button)
        buttons_layout_edgeShutRest.addWidget(self.restart_button) 
        buttons_layout_edgeShutRest.addWidget(self.shutdown_button)

        # Info Label
        self.status_label = QtWidgets.QLabel(self)
        self.status_label.setFont(QtGui.QFont('Arial', 12))
        self.status_label.setAlignment(QtCore.Qt.AlignCenter)
        layout.addWidget(self.status_label)

        # Exit btn
        self.exit_button = QtWidgets.QPushButton("Exit", self)
        self.exit_button.setStyleSheet("background-color: black; color: white;")
        self.exit_button.clicked.connect(self.close)

        self.setLayout(layout)

        self.set_system_info()

        grid_layout = QtWidgets.QGridLayout()

        # deseign to the grid layout
        grid_layout.addWidget(self.create_button, 0, 0)    
        grid_layout.addWidget(self.delete_button, 0, 1)  
        grid_layout.addWidget(self.kms_exp_command, 1, 0) 
        grid_layout.addLayout(buttons_layout_edgeShutRest, 1, 1)  # Add the new buttons next to KMS Exclude button
        grid_layout.addWidget(self.exit_button, 2, 0, 1, 2)  # Span exit button across two columns
        #Row 0	Column 0	Column 1
        #Row 1	create_button          |	delete_button
        #Row 2	kms_exp_command | 	button_layout (three buttons)
        #Row 3	exit_button (spans both columns)	
        
        # Add the grid layout to the main layout
        layout.addLayout(grid_layout)
    
    
    def resource_path(self, relative_path):
        """ Get the absolute path to the resource, works for development and for PyInstaller bundle """
        try:
            base_path = sys._MEIPASS  # Used by PyInstaller to store temp files
        except Exception:
            base_path = os.path.abspath(".")
        return os.path.join(base_path, relative_path)
    
    def set_system_info(self):
        system_info = get_system_info()

        self.pc_info_text.append("<center>System Information</center>")
        self.pc_info_text.append("<center>===============================</center>")
        for key, value in system_info.items():
            if key == "Windows Activation": # new method to add color individually in CPU change it fow windows status 
                # Check the activation status and set the color accordingly
                if value == "Not Activated":
                    self.pc_info_text.append(f"<center><span style='color: grey;'>{key}:</span> <span style='color: red;'>{value}</span></center>")
                elif value == "Activated":
                    self.pc_info_text.append(f"<center><span style='color: grey;'>{key}:</span> <span style='color: green;'>{value}</span></center>")
            elif isinstance(value, list):
                # grab items from a list
                self.pc_info_text.append(f"<center><span style='color: grey;'>{key}:</span></center>")
                for item in value:
                    # If item is a dictionary, fetch and display each key-value pair
                    if isinstance(item, dict):
                        for sub_key, sub_value in item.items():
                            self.pc_info_text.append(f"<center><span style='color: grey;'>{sub_key}:</span> <span style='color: white;'>{sub_value}</span></center>")
                    else:
                        # display if get only a value 
                        self.pc_info_text.append(f"<center><span style='color: white;'>{item}</span></center>")
            elif isinstance(value, dict):
                # If value is a dictionary, display its content with grey key and white value
                for sub_key, sub_value in value.items():
                    self.pc_info_text.append(f"<center><span style='color: grey;'>{sub_key}:</span> <span style='color: white;'>{sub_value}</span></center>")
            else:
                # Set the key color to grey and value to white
                self.pc_info_text.append(f"<center><span style='color: grey;'>{key}:</span> <span style='color: orange;'>{value}</span></center>")
        self.pc_info_text.append("<center>===============================</center>")

        
    def refresh_system_info(self):
        self.pc_info_text.clear()
        self.set_system_info()
        self.status_label.setStyleSheet("color: green; font-weight: bold; font-size: 14px;")
        self.status_label.setText("System info refreshed")
                                  
        # Create a QTimer to clear the status_label after 5 seconds (5000 milliseconds)
        QTimer.singleShot(5000, self.clear_status_label)

    def clear_status_label(self):
        self.status_label.clear()

    def create_tech_folder(self):
        desktop_path = os.path.join(os.path.join(os.environ['USERPROFILE']), 'Desktop')
        tech_folder_path = os.path.join(desktop_path, 'tech')

        try:
            # Create the 'tech' folder if it doesn't exist
            if not os.path.exists(tech_folder_path):
                os.makedirs(tech_folder_path)
                self.status_label.setStyleSheet("color: green; font-weight: bold; font-size: 14px;")
                self.status_label.setText("Folder 'tech' created on the desktop.")
            else:
                self.status_label.setStyleSheet("color: orange; font-weight: bold; font-size: 14px;")
                self.status_label.setText("Folder 'tech' already exists on the desktop.")

            # Disable real-time protection using win32com.client
            shell = win32com.client.Dispatch("WScript.Shell")
            self.status_label.setStyleSheet("color: green; font-weight: bold; font-size: 14px;")
            # Add the 'tech' folder to Windows Defender exclusion list
            shell.Run(f"powershell.exe -Command \"Add-MpPreference -ExclusionPath '{tech_folder_path}'\"", 0, True)
            self.status_label.setText("Folder 'tech' added to exclusion list.")

        except Exception as e:
            # Handle exceptions and display an error message
            QtWidgets.QMessageBox.critical(self, "Error", f"Failed to execute command: {str(e)}")

    def delete_tech_folder(self):
        desktop_path = os.path.join(os.path.join(os.environ['USERPROFILE']), 'Desktop')
        tech_folder_path = os.path.join(desktop_path, 'tech')

        try:
            if os.path.exists(tech_folder_path):
                
                open_files_processes = get_open_files_in_directory(tech_folder_path)

                if open_files_processes:
                    processes_list = "\n".join(open_files_processes)
                    QtWidgets.QMessageBox.critical(self, "Critical", f"The following programs \n{processes_list}\n have open files in the 'tech' folder:\n\nPlease close them before proceeding.")
                    return
                
                shutil.rmtree(tech_folder_path)
                self.status_label.setStyleSheet("color: green; font-weight: bold; font-size: 14px;")
                self.status_label.setText("Folder 'tech' deleted from the desktop.")
            else:
                self.status_label.setStyleSheet("color: red; font-weight: bold; font-size: 14px;")
                self.status_label.setText("Folder 'tech' does not exist on the desktop.")
            
            self.status_label.setText("Real-time protection turned on")
            # Remove the 'tech' folder from the Windows Defender exclusion list
            subprocess.run(f'powershell.exe Remove-MpPreference -ExclusionPath "{tech_folder_path}"', check=True, creationflags=subprocess.CREATE_NO_WINDOW)
            self.status_label.setStyleSheet("color: red; font-weight: bold; font-size: 14px;")
            self.status_label.setText("Folder 'tech' removed from exclusion list.")
        
        except subprocess.CalledProcessError as e:
            #print(f"Error executing command: {str(e)}")
            QtWidgets.QMessageBox.critical(self, "Error", f"Failed to execute command: {str(e)}")
        except Exception as e:
            #print(f"Error executing command: {str(e)}")
            QtWidgets.QMessageBox.critical(self, "Error", f"Failed to execute command: {str(e)}")
    
    def kms_security_bypass(self):
        # Command for KMS security prevention (from KMSAuto .Rabious aka*Dragonite)
        try:
            command_list = [
                "Add-MpPreference -ThreatIDDefaultAction_Ids 2147685180 -ThreatIDDefaultAction_Actions Allow -Force",
                "Add-MpPreference -ThreatIDDefaultAction_Ids 2147735507 -ThreatIDDefaultAction_Actions Allow -Force",
                "Add-MpPreference -ThreatIDDefaultAction_Ids 2147736914 -ThreatIDDefaultAction_Actions Allow -Force",
                "Add-MpPreference -ThreatIDDefaultAction_Ids 2147743522 -ThreatIDDefaultAction_Actions Allow -Force",
                "Add-MpPreference -ThreatIDDefaultAction_Ids 2147734094 -ThreatIDDefaultAction_Actions Allow -Force",
                "Add-MpPreference -ThreatIDDefaultAction_Ids 2147743421 -ThreatIDDefaultAction_Actions Allow -Force",
                "Add-MpPreference -ThreatIDDefaultAction_Ids 2147765679 -ThreatIDDefaultAction_Actions Allow -Force",
                "Add-MpPreference -ThreatIDDefaultAction_Ids 2147783203 -ThreatIDDefaultAction_Actions Allow -Force",
                "Add-MpPreference -ThreatIDDefaultAction_Ids 251873 -ThreatIDDefaultAction_Actions Allow -Force",
                "Add-MpPreference -ThreatIDDefaultAction_Ids 213927 -ThreatIDDefaultAction_Actions Allow -Force",
                "Add-MpPreference -ThreatIDDefaultAction_Ids 2147722906 -ThreatIDDefaultAction_Actions Allow -Force",
                "Add-MpPreference -ExclusionPath C:\\Windows\\KMSAutoS -Force",
                "Add-MpPreference -ExclusionPath C:\\Windows\\System32\\SppExtComObjHook.dll -Force",
                "Add-MpPreference -ExclusionPath C:\\Windows\\System32\\SppExtComObjPatcher.exe -Force",
                "Add-MpPreference -ExclusionPath C:\\Windows\\AAct_Tools -Force",
                "Add-MpPreference -ExclusionPath C:\\Windows\\AAct_Tools\\AAct_x64.exe -Force",
                "Add-MpPreference -ExclusionPath C:\\Windows\\AAct_Tools\\AAct_files\\KMSSS.exe -Force",
                "Add-MpPreference -ExclusionPath C:\\Windows\\AAct_Tools\\AAct_files -Force",
                "Add-MpPreference -ExclusionPath C:\\Windows\\KMS -Force"
            ]

            # Execute each command separately in PowerShell with hidden window
            for cmd in command_list:
                subprocess.run(
                    f'powershell -nologo -noninteractive -windowStyle hidden -noprofile -command "{cmd}"',
                    check=True,
                    creationflags=subprocess.CREATE_NO_WINDOW,
                    shell=True
                )
            self.status_label.setStyleSheet("color: green; font-weight: bold; font-size: 14px;")
            self.status_label.setText("KMS security prevention bypass added successfully.")
        except subprocess.CalledProcessError as e:
            #print(f"Error executing command: {str(e)}")
            self.status_label.setStyleSheet("color: red; font-weight: bold; font-size: 14px;")
            self.status_label.setText(f"Error executing command: {str(e)}")
        
    def open_edge_private(self):
        # Command to open Microsoft Edge in private mode with the specified URL
        subprocess.run(['start', 'msedge', '--inprivate', 'https://keyboard-test.space/'], shell=True)
    
    def confirm_shutdown(self):
        reply = QtWidgets.QMessageBox.question(
            self, 
            'Confirm Shutdown', 
            "Shut down the system?", 
            QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No, 
            QtWidgets.QMessageBox.Yes  # Set default to Yes
        )

        if reply == QtWidgets.QMessageBox.Yes:
            self.fast_shutdown()

    def fast_shutdown(self):
        # Command to perform a fast shutdown
        #/s: This switch tells the system to shut down.
        #/f: This forces running applications to close without warning the user, which is essential for an instant shutdown.
        #/t 0: This specifies the time delay before the shutdown in seconds. The value 0 means the shutdown should occur immediately.
        subprocess.run(['shutdown', '/s', '/f', '/t', '0'], shell=True)

    def confirm_restart(self):
        reply = QtWidgets.QMessageBox.question(
            self, 
            'Confirm Restart', 
            "Restart the system?", 
            QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No, 
            QtWidgets.QMessageBox.Yes  # Set default to Yes
        )

        if reply == QtWidgets.QMessageBox.Yes:
            self.fast_restart()

    def fast_restart(self):
        # Command to perform a fast restart
        #/r:
        #   This switch tells the shutdown command to restart the computer after shutting it down.
    #       Unlike /s which shuts down the system completely, /r shuts down the system and then reboots it.
        #/f:
        #     This switch forces running applications to close without warning the user.
        #     It ensures that the system does not wait for applications to close gracefully, making the restart immediate.
        #     Be aware that this might result in unsaved work being lost, as the system does not prompt to save open files.

        # /t 0:
        #     This specifies the time delay before the restart in seconds.
        #     The value 0 means that the restart should happen immediately.
        #     If you wanted to delay the restart by, say, 30 seconds, you would use /t 30 instead.

        # shell=True:
        # This argument is part of the subprocess.run function and is used to indicate that the command should be run through the shell.
        # This allows you to execute shell commands directly from within a Python script
        subprocess.run(['shutdown', '/r', '/f', '/t', '0'], shell=True)



def main():
    # Ensure the script is run with administrative privileges
    if not ctypes.windll.shell32.IsUserAnAdmin():
        QtWidgets.QMessageBox.critical(None, "Error", "Requires administrative privileges.")
        return

    app = QtWidgets.QApplication(sys.argv)

    main_window = MainWindow()    
    main_window.show()

    sys.exit(app.exec_())

if __name__ == "__main__":
    if not ctypes.windll.shell32.IsUserAnAdmin():
        QtWidgets.QMessageBox.critical(None, "Error", "Requires administrative privileges.")
        sys.exit()
    app = QtWidgets.QApplication(sys.argv)
    main_window = MainWindow()
    main_window.show()
    sys.exit(app.exec_())