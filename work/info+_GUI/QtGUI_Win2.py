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
from PyQt5.QtCore import QTimer
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

def get_windows_activation_status():
    try:
        script = (
            "Get-WmiObject -Query 'select LicenseStatus from SoftwareLicensingProduct where PartialProductKey is not null and LicenseStatus=1' | "
            "Select-Object -ExpandProperty LicenseStatus"
        )
        result = subprocess.check_output(
            ['powershell', '-Command', script],
            text=True,
            creationflags=subprocess.CREATE_NO_WINDOW
        )
        if "1" in result.strip():
            return "Activated"
        else:
            return "Not Activated"
    except Exception as e:
        return f"Error: {str(e)}"

def get_serial_number():
    try:
        # Primary method: Execute the WMIC command to get the BIOS serial number
        result = subprocess.check_output(
            ['wmic', 'bios', 'get', 'serialnumber'],
            text=True,
            creationflags=subprocess.CREATE_NO_WINDOW
        ).strip().split('\n')
        
        # Iterate over the result to find the serial number
        for line in result:
            serial_number = line.strip()
            # Skip the header line or any empty line
            if serial_number and serial_number.lower() != "serialnumber" and serial_number != "To Be Filled By O.E.M.":
                return serial_number
    
    except subprocess.CalledProcessError as e:
        return f"Error: {str(e)}"

def get_pc_model():
    try:
        # Primary method: Execute the WMIC command to get the PC model
        result = subprocess.check_output(
            ['wmic', 'computersystem', 'get', 'model'],
            text=True,
            creationflags=subprocess.CREATE_NO_WINDOW
        ).strip().split('\n')
        
        # Iterate over the result to find the model
        for line in result:
            model = line.strip()
            # Skip the header line or any empty line
            if model and model.lower() != "model" and model.lower() != "to be filled by o.e.m.":
                return model
        
        # If the primary method fails or returns an invalid value, fall back to an alternative method
        return get_pc_model_fallback()
    
    except subprocess.CalledProcessError as e:
        return f"Error getting pc model: {str(e)}"

def get_pc_model_fallback():
    try:
        # Fallback method: Use WMI through win32com.client to get the PC model
        wmi = win32com.client.GetObject("winmgmts:")
        system_items = wmi.ExecQuery("Select Model from Win32_ComputerSystem")
        
        for system in system_items:
            model = system.Model.strip()
            if model and model.lower() != "model" and model.lower() != "to be filled by o.e.m.":
                return model

        return "PC model not found in fallback method"
    
    except Exception as e:
        return f"Error in fallback method: {str(e)}"

def get_windows_edition():
    try:
        # Connect to the WMI service
        wmi = win32com.client.Dispatch("WbemScripting.SWbemLocator")
        conn = wmi.ConnectServer(".", "root\\cimv2")
        
        # Query the operating system for the edition
        query = "SELECT Caption FROM Win32_OperatingSystem"
        os_info = conn.ExecQuery(query)
        
        # Extract and return the Windows edition
        for os in os_info:
            return os.Caption
    except Exception as e:
        return f"Error retrieving Windows edition: {str(e)}"



def get_ram_info():
    ram_info = {}

    try:
        # Initialize WMI object for fetching RAM information
        wmi_obj = wmi.WMI()
        ram_details = []

        # Dictionary to map memory types
        ram_types = {
            '20': 'DDR',
            '21': 'DDR2',
            '22': 'DDR2 FB-DIMM',
            '24': 'DDR3',
            '26': 'DDR4',
            '27': 'DDR5',
            '0': 'Unknown',
        }

        # Fetch RAM speed, type, manufacturer, and capacity using WMI
        for memory in wmi_obj.Win32_PhysicalMemory():
            memory_type = ram_types.get(str(memory.SMBIOSMemoryType), "Unknown")
            manufacturer = memory.Manufacturer.strip() if memory.Manufacturer else "Unknown Manufacturer"
            speed = memory.Speed if memory.Speed else "Unknown Speed"
            capacity = round(int(memory.Capacity) / (1024**3)) if memory.Capacity else "Unknown Capacity"

            # Fallback mechanism if the primary data is missing or incorrect
            if manufacturer.lower() in ["unknown manufacturer", "unknown"]:
                manufacturer = ram_fallback(memory.DeviceLocator, "Manufacturer")
            if memory_type == "Unknown":
                memory_type = ram_fallback(memory.DeviceLocator, "SMBIOSMemoryType", ram_types)
            if speed == "Unknown Speed":
                speed = ram_fallback(memory.DeviceLocator, "Speed")
            if capacity == "Unknown Capacity":
                capacity = ram_fallback(memory.DeviceLocator, "Capacity")

            ram_details.append(
                f"Manuf.: {manufacturer}, "
                f"{memory_type} "
                f"{capacity}GB "
                f"{speed} MHz"
            )

        if ram_details:
            ram_info["RAM"] = ram_details
        else:
            ram_info["RAM"] = ["No RAM information found"]

    except Exception as e:
        ram_info["Error"] = f"Error retrieving RAM information: {str(e)}"

    return ram_info

