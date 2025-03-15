import json
from PyQt6.QtWidgets import QComboBox, QMessageBox

from helpers import MessageHelper

class DataHandle:
    """Class containing setup utilities for client data management."""
    json_file = "client_system_info.json"
    @staticmethod
    def load_existing_clients(json_file: str, client_dropdown: QComboBox):
        """Load existing clients from a JSON file and populate a dropdown."""
        try:
            with open(json_file, "r") as file:
                data = json.load(file)
                for client in data.keys():
                    client_dropdown.addItem(client)
        except (FileNotFoundError, json.JSONDecodeError):
            pass  # No existing data or invalid JSON format

    @staticmethod
    def load_client_data(json_file: str):
        """Load existing client data from the JSON file."""
        try:
            with open(json_file, "r") as file:
                return json.load(file)
        except (FileNotFoundError, json.JSONDecodeError):
            return {}

    @staticmethod
    def save_client_data(json_file: str, client_name: str, new_record: dict):
        """Save client data to the JSON file with duplicate handling."""
        existing_data = DataHandle.load_client_data(json_file)

        if client_name not in existing_data:
            existing_data[client_name] = {}

        # Extract the machine serial from the new_record dictionary (there should be only one key)
        machine_sn = list(new_record.keys())[0]

        if machine_sn in existing_data[client_name]:
            # Duplicate found – check and handle duplicates.
            return DataHandle.check_duplicate_and_handle(json_file, client_name, machine_sn, new_record[machine_sn], existing_data)
        else:
            # No duplicate found; simply add the record.
            existing_data[client_name][machine_sn] = new_record[machine_sn]
            with open(json_file, "w") as file:
                json.dump(existing_data, file, indent=4)
            return "Ok"

    @staticmethod
    def check_duplicate_and_handle(json_file: str, client_name: str, machine_sn: str, new_record: dict, existing_data: dict):
        """
        Check if a record with the same machine serial number or BIOS serial number exists.
        - If the record is in the same client, a match on either machine_sn or BIOS S/N triggers a duplicate.
        - If the record is in a different client, both machine_sn and BIOS S/N must match to trigger a duplicate.
        If duplicates are found, show them in a table and ask the user whether to merge or add new.
        """
        duplicates = {}
        new_bios = new_record.get("BIOS S/N", None)

        # Loop over every client and every machine record in the existing data.
        for ex_client, machines in existing_data.items():
            for ex_machine_sn, record in machines.items():
                # For the same client: trigger duplicate if either field matches.
                if ex_client == client_name:
                    condition = (ex_machine_sn == machine_sn) or (new_bios and record.get("BIOS S/N") == new_bios)
                else:
                    # For a different client, both machine_sn and BIOS S/N must match.
                    condition = (ex_machine_sn == machine_sn) and (new_bios is not None and record.get("BIOS S/N") == new_bios)
                
                if condition:
                    if ex_client not in duplicates:
                        duplicates[ex_client] = {}
                    duplicates[ex_client][ex_machine_sn] = record

        if duplicates:
            message_helper = MessageHelper()
            # Show duplicates in a table and ask the user for an action.
            result = message_helper.show_duplicate_dialog(machine_sn, new_bios, duplicates, new_record)
            if result == "Merge":
                return DataHandle.merge_records(json_file, client_name, machine_sn, duplicates, new_record, existing_data)
            elif result == "Add New":
                if message_helper.confirm("Confirm Add New", "Duplicates were found. Do you really want to add this as a new entry?"):
                    return DataHandle.add_new_record(json_file, client_name, machine_sn, new_record, existing_data)
                else:
                    return "Cancelled"
            else:
                return "Cancelled"
        else:
            # No duplicates found, add record directly.
            return DataHandle.add_new_record(json_file, client_name, machine_sn, new_record, existing_data)

    @staticmethod
    def merge_records(json_file: str, client_name: str, machine_sn: str, duplicates: dict, new_record: dict, existing_data: dict):
        """
        Merge all duplicate records with the new record. Previous duplicate entries will be overwritten.
        """
        merged_record = {}

        def merge_into(merged, record):
            for key, value in record.items():
                if key not in merged or merged[key] == "Unknown":
                    merged[key] = value
                else:
                    if value not in merged[key]:
                        merged[key] = f"{merged[key]}, {value}"

        for dup_client, machines in duplicates.items():
            for dup_machine, record in machines.items():
                merge_into(merged_record, record)
        merge_into(merged_record, new_record)

        # Remove all duplicates and add the merged record.
        for dup_client, machines in duplicates.items():
            for dup_machine in list(machines.keys()):
                del existing_data[dup_client][dup_machine]
        existing_data[client_name][machine_sn] = merged_record

        with open(json_file, "w") as file:
            json.dump(existing_data, file, indent=4)
        return "Merged"

    @staticmethod
    def add_new_record(json_file: str, client_name: str, machine_sn: str, new_record: dict, existing_data: dict):
        """Add a new entry for the machine serial number, ensuring uniqueness if needed."""
        if machine_sn.lower() in ["unknown", "restricted by bios"]:
            base_sn = machine_sn
            counter = 1
            while f"{base_sn}+{counter}" in existing_data[client_name]:
                counter += 1
            machine_sn = f"{base_sn}+{counter}"

        existing_data[client_name][machine_sn] = new_record

        with open(json_file, "w") as file:
            json.dump(existing_data, file, indent=4)
        return "Add New"

