import json
import os
import subprocess
import glob

def get_machine_serial():
    """Fetch the system's machine serial number using Linux methods."""
    # First attempt: Read from the sysfs entry (usually available on most Linux systems)
    try:
        with open("/sys/class/dmi/id/product_serial", "r") as f:
            machine_sn = f.read().strip()
            if machine_sn and machine_sn.lower() not in ["", "unknown", "none"]:
                return machine_sn
    except Exception:
        pass

    # Fallback: Use dmidecode command (may require sudo)
    try:
        machine_sn = subprocess.check_output("sudo dmidecode -s system-serial-number", shell=True).decode().strip()
        if machine_sn and machine_sn.lower() not in ["", "unknown", "none"]:
            return machine_sn
    except Exception:
        pass
    # Read from the sysfs entry for product_uuid as an alternative
    try:
        with open("/sys/class/dmi/id/product_uuid", "r") as f:
            machine_uuid = f.read().strip()
            if machine_uuid and machine_uuid.lower() not in ["", "unknown", "none"]:
                return machine_uuid
    except Exception:
        pass


    return "Unknown"

def get_disk_serial():
    """Fetch the primary disk's serial number."""
    # First attempt: Read from sysfs for the first disk (commonly /dev/sda)
    try:
        with open("/sys/block/sda/device/serial", "r") as f:
            disk_sn = f.read().strip()
            if disk_sn:
                return disk_sn
    except Exception:
        pass

    # Fallback: Use udevadm to query the device properties
    try:
        output = subprocess.check_output("udevadm info --query=property --name=/dev/sda", shell=True).decode()
        for line in output.splitlines():
            if line.startswith("ID_SERIAL="):
                disk_sn = line.split("=", 1)[1].strip()
                if disk_sn:
                    return disk_sn
    except Exception:
        pass

    return "Unknown"

def get_ram_serial():
    """Fetch serial numbers for all installed RAM modules using dmidecode."""
    try:
        # dmidecode -t memory prints out details for all memory devices.
        output = subprocess.check_output("sudo dmidecode -t memory", shell=True).decode()
        ram_serials = []
        for line in output.splitlines():
            line = line.strip()
            if line.startswith("Serial Number:"):
                serial = line.split(":", 1)[1].strip()
                if serial and serial.lower() not in ["not installed", "none", ""]:
                    ram_serials.append(serial)
        if ram_serials:
            return ", ".join(ram_serials)
    except Exception:
        pass
    return "Unknown"

def get_battery_serial():
    """Fetch battery serial number if available (for laptops)."""
    # Look for battery information directories (often named BAT0, BAT1, etc.)
    battery_paths = glob.glob("/sys/class/power_supply/BAT*")
    for bat in battery_paths:
        serial_path = os.path.join(bat, "serial_number")
        if os.path.exists(serial_path):
            try:
                with open(serial_path, "r") as f:
                    battery_sn = f.read().strip()
                    if battery_sn:
                        return battery_sn
            except Exception:
                pass
    return "Unknown"

def get_serial_numbers():
    """Fetch machine, disk, RAM, and battery serial numbers."""
    machine_sn = get_machine_serial()
    disk_sn = get_disk_serial()
    ram_sn = get_ram_serial()
    battery_sn = get_battery_serial()
    return machine_sn, disk_sn, ram_sn, battery_sn

def save_to_json():
    """Prompts for a client name, gathers system serial numbers, ensures uniqueness, and saves to a JSON file."""
    client_name = input("Enter Client Name: ").strip()
    machine_sn, disk_sn, ram_sn, battery_sn = get_serial_numbers()

    json_file = "client_system_info.json"

    # Load existing data if the JSON file exists
    if os.path.exists(json_file):
        with open(json_file, "r") as file:
            try:
                existing_data = json.load(file)
            except json.JSONDecodeError:
                existing_data = {}
    else:
        existing_data = {}

    # Ensure the client entry exists in the JSON data
    if client_name not in existing_data:
        existing_data[client_name] = {}

    # Prevent duplicate machine serial numbers for the same client
    if machine_sn in existing_data[client_name]:
        print(f"⚠ Warning: Machine S/N '{machine_sn}' already exists for client '{client_name}'. Not adding a duplicate entry.")
        return

    # Handle ambiguous serial numbers (like "Unknown") by appending a counter
    if machine_sn.lower() in ["unknown", "restricted"]:
        base_sn = machine_sn
        counter = 1
        while f"{base_sn}+{counter}" in existing_data[client_name]:
            counter += 1
        machine_sn = f"{base_sn}+{counter}"

    # Add the new machine entry
    existing_data[client_name][machine_sn] = {
        "Disk S/N": disk_sn,
        "RAM S/N": ram_sn,
        "Battery S/N": battery_sn
    }

    # Save updated data to the JSON file
    with open(json_file, "w") as file:
        json.dump(existing_data, file, indent=4)

    # Display fetched system information
    print("\n✅ **System Information Saved:**")
    print(f"🖥  Machine S/N:  {machine_sn}")
    print(f"💾 Disk S/N:     {disk_sn}")
    print(f"🧠 RAM S/N:      {ram_sn}")
    print(f"🔋 Battery S/N:  {battery_sn}\n")
    print(f"✅ Data successfully saved to '{json_file}'.")

if __name__ == "__main__":
    save_to_json()
