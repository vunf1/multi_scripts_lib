
import platform
import webbrowser
import xml.etree.ElementTree as ET
import psutil
import GPUtil
import win32com.client
import sys, os, subprocess, ctypes, shutil, socket
from PyQt5 import QtWidgets, QtGui, QtCore
from PyQt5.QtGui import QIcon, QPixmap
from PyQt5.QtCore import QTimer
import barcode
from barcode.writer import ImageWriter
import cv2
import re
import time
import py3nvml.py3nvml as nvml
import logging
import concurrent.futures
COLORS = {
    "green": "rgb(206,255,0)",
    "red": "rgb(239,20,20)",
    "yellow": "rgb(227,245,0)",
    "blue": "rgb(0,139,139)",
}
# logging for low level adjustments and debug stdout stdin
logging.basicConfig(filename='system_debug.log', level=logging.DEBUG, 
                    format='%(asctime)s - %(levelname)s - %(message)s')
def s_text(text, color):
    return f"<span style='color:{color};'>{text}</span>"
#Win32 Calls to retreive PC data
def get_value_win32(wmi_class, attributes, mode=None):
    try:
        # Create a WMI connection
        wmi = win32com.client.Dispatch("WbemScripting.SWbemLocator")
        conn = wmi.ConnectServer(".", "root\\cimv2")

        # Generate the query string for WMI
        query = f"SELECT {', '.join(attributes)} FROM {wmi_class}"
        items = conn.ExecQuery(query)

        # Handle different modes
        if mode == 'GPU':
            return handle_gpu_mode(items)
        elif mode == 'CPU':
            return handle_cpu_mode(items)
        elif mode == 'RAM':
            return handle_ram_mode(items)
        else:
            return handle_default_mode(items, attributes)

    except Exception as e:
        # Log the error and return a message indicating failure
        error_message = f"Failed to retrieve data: {str(e)}"
        logging.error(error_message)
        return error_message

def handle_gpu_mode(gpus):
    gpus_info = {'GPU': []}

    for gpu in gpus:
        name = gpu.Name
        memory_str = retrieve_memory(gpu.AdapterRAM, name)
        current_refresh_rate = gpu.CurrentRefreshRate
        max_refresh_rate = getattr(gpu, 'MaxRefreshRate', "N/A")

        if name:
            gpus_info['GPU'].append(
                f"{name} | Memory: {memory_str} | "
                f"Cur. RR: {current_refresh_rate} Hz | "
                f"Max RR: {max_refresh_rate} Hz"
            )
    
    if not gpus_info['GPU']:
        gpus_info['GPU'].append("No GPU Data found")
    
    return gpus_info

def handle_cpu_mode(cpus):
    cpu_details = []

    for cpu in cpus:
        color = 'red' if 'AMD' in cpu.Name else 'LightBlue' if 'Intel' in cpu.Name else 'white'
        cpu_details.append(
            s_text(
                f"{cpu.Name} "
                f"{cpu.MaxClockSpeed / 1000:.2f} GHz, "
                f"Cores: {cpu.NumberOfCores}, "
                f"Threads: {cpu.NumberOfLogicalProcessors}",
                color
            )
        )

    return cpu_details if cpu_details else ["No CPU Data found"]

def handle_ram_mode(items, ram_types=None):
    ram_details = []
    ram_types = ram_types or {
        '20': 'DDR', '21': 'DDR2', '22': 'DDR2 FB-DIMM',
        '24': 'DDR3', '26': 'DDR4', '27': 'DDR5', '0': 'Unknown',
    }

    for memory in items:
        memory_type = ram_types.get(str(memory.SMBIOSMemoryType), "Unknown")
        manufacturer = memory.Manufacturer.strip() if memory.Manufacturer else "Unknown Manufacturer"
        speed = memory.Speed or "Unknown Speed"
        capacity = round(int(memory.Capacity) / (1024**3)) if memory.Capacity else "Unknown Capacity"

        ram_details.append(
            f"Manuf.: {manufacturer}, "
            f"{memory_type} "
            f"{s_text(f'{capacity}GB', 'yellow')} "
            f"{speed} MHz"
        )
    
    return ram_details if ram_details else ["No RAM information found"]

def handle_default_mode(items, attributes):
    results = {}
    for item in items:
        for attribute in attributes:
            try:
                value = getattr(item, attribute, "").strip()
                if value and value.lower() != attribute.lower() and "o.e.m." not in value.lower():
                    return value
            except Exception as e:
                logging.error(f"Failed to retrieve {attribute}: {str(e)}")
                return f"{attribute} not found"

    if not results:
        return f"{', '.join(attributes)} not found"

    return results

