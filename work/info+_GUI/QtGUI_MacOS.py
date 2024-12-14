import os
import platform
import psutil
import ctypes
import sys
from PyQt5 import QtWidgets, QtGui

import GPUtil

def get_system_info():
    info = {}
    info['MacOS Version'] = platform.mac_ver()[0]
    info['Total RAM'] = f"{round(psutil.virtual_memory().total / (1024**3))} GB"
    
    # Disk information
    disk_info = []
    for disk in psutil.disk_partitions():
        if 'rw' in disk.opts:  # Read-write partitions
            usage = psutil.disk_usage(disk.mountpoint)
            disk_info.append(f"{disk.device} - {round(usage.total / (1024**3))} GB")
    info['Disks'] = disk_info

    # CPU information
    cpu_name = platform.processor()
    cpu_cores = psutil.cpu_count(logical=False)
    cpu_threads = psutil.cpu_count(logical=True)
    cpu_max_speed = psutil.cpu_freq().max
    info['CPU'] = (
        f"{cpu_name}\n"
        f" {cpu_max_speed / 1000:.2f} GHz, {cpu_cores} Core(s), \n"
        f"{cpu_threads} Logical Processor(s)".splitlines()
    )

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
    desktop_path = os.path.join(os.path.expanduser('~'), 'Desktop')
    tech_folder_path = os.path.join(desktop_path, 'tech')

    if not os.path.exists(tech_folder_path):
        os.makedirs(tech_folder_path)
        QtWidgets.QMessageBox.information(None, "Info", "Folder 'tech' created on the desktop.")
    else:
        QtWidgets.QMessageBox.information(None, "Info", "Folder 'tech' already exists on the desktop.")

def delete_tech_folder():
    desktop_path = os.path.join(os.path.expanduser('~'), 'Desktop')
    tech_folder_path = os.path.join(desktop_path, 'tech')

    if os.path.exists(tech_folder_path):
        os.rmdir(tech_folder_path)
        QtWidgets.QMessageBox.information(None, "Info", "Folder 'tech' deleted from the desktop.")
    else:
        QtWidgets.QMessageBox.information(None, "Info", "Folder 'tech' does not exist on the desktop.")

class MainWindow(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()

        self.initUI()

    def initUI(self):
        self.setWindowTitle("Tech Folder Management")
        self.setGeometry(100, 100, 800, 600)

        layout = QtWidgets.QVBoxLayout()

        self.info_text = QtWidgets.QTextEdit(self)
        self.info_text.setReadOnly(True)
        self.info_text.setFont(QtGui.QFont('Courier', 10))
        self.info_text.setStyleSheet("background-color: black; color: white;")
        layout.addWidget(self.info_text)

        self.update_info_button = QtWidgets.QPushButton("Update System Info", self)
        self.update_info_button.clicked.connect(self.update_system_info)
        layout.addWidget(self.update_info_button)

        self.create_button = QtWidgets.QPushButton("Create 'tech' folder", self)
        self.create_button.setStyleSheet("background-color: green; color: white;")
        self.create_button.clicked.connect(create_tech_folder)
        layout.addWidget(self.create_button)

        self.delete_button = QtWidgets.QPushButton("Delete 'tech' folder", self)
        self.delete_button.setStyleSheet("background-color: red; color: white;")
        self.delete_button.clicked.connect(delete_tech_folder)
        layout.addWidget(self.delete_button)

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

def main():
    app = QtWidgets.QApplication(sys.argv)
    main_window = MainWindow()
    main_window.show()
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