def ram_fallback(device_locator, attribute, ram_types=None):
    """
    General fallback method to retrieve RAM attributes.
    Handles Manufacturer, SMBIOSMemoryType, Speed, and Capacity.
    
    :param device_locator: The device locator for the memory module.
    :param attribute: The attribute to retrieve (e.g., Manufacturer, SMBIOSMemoryType, Speed, Capacity).
    :param ram_types: (Optional) The dictionary mapping for SMBIOSMemoryType.
    :return: The retrieved value or a string indicating it was not found.
    """
    try:
        wmi_obj = wmi.WMI()
        fallback_query = wmi_obj.query(f"SELECT {attribute} FROM Win32_PhysicalMemory WHERE DeviceLocator = '{device_locator}'")
        
        for memory in fallback_query:
            if attribute == "SMBIOSMemoryType" and memory.SMBIOSMemoryType:
                return ram_types.get(str(memory.SMBIOSMemoryType), "Unknown") if ram_types else str(memory.SMBIOSMemoryType)
            elif attribute == "Manufacturer" and memory.Manufacturer:
                return memory.Manufacturer.strip()
            elif attribute == "Speed" and memory.Speed:
                return memory.Speed
            elif attribute == "Capacity" and memory.Capacity:
                return round(int(memory.Capacity) / (1024**3))
        
        return f"Unknown {attribute}"

    except Exception as e:
        return f"Failed to retrieve {attribute}: {str(e)}"
    
def get_pci_lanes_info():
    pci_info = {}
    seen_device_ids = set()

    # Ensure 'GPU' key exists and is a list
    if 'GPU' not in pci_info:
        pci_info['GPU'] = []

    try:
        # Attempt to fetch GPU information using GPUtil
        gpus = GPUtil.getGPUs()        
        for gpu in gpus:
            device_id = gpu.uuid  # Using GPU UUID as a unique identifier
            if device_id not in seen_device_ids:
                gpu_details_str = f"{gpu.name} {gpu.memoryTotal / 1024:.2f}GBs"
                pci_info['GPU'].append(gpu_details_str)
                seen_device_ids.add(device_id)
        
        if not  pci_info['GPU']:
            raise ValueError("No GPUs found using GPUtil.")

    except (Exception, ValueError) as e:
        # Fallback to nvidia-smi in case GPUtil fails or returns no information
        pci_info['GPU'].append(get_gpu_info_fallback())

    return pci_info

def parse_nvidia_smi_xml(xml_output):
    root = ET.fromstring(xml_output)
    return [f"{gpu.find('product_name').text} - {gpu.find('fb_memory_usage/total').text}" for gpu in root.findall('gpu')]

def get_gpu_info_fallback():
    try:
        gpus = GPUtil.getGPUs()
        if not gpus:
            return ["No GPUs found using fallback method."]
        
        return [f"{gpu.name} - {gpu.memoryTotal / 1024:.2f} GB" for gpu in gpus]
    except Exception as e:
        return [f"Error fetching GPU info using fallback method: {str(e)}"]

def get_cpu_info():
    cpu_info = {}

    try:
        # Fetch CPU information using WMI
        w = wmi.WMI()
        cpu_details = []
        for cpu in w.Win32_Processor():            
            # Determine the color based on the CPU name
            if 'AMD' in cpu.Name:
                color = 'red'
            elif 'Intel' in cpu.Name:
                color = 'LightBlue'
            else:
                color = 'white'  # Default color if neither is found
    
            cpu_details_str = (
                f"<span style='color: {color};'>{cpu.Name}</span>\n"
                f"{cpu.MaxClockSpeed / 1000:.2f} GHz, "
                f"Cores: {cpu.NumberOfCores}, "
                f"Threads: {cpu.NumberOfLogicalProcessors}"
            )
            cpu_details.append(cpu_details_str)

        if cpu_details:
            cpu_info["CPU"] = cpu_details

    except Exception as e:
        cpu_info["Error"] = f"Error fetching CPU info: {str(e)}"

    return cpu_info

def get_disks():
    disk_info = {}

    try:
        # Initialize a list to hold the formatted information for each disk
        disk_details = []
        
        for disk in psutil.disk_partitions():
            if 'fixed' in disk.opts:
                usage = psutil.disk_usage(disk.mountpoint)
                disk_details.append(
                    f"{disk.device} | "
                    f" {disk.fstype} |"
                    f" {round(usage.total / (1024**3), 2)}GB | "
                    f" {round(usage.free / (1024**3), 2)}GB | "
                    f" {round(usage.used / (1024**3), 2)}GB"
                )

        if disk_details:
            disk_info["Disks"] = disk_details

    except Exception as e:
        disk_info["Error"] = f"Error fetching disk info: {str(e)}"

    return disk_info

def get_system_info():
    info = {}    

    info['Model'] = f"{get_pc_model()}"    
    info['S/N'] = f"{get_serial_number()}"

    info['Edition'] = f"{get_windows_edition()}"
    info['Architecture'] = f"{platform.architecture()[0]}"
    info['Windows Activation'] = f"{get_windows_activation_status()}"
    info['User has administrative rights'] = "YES" if ctypes.windll.shell32.IsUserAnAdmin() else "NO"  

    pc_info = {}
    pc_info.update(get_pci_lanes_info())
    pc_info.update(get_cpu_info())    
    pc_info.update (get_ram_info())
    pc_info.update(get_disks())
    pc_info.update(get_port_info('usb'))
    pc_info.update(get_port_info('display'))
    
    #info['PCI_Devices'] = pc_info.get('PCI_Devices', ["No PCI devices found"])

    info['RAM'] = pc_info.get('RAM', ["No RAM data found"])
    info['Disks'] = pc_info.get('Disks', ["No Disks found"])
    info['CPU'] = pc_info.get('CPU', ["No CPU Data found"])
    info['GPU'] = pc_info.get('GPU', ["No GPUs found"])
    info['USB'] = pc_info.get('USB', ["No USB data found"])
    info['Display'] = pc_info.get('Display', ["No Display data found"])

    return info

class MainWindow(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()        
        self.initUI()

    def initUI(self):
        self.setWindowTitle("PC Info")
        self.setGeometry(100, 100, 600, 700)
        self.setWindowIcon(QtGui.QIcon('icon_info.ico'))
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
    main()