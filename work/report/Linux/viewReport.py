import sys
import json
from PyQt6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QLineEdit, QPushButton, 
    QTableWidget, QTableWidgetItem, QHBoxLayout
)
from PyQt6.QtCore import Qt
from addReport import AddReport  # Import AddReport class

class ViewReport(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Client System Info Viewer")

        # Layout
        main_layout = QVBoxLayout()

        # Search Bar, Refresh Button & Add Report Button
        button_layout = QHBoxLayout()
        self.search_bar = QLineEdit()
        self.search_bar.setPlaceholderText("Search by any field (Client, Machine S/N, Disk, RAM, Battery)...")
        self.search_bar.textChanged.connect(self.filter_data)

        self.refresh_button = QPushButton("Refresh")
        self.refresh_button.clicked.connect(self.load_data)

        self.add_report_button = QPushButton("Add Report")
        self.add_report_button.clicked.connect(self.run_add_report)  # Opens AddReport window

        button_layout.addWidget(self.search_bar)
        button_layout.addWidget(self.refresh_button)
        button_layout.addWidget(self.add_report_button)
        main_layout.addLayout(button_layout)

        # Table Widget
        self.table = QTableWidget()
        self.table.setColumnCount(11)
        self.table.setHorizontalHeaderLabels([
            "Client",
            "Machine S/N",
            "Disk S/N",
            "RAM S/N",
            "Battery S/N",
            "CPU S/N",
            "BIOS S/N",
            "GPU S/N",
            "NIC S/N",
            "Power S/N",
            "Display S/N"
        ])
        self.table.setSortingEnabled(True)
        self.table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        main_layout.addWidget(self.table)

        self.setLayout(main_layout)

        # Load JSON Data
        self.load_data()

    def load_data(self):
        """ Load JSON file and display it in the table, auto-resize columns """
        self.table.setRowCount(0)  # Clear table before loading
        try:
            with open("client_system_info.json", "r") as file:
                data = json.load(file)

            row = 0
            for client, machines in data.items():
                for machine_sn, details in machines.items():
                    self.table.insertRow(row)
                    # Column 0: Client
                    self.table.setItem(row, 0, QTableWidgetItem(client))
                    # Column 1: Machine S/N
                    self.table.setItem(row, 1, QTableWidgetItem(machine_sn))
                    # Column 2: Disk S/N
                    self.table.setItem(row, 2, QTableWidgetItem(details.get("Disk S/N", "Unknown")))
                    # Column 3: RAM S/N
                    self.table.setItem(row, 3, QTableWidgetItem(details.get("RAM S/N", "Unknown")))
                    # Column 4: Battery S/N
                    self.table.setItem(row, 4, QTableWidgetItem(details.get("Battery S/N", "Unknown")))
                    # Column 5: CPU S/N
                    self.table.setItem(row, 5, QTableWidgetItem(details.get("CPU S/N", "Unknown")))
                    # Column 6: BIOS S/N
                    self.table.setItem(row, 6, QTableWidgetItem(details.get("BIOS S/N", "Unknown")))
                    # Column 7: GPU S/N
                    self.table.setItem(row, 7, QTableWidgetItem(details.get("GPU S/N", "Unknown")))
                    # Column 8: NIC S/N
                    self.table.setItem(row, 8, QTableWidgetItem(details.get("NIC S/N", "Unknown")))
                    # Column 9: Power S/N
                    self.table.setItem(row, 9, QTableWidgetItem(details.get("Power S/N", "Unknown")))
                    # Column 10: Display S/N
                    self.table.setItem(row, 10, QTableWidgetItem(details.get("Display S/N", "Unknown")))
                    row += 1

            # Auto-resize columns to fit content
            self.table.resizeColumnsToContents()
            self.adjust_window_size()

        except (FileNotFoundError, json.JSONDecodeError):
            self.table.setRowCount(0)  # Clear table if file is missing/corrupt


    def adjust_window_size(self):
        """ Adjusts the window size to fit the table contents """
        self.table.resizeColumnsToContents()  # Make columns fit content
        width = sum(self.table.columnWidth(i) for i in range(self.table.columnCount())) + 50
        height = (self.table.rowHeight(0) * (self.table.rowCount() + 2)) + 100
        self.resize(width, height)

    def filter_data(self):
        """ Filter table content based on search bar input (supports spaces and multiple words) """
        filter_text = self.search_bar.text().strip().lower()
        words = filter_text.split()  # Allows searching multiple words in any order

        for row in range(self.table.rowCount()):
            row_text = " ".join([self.table.item(row, col).text().lower() for col in range(self.table.columnCount()) if self.table.item(row, col)])
            match = all(word in row_text for word in words)  # Check if all words exist in any column
            self.table.setRowHidden(row, not match)

    def run_add_report(self):
        """ Opens the AddReport window """
        self.add_report_window = AddReport()
        self.add_report_window.show()


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = ViewReport()
    window.show()
    sys.exit(app.exec())