def retrieve_memory(adapter_ram, name):
    if adapter_ram and adapter_ram > (1024**2):
        memory = adapter_ram / (1024**3)
        return f"{memory:.2f} GB" if memory > 0 else "Memory not available (invalid value)"
    else:
        return get_vendor_specific_memory(name)

def get_vendor_specific_memory(name):
    if "NVIDIA" in name:
        try:
            nvml.nvmlInit()
            handle = nvml.nvmlDeviceGetHandleByIndex(0)
            memory_info = nvml.nvmlDeviceGetMemoryInfo(handle)
            nvml.nvmlShutdown()
            return f"{memory_info.total / (1024**3):.2f} GB"
        except Exception as e:
            return f"Failed to retrieve NVIDIA memory: {str(e)}"

    return "Memory not available"

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
        
        return "Activated" if "1" in result else  "Not Activated"
    except Exception:
        return "Not Activated" 
# Function to check for open files in a directory and return the process names
def get_open_files_in_directory(directory):
    open_files_processes = []
    for proc in psutil.process_iter(['name', 'open_files']):
        try:
            open_files = proc.info['open_files']
            if open_files:
                for file in open_files:
                    if file.path.startswith(directory):
                        open_files_processes.append(proc.info['name'])
                        break  # save break to avoid adding the same process multiple times
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return open_files_processes

def get_ram_info():
    ram_details = []
    ram_types = {
        '20': 'DDR', '21': 'DDR2', '22': 'DDR2 FB-DIMM', 
        '24': 'DDR3', '26': 'DDR4', '27': 'DDR5', '0': 'Unknown',
    }

    try:
        wmi = win32com.client.Dispatch("WbemScripting.SWbemLocator")
        conn = wmi.ConnectServer(".", "root\\cimv2")
        ram_modules = conn.ExecQuery("SELECT Manufacturer, SMBIOSMemoryType, Speed, Capacity FROM Win32_PhysicalMemory")

        for memory in ram_modules:
            memory_type = ram_types.get(str(memory.SMBIOSMemoryType), "Unknown")
            manufacturer = memory.Manufacturer.strip() if memory.Manufacturer else "Unknown Manufacturer"
            speed = memory.Speed or "Unknown Speed"
            capacity = round(int(memory.Capacity) / (1024**3)) if memory.Capacity else "Unknown Capacity"

            ram_details.append(
                f"Manuf.: {manufacturer}, "
                f"{memory_type} "
                f"{s_text(f"{capacity}GB","yellow")} "
                f"{speed} MHz"
            )

    except Exception:
        return ["No RAM information found"]

    return ram_details

def get_disks():
    disk_details = []

    try:
        for disk in psutil.disk_partitions():
            if 'fixed' in disk.opts:
                usage = psutil.disk_usage(disk.mountpoint)
                disk_details.append(   
                    f"{disk.device} | {disk.fstype} | "
                    f"{round(usage.total / (1024**3), 2)}GB | "
                    f"{s_text(f'{round(usage.free / (1024**3), 2)}GB free', "green")} | "
                    f"{s_text(f'{round(usage.used / (1024**3), 2)}GB used', "red")} | "
                )
    except Exception:
        return ["No Disks found"]

    return disk_details

def get_system_info():
    info = {}

    try:
        # Fetch PC Model and Serial Number
        info['Model'] = get_value_win32('Win32_ComputerSystem', ['Model'])
        info['S/N'] = s_text(get_value_win32('Win32_BIOS', ['SerialNumber']),"green")

        # Windows Info
        info['Edition'] =s_text(get_value_win32('Win32_OperatingSystem', ['Caption']),"yellow")
        info['Architecture'] = platform.architecture()[0] #86 | 64bit

        info['Windows Activation'] = s_text(get_windows_activation_status(), "green" if get_windows_activation_status() == "Activated" else "red")

        admin_status = "YES" if ctypes.windll.shell32.IsUserAnAdmin() else "NO"
        
        info['User has administrative rights'] = s_text(admin_status, "yellow" if admin_status == "YES" else "red")

        # RAM Info
        info['RAM'] = get_value_win32('Win32_PhysicalMemory', ['Manufacturer', 'SMBIOSMemoryType', 'Speed', 'Capacity'], mode='RAM')

        # CPU Info
        info['CPU'] = get_value_win32('Win32_Processor', ['Name, MaxClockSpeed, NumberOfCores, NumberOfLogicalProcessors'], "CPU")

        # Disk Info
        info['Disks'] = get_disks()

        # PCI and GPU Info
        info['GPU'] = get_value_win32('Win32_VideoController', ['Name', 'AdapterRAM', 'CurrentRefreshRate', 'MaxRefreshRate'], "GPU").get('GPU', ["No GPUs found"])


    except Exception as e:
        info["Error"] = f"Error retrieving system information: {str(e)}"

    return info

