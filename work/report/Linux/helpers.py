import json
from PyQt6.QtWidgets import QMessageBox, QWidget

class MessageHelper(QWidget):
    def show_message(self, title: str, message: str):
        """Show an informational message box."""
        QMessageBox.information(self, title, message, QMessageBox.StandardButton.Ok)

    def show_warning(self, title: str, message: str):
        """Show a warning message box."""
        QMessageBox.warning(self, title, message, QMessageBox.StandardButton.Ok)

    def show_error(self, title: str, message: str):
        """Show an error message box."""
        QMessageBox.critical(self, title, message, QMessageBox.StandardButton.Ok)

    def show_confirmation(self, title: str, message: str) -> bool:
        """Show a confirmation dialog and return True if the user clicks 'Yes'."""
        reply = QMessageBox.question(self, title, message, 
                                     QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No, 
                                     QMessageBox.StandardButton.No)
        return reply == QMessageBox.StandardButton.Yes
    
    def show_duplicate_dialog(self, machine_sn: str, new_bios: str, duplicates: dict, new_record: dict) -> str:
        """
        Show a duplicate dialog with details and return the user's choice:
        "Merge", "Add New", or "Cancel".
        """
        msg_box = QMessageBox(self)
        msg_box.setIcon(QMessageBox.Icon.Warning)
        msg_box.setWindowTitle("Duplicate Entry Detected")
        duplicate_text = json.dumps(duplicates, indent=4)
        msg_box.setText(
            f"Duplicate record(s) found for Machine S/N '{machine_sn}' or BIOS S/N '{new_bios}'."
        )
        comparison_text = (
            f"Existing Duplicate Data:\n{duplicate_text}\n\n"
            f"New Data:\n{json.dumps(new_record, indent=4)}\n\n"
            "Choose 'Merge' to combine these records, 'Add New' to keep them separate, or 'Cancel' to abort."
        )
        msg_box.setInformativeText(comparison_text)

        # Add action buttons
        merge_button = msg_box.addButton("Merge", QMessageBox.ButtonRole.AcceptRole)
        add_new_button = msg_box.addButton("Add New", QMessageBox.ButtonRole.RejectRole)
        cancel_button = msg_box.addButton("Cancel", QMessageBox.ButtonRole.DestructiveRole)

        msg_box.exec()

        if msg_box.clickedButton() == merge_button:
            return "Merge"
        elif msg_box.clickedButton() == add_new_button:
            return "Add New"
        elif msg_box.clickedButton() == cancel_button:
            return "Cancel"
        else:
            return "Cancel"