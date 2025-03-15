import ast
import json
import re
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QLabel, QLineEdit, QPushButton, QComboBox, QCompleter, QMessageBox
)
from PyQt6.QtCore import Qt
from hardware_info import HardwareInfo  
from data_handle import DataHandle
from helpers import MessageHelper

class AddReport(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Add Machine Warranty Check")
        self.setGeometry(300, 200, 400, 350)

        # Layout
        layout = QVBoxLayout()

        # Dropdown + Search Autocomplete
        self.client_label = QLabel("Select or Enter Client Name:")
        layout.addWidget(self.client_label)

        self.client_dropdown = QComboBox(self)
        self.client_dropdown.setEditable(True)
        self.client_dropdown.setInsertPolicy(QComboBox.InsertPolicy.InsertAlphabetically)
        layout.addWidget(self.client_dropdown)

        self.json_file = DataHandle.json_file
        DataHandle.load_existing_clients(self.json_file, self.client_dropdown)

        # Autocomplete for dropdown list
        self.completer = QCompleter(self.client_dropdown.model(), self)
        self.completer.setCompletionMode(QCompleter.CompletionMode.PopupCompletion)
        self.client_dropdown.setCompleter(self.completer)

        # Serial Number Labels (Auto-Populated)
        self.machine_label = QLabel("Machine S/N:")
        self.machine_sn = QLineEdit(self)
        self.machine_sn.setReadOnly(False)
        layout.addWidget(self.machine_label)
        layout.addWidget(self.machine_sn)
        
        self.bios_label = QLabel("Bios S/N:")
        self.bios_sn = QLineEdit(self)
        self.bios_sn.setReadOnly(True)
        layout.addWidget(self.bios_label)
        layout.addWidget(self.bios_sn)

        self.disk_label = QLabel("Disk S/N:")
        self.disk_sn = QLineEdit(self)
        self.disk_sn.setReadOnly(True)
        layout.addWidget(self.disk_label)
        layout.addWidget(self.disk_sn)

        self.ram_label = QLabel("RAM S/N:")
        self.ram_sn = QLineEdit(self)
        self.ram_sn.setReadOnly(True)
        layout.addWidget(self.ram_label)
        layout.addWidget(self.ram_sn)

        self.display_label = QLabel("Display S/N:")
        self.display_sn = QLineEdit(self)
        self.display_sn.setReadOnly(True)
        layout.addWidget(self.display_label)
        layout.addWidget(self.display_sn)
        
        self.cpu_label = QLabel("CPU S/N:")
        self.cpu_sn = QLineEdit(self)
        self.cpu_sn.setReadOnly(True)
        layout.addWidget(self.cpu_label)
        layout.addWidget(self.cpu_sn)
        
        self.gpu_label = QLabel("GPU S/N:")
        self.gpu_sn = QLineEdit(self)
        self.gpu_sn.setReadOnly(True)
        layout.addWidget(self.gpu_label)
        layout.addWidget(self.gpu_sn)
        
        
        self.nic_label = QLabel("NIC S/N:")
        self.nic_sn = QLineEdit(self)
        self.nic_sn.setReadOnly(True)
        layout.addWidget(self.nic_label)
        layout.addWidget(self.nic_sn)
        
        self.power_supply_label = QLabel("Power S/N:")
        self.power_supply_sn = QLineEdit(self)
        self.power_supply_sn.setReadOnly(True)
        layout.addWidget(self.power_supply_label)
        layout.addWidget(self.power_supply_sn)
        
        self.battery_label = QLabel("Battery S/N:")
        self.battery_sn = QLineEdit(self)
        self.battery_sn.setReadOnly(True)
        layout.addWidget(self.battery_label)
        layout.addWidget(self.battery_sn)
        

        # Submit Button
        self.submit_button = QPushButton("Submit", self)
        self.submit_button.clicked.connect(self.submit_data)
        layout.addWidget(self.submit_button)

        # Set layout
        self.setLayout(layout)

        # Auto-fill serial numbers on startup
        self.fill_serial_numbers()

    def _format_value(self, value):
        """
        Format a value for display.
        If the value is a dictionary (e.g., for NIC, Power, or Display serials),
        join its key–value pairs into a multi-line string.
        """
        if isinstance(value, dict):
            return "\n".join([f"{k}: {v}" for k, v in value.items()])
        return str(value)


    def fill_serial_numbers(self):
        """Auto-fill serial number fields using the HardwareInfo class."""
        serials_json = HardwareInfo.get_serial_numbers()
        serials = json.loads(serials_json)  # Convert JSON string back to dict
        
        self.machine_sn.setText(serials.get("Machine S/N", "N/A"))
        
        disk_sn_value = serials.get("Disk S/N", "N/A")
        # Check if the value is a list and convert it to a string if so
        if isinstance(disk_sn_value, list):
            disk_sn_value = ", ".join(disk_sn_value)
            
        self.disk_sn.setText(disk_sn_value)
        
        ram_sn_value = serials.get("RAM S/N", "N/A")
        # Check if the value is a list and convert it to a string if so
        if isinstance(ram_sn_value, list):
            ram_sn_value = ", ".join(ram_sn_value)
            
        self.ram_sn.setText(ram_sn_value)
        
        self.cpu_sn.setText(serials.get("CPU S/N", "N/A"))
        self.bios_sn.setText(serials.get("BIOS S/N", "N/A"))
        self.gpu_sn.setText(serials.get("GPU S/N", "N/A"))
        
        nic_value = serials.get("NIC S/N", "N/A")
        nic_value = ", ".join(str(value) for value in nic_value.values())
        self.nic_sn.setText(nic_value)
        
        self.battery_sn.setText(serials.get("Battery S/N", "N/A"))
        self.power_supply_sn.setText(serials.get("Power S/N", "N/A"))
        
        display_value = serials.get("Display S/N", "N/A")
        display_value = ", ".join(f"{v}" for k, v in display_value.items())
        self.display_sn.setText(display_value)


    def submit_data(self):
        """Save the data to a JSON file, fetching data from the QtForm fields."""
        client_name = self.client_dropdown.currentText().strip()

        # Build a new_record dict where the key is the Machine S/N and its value holds the rest.
        new_record = {
            self.machine_sn.text().strip(): {
                "Disk S/N": self.disk_sn.text().strip(),
                "RAM S/N": self.ram_sn.text().strip(),
                "Battery S/N": self.battery_sn.text().strip(),
                "CPU S/N": self.cpu_sn.text().strip(),
                "BIOS S/N": self.bios_sn.text().strip(),
                "GPU S/N": self.gpu_sn.text().strip(),
                "NIC S/N": self.nic_sn.text().strip(),
                "Power S/N": self.power_supply_sn.text().strip(),
                "Display S/N": self.display_sn.text().strip()
            }
        }

        # Save data and capture the result from DataHandle (alias of SetupHelpers)
        result = DataHandle.save_client_data(self.json_file, client_name, new_record)
        helper = MessageHelper()
        match result:
            case "Ok":
                helper.show_message("Success", "✅ Data successfully saved!")
            case "Merged":
                helper.show_message("Merge Successful", "✅ Records have been merged successfully.")
            case "Add New":
                helper.show_message("Success", "✅ New record has been added!")
            case _:
                helper.show_error("Error", f"Unexpected result: {result}")

if __name__ == "__main__":
    from PyQt6.QtWidgets import QApplication
    import sys

    app = QApplication(sys.argv)
    window = AddReport()
    window.show()
    sys.exit(app.exec())