def execute_powershell_command(command):
    """Execute a PowerShell command using WScript.Shell's Run method."""
    try:
        shell = win32com.client.Dispatch("WScript.Shell")
        logging.info(f"Running PowerShell command: {command}")
        result = shell.Run(f"powershell.exe -Command \"{command}\"", 0, True)
        
        if result != 0:
            error_message = f"Command failed with exit code: {result}"
            logging.error(f"Command failed: {command}\nError: {error_message}")
            raise Exception(error_message)
        else:
            logging.info(f"Command executed successfully: {command}")
    except Exception as e:
        logging.error(f"Unexpected Error: {str(e)}")
        raise

class ImageWindow(QtWidgets.QWidget):
    def __init__(self, image_path, parent):
        super().__init__(parent)
                
        self.image_path = image_path  # Ensure image_path is correctly assigned
        self.parent_window = parent  # Store the parent reference

        # Set window flags to remove border and icon
        self.setWindowFlags(QtCore.Qt.FramelessWindowHint)

        # Create a label to hold the image
        self.image_label = QtWidgets.QLabel(self)
        pixmap = QtGui.QPixmap(image_path)
        self.image_label.setPixmap(pixmap)

        # Create a close button (X) in the top right corner
        close_button = QtWidgets.QPushButton('X', self)
        close_button.setStyleSheet("background-color: red; color: white; font-weight: bold; border: none;")
        close_button.setFixedSize(30, 30)
        close_button.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        close_button.clicked.connect(self.close)  # Connect the button to the close event

        # Create a layout for the close button and add it to the top-right corner
        close_button_X = QtWidgets.QHBoxLayout()
        close_button_X.addWidget(close_button, alignment=QtCore.Qt.AlignRight)
        close_button_X.setContentsMargins(0, 0, 0, 0)

        # Main layout combining the button and image
        main_layout = QtWidgets.QVBoxLayout()
        main_layout.addLayout(close_button_X)
        main_layout.addWidget(self.image_label)
        main_layout.setContentsMargins(0, 0, 0, 0)

        # Adjust the size of the window to fit the image
        self.setLayout(main_layout)
        self.resize(pixmap.width(), pixmap.height() + close_button.height())

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self.old_pos = event.globalPos()

    def mouseMoveEvent(self, event):
        delta = QtCore.QPoint(event.globalPos() - self.old_pos)
        self.move(self.x() + delta.x(), self.y() + delta.y())
        self.old_pos = event.globalPos()

    def closeEvent(self, event):
        try:
            if os.path.exists(self.image_path):
                os.remove(self.image_path)  # Delete the image file
                if self.parent_window:
                    self.parent_window.status_label.setText(s_text(f"Image file {os.path.basename(self.image_path)} deleted.", "green"))
            else:
                if self.parent_window:
                    self.parent_window.status_label.setText(s_text(f"Image file {os.path.basename(self.image_path)} not found.", "red"))
        except Exception as e:
            if self.parent_window:
                self.parent_window.status_label.setText(s_text(f"Failed to delete image file: {str(e)}", "red"))
        
        event.accept()  # Ensure the window closes cleanly
class MainWindow(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.cv2 = cv2  # Initialize OpenCV 
        self.initUI()

    def initUI(self):
        
        self.setWindowTitle("Fast PC Fetch")
        self.setGeometry(100, 200, 850, 650) 
        # Main layout
        # Remove the window frame to create a custom close button
        self.setWindowFlags(QtCore.Qt.FramelessWindowHint)

        # Main layout
        layout = QtWidgets.QVBoxLayout()

        # Create a close button (X) in the top right corner
        close_button = QtWidgets.QPushButton('X', self)
        close_button.setStyleSheet("background-color: red; color: white; font-weight: bold; border: none;")
        close_button.setFixedSize(30, 30)
        close_button.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        close_button.clicked.connect(self.close)  # Connect the button to the close event

        # Create a layout for the close button and add it to the top-right corner
        topbar_layout = QtWidgets.QHBoxLayout()
        topbar_layout.addWidget(close_button, alignment=QtCore.Qt.AlignRight)
        topbar_layout.setContentsMargins(0, 0, 0, 0)

        # Add the close button layout to the main layout
        layout.addLayout(topbar_layout)
        # System info display area
        self.pc_info_text = QtWidgets.QTextEdit(self)
        self.pc_info_text.setReadOnly(True)
        self.pc_info_text.setFont(QtGui.QFont('Courier', 9))
        self.pc_info_text.setStyleSheet("background-color: black; color: white;")
        self.pc_info_text.setAlignment(QtCore.Qt.AlignCenter)  # Align text to the center
       

        # Refresh button
        self.refresh_info_btn = QtWidgets.QPushButton("Refresh System Info", self)
        self.refresh_info_btn.clicked.connect(self.refresh_system_info)


        self.create_folder_btn = QtWidgets.QPushButton("Create 'tech' folder", self)
        self.create_folder_btn.clicked.connect(self.create_tech_folder)

        self.delete_folder_btn = QtWidgets.QPushButton("Delete 'tech' folder", self)
        self.delete_folder_btn.clicked.connect(self.delete_tech_folder)

        self.barcode_button = QtWidgets.QPushButton("Generate Barcode", self)
        self.barcode_button.clicked.connect(self.generate_barcode)

        self.delete_barcode_button = QtWidgets.QPushButton("Delete Barcode", self)
        self.delete_barcode_button.clicked.connect(self.delete_barcode)



        self.kms_exclude_btn = QtWidgets.QPushButton("KMS Exclude", self)
        self.kms_exclude_btn.clicked.connect(self.kms_security_bypass)

        self.keyboard_test_btn = QtWidgets.QPushButton(self)
        self.keyboard_test_btn.setIcon(self.style().standardIcon(QtWidgets.QStyle.SP_ComputerIcon))
        self.keyboard_test_btn.setToolTip("Keyboard Test")
        self.keyboard_test_btn.clicked.connect(lambda: self.open_executable('AquaKeyTest.exe'))


        self.shutdown_btn = QtWidgets.QPushButton("Shutdown", self)
        self.shutdown_btn.setToolTip("Fast Shut down")
        self.shutdown_btn.clicked.connect(self.confirm_shutdown)

        self.restart_btn = QtWidgets.QPushButton("Restart", self)
        self.restart_btn.setToolTip("Fast Restart")
        self.restart_btn.clicked.connect(self.confirm_restart)

        self.camera_button = QtWidgets.QPushButton(self)
        self.camera_button.setIcon(QtGui.QIcon(self.style().standardIcon(QtWidgets.QStyle.SP_DialogNoButton)))
        self.camera_button.setToolTip("Open Cameras")
        self.camera_button.clicked.connect(self.display_all_cameras)


        self.clean_footprint = QtWidgets.QPushButton("Clean", self)
        self.clean_footprint.setToolTip("Clean Footprint")
        self.clean_footprint.clicked.connect(self.clean_system)

        self.private_browser = QtWidgets.QPushButton("Private B", self)
        self.private_browser.setToolTip("Private browser")
        self.private_browser.clicked.connect(self.open_duckduckgo_private)

        # Status label
        self.status_label = QtWidgets.QLabel("", self)
        self.status_label.setAlignment(QtCore.Qt.AlignCenter)
        
        # Internet connection status label
        self.internet_status_label = QtWidgets.QLabel("Checking internet connection...", self)
        self.internet_status_label.setAlignment(QtCore.Qt.AlignCenter)


        # Exit button
        self.exit_button = QtWidgets.QPushButton("Exit", self)
        self.exit_button.setToolTip("Exit")
        self.exit_button.clicked.connect(self.close)

        #populate system label when start
        self.set_system_info()
        
        # Timer to check internet connection status every 5 seconds
        self.internet_timer = QtCore.QTimer(self)
        self.internet_timer.timeout.connect(self.check_internet_connection)
        #self.internet_timer.timeout.connect(self.set_system_info)
        self.internet_timer.start(5000)  # Refresh every 5 seconds

        # Create/Delete buttons in a single horizontal layout
        buttons_layout = QtWidgets.QHBoxLayout()
        buttons_layout.addWidget(self.create_folder_btn)
        buttons_layout.addWidget(self.delete_folder_btn)
        buttons_layout.addWidget(self.barcode_button)
        buttons_layout.addWidget(self.delete_barcode_button)
        buttons_layout.addWidget(self.private_browser)
        layout.addLayout(buttons_layout)

        #Another horizontal layout
        additional_buttons_layout = QtWidgets.QHBoxLayout()
        additional_buttons_layout.addWidget(self.kms_exclude_btn)
        additional_buttons_layout.addWidget(self.keyboard_test_btn)
        additional_buttons_layout.addWidget(self.shutdown_btn)
        additional_buttons_layout.addWidget(self.restart_btn)
        additional_buttons_layout.addWidget(self.camera_button)
        additional_buttons_layout.addWidget(self.clean_footprint)
        layout.addLayout(additional_buttons_layout)

        #Main Body
        layout.addWidget(self.pc_info_text)
        layout.addWidget(self.refresh_info_btn)
        layout.addWidget(self.status_label)
        layout.addWidget(self.internet_status_label)
        layout.addWidget(self.exit_button)
        #Send final layout to window
        self.setLayout(layout)

    def set_system_info(self):
        system_info = get_system_info()
        self.pc_info_text.clear()
        for key, value in system_info.items():
            if isinstance(value, list):
                self.pc_info_text.append(f"{key}:")
                for item in value:
                    self.pc_info_text.append(f"  {item}")
            else:
                self.pc_info_text.append(f"{key}: {value}")
            # Extract serial number from the info dictionary - adjust for Barcode
                if key == 'S/N':
                    # Extract the serial number by removing HTML tags if present
                    self.serial_number = self.rm_span_element(value)

    def rm_span_element(self, value):
        # Remove HTML tags if present
        return re.sub('<[^<]+?>', '', value)

    def refresh_system_info(self):
        self.set_system_info()
        self.status_label.setText(s_text("System info refreshed", "green"))
        QTimer.singleShot(3000, self.clear_status_label)

    def clear_status_label(self):
        self.status_label.clear()

    # def create_tech_folder(self):
    #     desktop_path = os.path.join(os.path.join(os.environ['USERPROFILE']), 'Desktop')
    #     tech_folder_path = os.path.join(desktop_path, 'tech')

    #     try:
    #         # Create the 'tech' folder if it doesn't exist
    #         if not os.path.exists(tech_folder_path):
    #             os.makedirs(tech_folder_path)
    #             self.status_label.setText(s_text("Folder 'tech' created on the desktop.", "green"))

    #             # Add the 'tech' folder to Windows Defender exclusion list using the execute_powershell_command method
    #             exclusion_command = f"Add-MpPreference -ExclusionPath '{tech_folder_path}'"
    #             execute_powershell_command(exclusion_command)
    #             self.status_label.setText(s_text("Folder 'tech' added to exclusion list.", "green"))
    #         else:
    #             self.status_label.setText(s_text("Folder 'tech' already exists on the desktop.", "red"))

    #     except Exception as e:
    #         # Handle exceptions and display an error message window
    #         QtWidgets.QMessageBox.critical(self, "Error", f"Failed to execute command: {str(e)}")

    # def delete_tech_folder(self):
    #     desktop_path = os.path.join(os.path.join(os.environ['USERPROFILE']), 'Desktop')
    #     tech_folder_path = os.path.join(desktop_path, 'tech')

    #     try:
    #         if os.path.exists(tech_folder_path):
                
    #             open_files_processes = get_open_files_in_directory(tech_folder_path)

    #             if open_files_processes:
    #                 processes_list = "\n".join(open_files_processes)
    #                 QtWidgets.QMessageBox.critical(self, "Critical", f"The following programs \n{processes_list}\n have open files in the 'tech' folder:\n\nPlease close them before proceeding.")
    #                 return
                    
    #             shutil.rmtree(tech_folder_path)
    #             self.status_label.setText(s_text("Folder 'tech' deleted from the desktop.", "red"))

    #             # Remove the 'tech' folder from the Windows Defender exclusion list using the execute_powershell_command method
    #             remove_exclusion_command = f"Remove-MpPreference -ExclusionPath '{tech_folder_path}'"
    #             execute_powershell_command(remove_exclusion_command)
    #             self.status_label.setText(s_text("Folder 'tech' removed from exclusion list.", "red"))
    #         else:
    #             self.status_label.setText(s_text("Folder 'tech' does not exist on the desktop.", "white"))
            
    #     except Exception as e:
    #         # Handle exceptions and display an error message window
    #         QtWidgets.QMessageBox.critical(self, "Error", f"Failed to execute command: {str(e)}")

    def create_tech_folder(self):
        desktop_path = os.path.join(os.path.join(os.environ['USERPROFILE']), 'Desktop')
        tech_folder_path = os.path.join(desktop_path, 'tech')

        try:
            # Check if the 'tech' folder already exists
            if not os.path.exists(tech_folder_path):
                # Create the 'tech' folder
                os.makedirs(tech_folder_path)
                self.status_label.setText(s_text("Folder 'tech' created on the desktop.", "green"))

                # Add the 'tech' folder to Windows Defender exclusion list
                exclusion_command = f"Add-MpPreference -ExclusionPath '{tech_folder_path}'"
                execute_powershell_command(exclusion_command)
                self.status_label.setText(s_text("Folder 'tech' added to exclusion list.", "green"))
            else:
                self.status_label.setText(s_text("Folder 'tech' already exists on the desktop.", "red"))

        except Exception as e:
            # Display an error message if an exception occurs
            QtWidgets.QMessageBox.critical(self, "Error", f"Failed to create folder or add to exclusion list: {str(e)}")


    def delete_tech_folder(self):
        desktop_path = os.path.join(os.path.join(os.environ['USERPROFILE']), 'Desktop')
        tech_folder_path = os.path.join(desktop_path, 'tech')

        def remove_folder():
            if os.path.exists(tech_folder_path):
                try:
                    shutil.rmtree(tech_folder_path)
                    self.status_label.setText(s_text("Folder 'tech' deleted from the desktop.", "red"))
                except Exception as e:
                    raise RuntimeError(f"Failed to delete folder: {str(e)}")
            else:
                self.status_label.setText(s_text("Folder 'tech' does not exist on the desktop.", "white"))
        
        def remove_exclusion():
            try:
                remove_exclusion_command = f"Remove-MpPreference -ExclusionPath '{tech_folder_path}'"
                execute_powershell_command(remove_exclusion_command)
                self.status_label.setText(s_text("Folder 'tech' removed from exclusion list.", "red"))
            except Exception as e:
                raise RuntimeError(f"Failed to remove exclusion: {str(e)}")

        try:
            # Run folder deletion and exclusion removal in parallel
            with concurrent.futures.ThreadPoolExecutor() as executor:
                future_remove_folder = executor.submit(remove_folder)
                future_remove_exclusion = executor.submit(remove_exclusion)
                # Wait for both tasks to complete
                concurrent.futures.wait([future_remove_folder, future_remove_exclusion], return_when=concurrent.futures.ALL_COMPLETED)
        except Exception as e:
            # Display an error message if an exception occurs
            QtWidgets.QMessageBox.critical(self, "Error", f"Failed to delete folder or remove from exclusion list: {str(e)}")


    def kms_security_bypass(self):
        """Function to execute KMS security bypass commands."""
        command_list = [
            # Allow specific threat IDs in Windows Defender
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

            # Exclude specific paths from Windows Defender scanning
            "Add-MpPreference -ExclusionPath C:\\Windows\\KMSAutoS -Force",
            "Add-MpPreference -ExclusionPath C:\\Windows\\System32\\SppExtComObjHook.dll -Force",
            "Add-MpPreference -ExclusionPath C:\\Windows\\System32\\SppExtComObjPatcher.exe -Force",
            "Add-MpPreference -ExclusionPath C:\\Windows\\AAct_Tools -Force",
            "Add-MpPreference -ExclusionPath C:\\Windows\\AAct_Tools\\AAct_x64.exe -Force",
            "Add-MpPreference -ExclusionPath C:\\Windows\\AAct_Tools\\AAct_files\\KMSSS.exe -Force",
            "Add-MpPreference -ExclusionPath C:\\Windows\\AAct_Tools\\AAct_files -Force",
            "Add-MpPreference -ExclusionPath C:\\Windows\\KMS -Force"
        ]

        # Notify user that the KMS-related commands are being executed
        self.status_label.setText(s_text("Executing KMS-related PowerShell commands...", "black"))

        # Execute each KMS-related PowerShell command and log the results
        for cmd in command_list:
            try:
                logging.info(f"Executing command: {cmd}")
                execute_powershell_command(cmd)
                logging.info(f"Successfully executed: {cmd}")
            except Exception as e:
                error_message = f"Failed to execute command: {cmd}\nError: {str(e)}"
                logging.error(error_message)
                QtWidgets.QMessageBox.critical(self, "Critical Error", error_message)

        self.status_label.setText(s_text("KMS-related commands executed successfully.", "green"))

    def clean_system(self):
        """Function to execute system cleaning commands with identifiable keys."""
        clean_system_commands = {
            "Clear_Recent_Files_Folders": "$quickAccessPath = [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\\Windows\\Recent'); Remove-Item -Path \"$quickAccessPath\\*\" -Force -Recurse",
            "Clear_Explorer_History_AutomaticDestinations": "Remove-Item -Path \"$env:APPDATA\\Microsoft\\Windows\\Recent\\AutomaticDestinations\\*\" -Force",
            "Clear_Explorer_History_CustomDestinations": "Remove-Item -Path \"$env:APPDATA\\Microsoft\\Windows\\Recent\\CustomDestinations\\*\" -Force",
            "Clear_Jump_Lists": "Remove-Item -Path \"$env:APPDATA\\Microsoft\\Windows\\Recent\\*.*\" -Force -Recurse",
            "Clear_Recent_Applications_History": "Remove-ItemProperty -Path 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\UserAssist' -Name * -ErrorAction SilentlyContinue",
            "Clear_Prefetch": "Remove-Item -Path 'C:\\Windows\\Prefetch\\*' -Force",
            "Clear_Temporary_Files_USER": "Remove-Item -Path \"$env:TEMP\\*\" -Force -Recurse",
            "Clear_Temporary_Files_SYSTEM": "Remove-Item -Path \"$env:WINDIR\\Temp\\*\" -Force -Recurse",
            "Clear_Thumbnail_Cache": "Stop-Process -Name explorer -Force; Remove-Item -Path \"$env:LOCALAPPDATA\\Microsoft\\Windows\\Explorer\\thumbcache_*\" -Force; Start-Process explorer.exe",
            "Clear_Edge_History": "Remove-Item -Path \"$env:LOCALAPPDATA\\Microsoft\\Edge\\User Data\\Default\\History\" -Force",
            "Clear_Windows_Defender_Scans": "Remove-Item -Path \"$env:PROGRAMDATA\\Microsoft\\Windows Defender\\Scans\\History\\Store\\*\" -Force -Recurse",
            "Clear_Windows_Defender_Temp": "Remove-Item -Path \"$env:PROGRAMDATA\\Microsoft\\Windows Defender\\Scans\\History\\Results\\Resource\\*\" -Force -Recurse",
        }

        # Execute each system cleaning PowerShell command
        for key, cmd in clean_system_commands.items():
            self.status_label.setText(s_text(f"Executing: {key}", "black"))
            try:
                execute_powershell_command(cmd)
                self.status_label.setText(s_text(f"Done: {key}", "green"))
            except Exception as e:
                logging.error(f"Error executing {key}: {str(e)}")
                self.status_label.setText(s_text(f"Error during {key}. Check logs for details.", "red"))

    def open_duckduckgo_private(self):
        url = 'https://duckduckgo.com/'

        try:
            # Try to open Microsoft Edge in private mode
            subprocess.run(['start', 'msedge', '--inprivate', url], shell=True, check=True)
        except subprocess.CalledProcessError:
            # If Edge fails, try other browsers in order with their private mode flags
            browsers = {
                'firefox': ['start', 'firefox', '-private-window', url],
                'chrome': ['start', 'chrome', '--incognito', url],
                'safari': ['open', '-a', 'Safari', '--args', '-private', url]
            }
            
            for browser, command in browsers.items():
                try:
                    subprocess.run(command, shell=True, check=True)
                    return
                except subprocess.CalledProcessError:
                    continue

            # If none of the specific browsers work, try to open the default browser in private mode
            try:
                webbrowser.get().open(url, new=2, autoraise=True)
            except Exception as e:
                QtWidgets.QMessageBox.critical(self, "Error", f"Failed to open browser: {str(e)}")
    
    def confirm_shutdown(self):
        reply = QtWidgets.QMessageBox.question(
            self, 
            'Confirm Shutdown', 
            "Shut down the system?", 
            QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No, 
            QtWidgets.QMessageBox.Yes # default
        )
        if reply == QtWidgets.QMessageBox.Yes:
            self.fast_shutdown()

    def fast_shutdown(self):
        subprocess.run(['shutdown', '/s', '/f', '/t', '0'], shell=True)

    def confirm_restart(self):
        reply = QtWidgets.QMessageBox.question(
            self, 
            'Confirm Restart', 
            "Restart the system?", 
            QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No, 
            QtWidgets.QMessageBox.Yes # default
        )
        if reply == QtWidgets.QMessageBox.Yes:
            self.fast_restart()

    def fast_restart(self):
        subprocess.run(['shutdown', '/r', '/f', '/t', '0'], shell=True)
        
    def check_internet_connection(self):
        try:
            # Check internet connectivity by attempting to connect to a common DNS server (Google's)
            socket.create_connection(("8.8.8.8", 53), timeout=2)
            self.internet_status_label.setText(s_text("Connected to the Internet","green"))
        except OSError:
            self.internet_status_label.setText(s_text("Not Connected to the Internet","red"))

    def closeEvent(self, event):
        # Ensure all cameras are closed when the main window is closed
        if hasattr(self, 'timer'):
            self.timer.stop()
        if hasattr(self, 'cameras'):
            self.close_all_cameras(self.cameras)
        event.accept()

    def generate_barcode(self):
        try:
            if not self.serial_number or self.serial_number == "SerialNumber not found":
                self.status_label.setText(s_text("Serial number not found. Cannot generate barcode.", "red"))
                return

            EAN = barcode.get_barcode_class('code128')
            ean = EAN(self.serial_number, writer=ImageWriter())
            filename = os.path.join(os.path.expanduser("~"), "Desktop", f"{self.serial_number}_barcode.png")

            # Check if the file already exists
            if not os.path.exists(filename):
                ean.save(filename[:-4])  # Remove the .png from the filename before saving
                self.status_label.setText(s_text(f"Barcode saved to {filename}", "green"))
            else:
                self.status_label.setText(s_text(f"Barcode already exists at {filename}", "red"))

            # Briefly delay to ensure the file system catches up
            time.sleep(0.5)

            # Open the image after saving or if it already exists
            self.show_image(filename)

        except Exception as e:
            self.status_label.setText(s_text(f"Failed to generate barcode: {str(e)}", "red"))

    def delete_barcode(self):
        try:
            filename = os.path.join(os.path.expanduser("~"), "Desktop", f"{self.serial_number}_barcode.png")

            if os.path.exists(filename):
                os.remove(filename)
                self.status_label.setText(s_text(f"Barcode deleted: {filename}", "green"))
            else:
                self.status_label.setText(s_text("Barcode file does not exist.", "red"))

        except Exception as e:
            self.status_label.setText(s_text(f"Failed to delete barcode: {str(e)}", "red"))

    def open_executable(self, name):
        # Get the current directory of the script
        current_dir = os.path.dirname(os.path.abspath(__file__))

        # Define the path to the executable
        exe_path = os.path.join(current_dir, name)

        # Check if the file exists
        if os.path.exists(exe_path):
            try:
                # Open the executable
                subprocess.run([exe_path], check=True)
            except subprocess.CalledProcessError as e:
                self.status_label.setText(s_text(f"Failed to open the executable: {e}", "black"))
            except Exception as e:
                QtWidgets.QMessageBox.critical(self, "Error", f"Failed : {str(e)}")
        else:
            QtWidgets.QMessageBox.critical(self, "Error", "Executable not found.")
    
    def display_all_cameras(self):
        self.cameras = []  # Reset the camera list
        index = 0

        # Search for all available cameras
        while True:
            cap = cv2.VideoCapture(index)
            if not cap.isOpened():
                cap.release()
                break
            self.cameras.append(cap)
            index += 1

        if len(self.cameras) == 0:
            print("No cameras found.")
            return

        print(f"{len(self.cameras)} camera(s) found. Opening...")

        # Timer to update frames
        self.timer = QtCore.QTimer(self)
        self.timer.timeout.connect(self.update_frames)
        self.timer.start(30)  # Update every 30 ms

    def update_frames(self):
        for i, cap in enumerate(self.cameras):
            ret, frame = cap.read()
            if not ret:
                continue

            # Display the frame in a window specific to this camera
            cv2.imshow(f"Camera {i}", frame)

            # Check if the window was closed by the user (X button)
            if cv2.getWindowProperty(f"Camera {i}", cv2.WND_PROP_VISIBLE) < 1:
                self.close_all_cameras()
                return

        # Check if 'q' is pressed to quit the camera loop
        if cv2.waitKey(1) & 0xFF == ord('q'):
            self.close_all_cameras()

    def close_all_cameras(self):
        # Stop the timer if it's running
        if self.timer:
            self.timer.stop()

        # Release all the camera resources
        for cap in self.cameras:
            cap.release()

        # Close all OpenCV windows
        cv2.destroyAllWindows()

        # Clear the camera list
        self.cameras = []

    #mouse event main window > make sure window with a custom topbar move when pressed 
    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self.old_pos = event.globalPos()

    def mouseMoveEvent(self, event):
        delta = QtCore.QPoint(event.globalPos() - self.old_pos)
        self.move(self.x() + delta.x(), self.y() + delta.y())
        self.old_pos = event.globalPos()

    def show_image(self, image_path):
        self.image_window = ImageWindow(image_path, parent=self)
        self.image_window.show()
    
    def closeEvent(self, event):
        """Ensure all cameras are closed when the main window is closed."""
        self.close_all_cameras()
        event.accept()

def main():
    #Make sure app only start if run as admin 
    if not ctypes.windll.shell32.IsUserAnAdmin():
        QtWidgets.QMessageBox.critical(None, "Error", "Requires administrative privileges.")
        return

    app = QtWidgets.QApplication(sys.argv)
    main_window = MainWindow()
    # Ensure that when the main window is closed, the whole application exits
    main_window.show()

    sys.exit(app.exec_())
if __name__ == "__main__":
    main()


# pyinstaller --onefile --windowed --add-data="icon_info.ico;." --icon=icon_info.ico --name="#info" --version-file="version_info.txt" QtGUI_WinLowEnd.py