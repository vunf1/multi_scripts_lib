import os
import platform
import subprocess
import glob
import hashlib
import json

class HardwareInfo:
    """Class to fetch various hardware serial numbers on Linux (and Windows for display)."""

    @staticmethod
    def get_machine_serial():
        """
        1. Read common DMI files (product_serial, product_uuid).
        2. Use dmidecode for system-serial-number.
        3. Read board_serial.
        4. Read chassis_serial.
        5. Use dmidecode for chassis-serial-number.
        6. Use dmidecode for baseboard-serial-number.
        """
        invalid_serials = {"", "unknown", "none", "system serial number",'default string'}
        
        # Method 1: Try standard DMI files.
        for path in ["/sys/class/dmi/id/product_serial", "/sys/class/dmi/id/product_uuid"]:
            try:
                with open(path, "r") as f:
                    sn = f.read().strip()
                    if sn and sn.lower() not in invalid_serials:
                        return sn
            except Exception:
                continue

        # Method 2: Use dmidecode for system-serial-number.
        try:
            sn = subprocess.check_output(
                "sudo dmidecode -s system-serial-number", shell=True
            ).decode().strip()
            if sn and sn.lower() not in invalid_serials:
                return sn
        except Exception:
            pass

        # Method 3: Try board serial.
        try:
            with open("/sys/class/dmi/id/board_serial", "r") as f:
                board_sn = f.read().strip()
                if board_sn and board_sn.lower() not in invalid_serials:
                    return board_sn
        except Exception:
            pass

        # Method 4: Try chassis serial from file.
        try:
            chassis_path = "/sys/class/dmi/id/chassis_serial"
            if os.path.exists(chassis_path):
                with open(chassis_path, "r") as f:
                    chassis_sn = f.read().strip()
                    if chassis_sn and chassis_sn.lower() not in invalid_serials:
                        return chassis_sn
        except Exception:
            pass

        # Method 5: Use dmidecode for chassis-serial-number.
        try:
            sn = subprocess.check_output(
                "sudo dmidecode -s chassis-serial-number", shell=True
            ).decode().strip()
            if sn and sn.lower() not in invalid_serials:
                return sn
        except Exception:
            pass

        # Method 6: Use dmidecode for baseboard-serial-number.
        try:
            sn = subprocess.check_output(
                "sudo dmidecode -s baseboard-serial-number", shell=True
            ).decode().strip()
            if sn and sn.lower() not in invalid_serials:
                return sn
        except Exception:
            pass

        return "Unknown"

    @staticmethod
    def get_bios_serial():
        """
        1. Read from /sys/class/dmi/id/bios_serial.
        2. Parse 'sudo dmidecode -t bios' output for a line starting with "Serial Number:".
        3. Fallback – parse the same dmidecode output for a line starting with "Asset Tag:".
        4. Last resort – parse 'sudo dmidecode -t system' output for a line starting with "UUID:".
        
        Note:
        System UUID is typically stored in the firmware (usually on the motherboard). 
        As a result, swapping peripheral components (like RAM, hard drives, or even the CPU) usually doesn't affect the UUID. 
        However, if replace or update the motherboard or if the firmware is re-flashed, the UUID may change.
        """
        invalids = {"", "n/a", "unknown", "system serial number", "to be filled by o.e.m."}

        # Method 1: Read from /sys/class/dmi/id/bios_serial.
        bios_serial_path = "/sys/class/dmi/id/bios_serial"
        if os.path.exists(bios_serial_path):
            try:
                with open(bios_serial_path, "r") as f:
                    serial = f.read().strip()
                    if serial and serial.lower() not in invalids:
                        return serial
            except Exception:
                pass

        # Method 2: Use dmidecode to parse BIOS info (Serial Number & Asset Tag) in one go.
        try:
            output = subprocess.check_output(
                "sudo dmidecode -t bios", shell=True, stderr=subprocess.DEVNULL
            ).decode()
            bios_serial = None
            asset_tag = None

            for line in output.splitlines():
                line = line.strip()
                if line.startswith("Serial Number:") and bios_serial is None:
                    candidate = line.split(":", 1)[1].strip()
                    if candidate and candidate.lower() not in invalids:
                        bios_serial = candidate
                elif line.startswith("Asset Tag:") and asset_tag is None:
                    candidate = line.split(":", 1)[1].strip()
                    if candidate and candidate.lower() not in invalids:
                        asset_tag = candidate

            if bios_serial:
                return bios_serial
            elif asset_tag:
                return asset_tag
        except Exception:
            pass

        # Method 3: Fallback – use system UUID as an identifier.
        try:
            output = subprocess.check_output(
                "sudo dmidecode -t system", shell=True, stderr=subprocess.DEVNULL
            ).decode()
            for line in output.splitlines():
                line = line.strip()
                if line.startswith("UUID:"):
                    candidate = line.split(":", 1)[1].strip()
                    # Ensure the candidate is valid.
                    if candidate and candidate.lower() not in invalids and candidate != "Not Specified":
                        return candidate
        except Exception:
            pass
    
    @staticmethod
    def get_disk_serials():
        """Fetch serial numbers for all non-USB disks in Linux."""
        disk_serials = []
        try:
            lsblk_output = subprocess.check_output(
                "lsblk -d -o NAME,TRAN", shell=True
            ).decode().splitlines()
            # Skip header line
            for line in lsblk_output[1:]:
                parts = line.split()
                if not parts:
                    continue
                name = parts[0]
                tran = parts[1].lower() if len(parts) > 1 else ""
                if tran == "usb":
                    continue

                serial = None
                serial_path = f"/sys/block/{name}/device/serial"
                try:
                    with open(serial_path, "r") as f:
                        serial = f.read().strip()
                except Exception:
                    serial = None

                if not serial or serial.lower() in ["", "unknown", "none"]:
                    try:
                        udev_output = subprocess.check_output(
                            f"udevadm info --query=property --name=/dev/{name}",
                            shell=True,
                        ).decode()
                        for udev_line in udev_output.splitlines():
                            if udev_line.startswith("ID_SERIAL="):
                                serial = udev_line.split("=", 1)[1].strip()
                                break
                    except Exception:
                        serial = None

                if serial and serial.lower() not in ["", "unknown", "none"]:
                    disk_serials.append(serial)
        except Exception:
            pass

        return disk_serials if disk_serials else ["Unknown"]

    @staticmethod
    def get_ram_serials():
        """Fetch serial numbers for all RAM modules using dmidecode."""
        ram_serials = []
        try:
            output = subprocess.check_output(
                "sudo dmidecode -t memory", shell=True
            ).decode().splitlines()
            for line in output:
                line = line.strip()
                if line.startswith("Serial Number:"):
                    serial = line.split(":", 1)[1].strip()
                    if serial and serial.lower() not in ["", "unknown", "none"]:
                        ram_serials.append(serial)
        except Exception:
            pass
        return ram_serials if ram_serials else ["Unknown"]
    
    @staticmethod
    def get_cpu_serial():
        """Fetch and decode the CPU serial number if available."""
        try:
            # Run dmidecode to get the processor information and grep for the "ID:" line.
            output = subprocess.check_output(
                "sudo dmidecode -t processor | grep 'ID:'", shell=True
            ).decode().strip()
            if "ID:" in output:
                hex_str = output.split("ID:")[1].strip()
                decoded_serial = hex_str.replace(" ", "")
                return decoded_serial
        except Exception:
            pass
        return "Unknown"

    @staticmethod
    def get_gpu_serial():
        """Fetch the GPU serial number (or a unique GPU identifier) for any GPU."""
        # Try using NVIDIA's tool first.
        try:
            output = subprocess.check_output("nvidia-smi -q", shell=True).decode()
            # Look for the "Serial Number" field.
            for line in output.splitlines():
                if "Serial Number" in line:
                    serial = line.split(":", 1)[1].strip()
                    if serial and serial.upper() != "N/A":
                        return serial
            # If Serial Number is not available, try the "GPU UUID".
            for line in output.splitlines():
                if "GPU UUID" in line:
                    uuid = line.split(":", 1)[1].strip()
                    if uuid:
                        return uuid
        except Exception:
            pass

        # Try using lshw for non-NVIDIA GPUs.
        try:
            output = subprocess.check_output("lshw -C display", shell=True).decode()
            for line in output.splitlines():
                if "serial:" in line.lower():
                    serial = line.split(":", 1)[1].strip()
                    if serial and serial.lower() not in ["n/a", "unknown", ""]:
                        return serial
        except Exception:
            pass

        # Fallback: use lspci output to generate a unique identifier.
        try:
            output = subprocess.check_output("lspci -nn | grep -i 'vga\\|3d'", shell=True).decode().strip()
            if output:
                return hashlib.sha256(output.encode()).hexdigest()
        except Exception:
            pass

        return "Unknown"

    @staticmethod
    def get_nic_serial():
        """
        Fetch the MAC addresses for all physical network interface cards (NICs) in the system.
        
        This function iterates over the entries in /sys/class/net and skips interfaces
        that are virtual (i.e. those that do not have a corresponding 'device' directory).
        
        Returns:
            A dictionary mapping interface names with MAC addresses.
        """
        nic_serials = {}
        net_dir = "/sys/class/net"

        if os.path.exists(net_dir):
            for iface in os.listdir(net_dir):
                iface_path = os.path.join(net_dir, iface)
                # Check if the interface is physical: it should have a "device" subdirectory.
                if not os.path.exists(os.path.join(iface_path, "device")):
                    continue  # Skip virtual interfaces

                address_file = os.path.join(iface_path, "address")
                try:
                    with open(address_file, "r") as f:
                        mac = f.read().strip()
                        if mac:
                            nic_serials[iface] = mac
                except Exception:
                    continue

        return nic_serials
    
    @staticmethod
    def get_power_supply_serial():
        """
        Fetch the power supply serial number using multiple methods.
        
        Methods attempted:
        1. Use 'sudo dmidecode -t 39' to search for a line starting with "Serial Number:".
        2. Fallback: search for a line starting with "Asset Tag:" in the same output.
        3. Check for PSU directories in /sys/class/power_supply/ (names starting with "PSU")
            and attempt to read a 'serial_number' file.
        4. Use 'udevadm info' on PSU directories to search for a POWER_SUPPLY_SERIAL property.
        5. Use 'lshw -class power' to search for a serial number in the hardware listing.
        6. Check the device tree (common on embedded systems) at /proc/device-tree/power_supply/serial-number.
        7. Use 'ipmitool fru' to query FRU data for PSU serial information.
        8. Check the 'uevent' file in PSU directories for a POWER_SUPPLY_SERIAL property.
        
        Returns:
            str: The power supply serial number if found; otherwise, "Unknown".
        """
        invalids = {"", "n/a", "unknown"}
        
        # Method 1 & 2: Use dmidecode -t 39 to search for serial info.
        try:
            output = subprocess.check_output("sudo dmidecode -t 39", shell=True).decode()
            for key in ("Serial Number:", "Asset Tag:"):
                for line in output.splitlines():
                    if line.strip().startswith(key):
                        value = line.split(":", 1)[1].strip()
                        if value.lower() not in invalids:
                            return value
        except Exception:
            pass

        # Method 3: Check for PSU directories in /sys/class/power_supply/ (e.g. PSU*)
        for psu_path in glob.glob("/sys/class/power_supply/PSU*"):
            serial_path = os.path.join(psu_path, "serial_number")
            try:
                with open(serial_path, "r") as f:
                    value = f.read().strip()
                    if value.lower() not in invalids:
                        return value
            except Exception:
                continue

        # Method 4: Use udevadm info to extract the POWER_SUPPLY_SERIAL property.
        for psu_path in glob.glob("/sys/class/power_supply/PSU*"):
            try:
                result = subprocess.check_output(
                    ["udevadm", "info", "--query=property", "--path=" + psu_path]
                ).decode()
                for line in result.splitlines():
                    if line.startswith("POWER_SUPPLY_SERIAL="):
                        value = line.split("=", 1)[1].strip()
                        if value.lower() not in invalids:
                            return value
            except Exception:
                continue

        # Method 5: Use lshw to fetch power supply information and extract a serial number.
        try:
            output = subprocess.check_output(["lshw", "-class", "power"]).decode()
            for line in output.splitlines():
                if "serial:" in line.lower():
                    value = line.split("serial:", 1)[1].strip()
                    if value.lower() not in invalids:
                        return value
        except Exception:
            pass

        # Method 6: Check the device tree for a serial number (common on embedded systems).
        dt_serial_path = "/proc/device-tree/power_supply/serial-number"
        try:
            if os.path.exists(dt_serial_path):
                with open(dt_serial_path, "r") as f:
                    value = f.read().strip()
                    if value.lower() not in invalids:
                        return value
        except Exception:
            pass

        # Method 7: Use ipmitool fru to query FRU data for PSU serial information.
        try:
            output = subprocess.check_output(["ipmitool", "fru"]).decode()
            for line in output.splitlines():
                if "Product Serial" in line or "Serial Number" in line:
                    parts = line.split(":", 1)
                    if len(parts) == 2:
                        value = parts[1].strip()
                        if value.lower() not in invalids:
                            return value
        except Exception:
            pass

        # Method 8: Check the 'uevent' file in PSU directories for a POWER_SUPPLY_SERIAL property.
        for psu_path in glob.glob("/sys/class/power_supply/PSU*"):
            uevent_file = os.path.join(psu_path, "uevent")
            try:
                with open(uevent_file, "r") as f:
                    for line in f:
                        if line.startswith("POWER_SUPPLY_SERIAL="):
                            value = line.split("=", 1)[1].strip()
                            if value.lower() not in invalids:
                                return value
            except Exception:
                continue

        return "Unknown"
    @staticmethod
    def get_battery_serial():
        """
        Fetch the battery serial number using multiple methods.
        
        Methods attempted:
          1. Check battery directories in /sys/class/power_supply/ that match BAT*.
          2. Fallback: read from /proc/acpi/battery/BAT0/info (for legacy systems).
        
        Returns:
            str: The battery serial number if found; otherwise, "Unknown".
        """
        invalids = {"", "unknown", "none"}

        # Method 1: Look for battery serial in /sys/class/power_supply/BAT*
        for bat_path in glob.glob("/sys/class/power_supply/BAT*"):
            serial_path = os.path.join(bat_path, "serial_number")
            try:
                with open(serial_path, "r") as f:
                    value = f.read().strip()
                    if value.lower() not in invalids:
                        return value
            except Exception:
                continue

        # Method 2: Fallback – check /proc/acpi/battery/BAT0/info (if available)
        proc_path = "/proc/acpi/battery/BAT0/info"
        if os.path.exists(proc_path):
            try:
                with open(proc_path, "r") as f:
                    for line in f:
                        if "Serial Number:" in line:
                            value = line.split(":", 1)[1].strip()
                            if value.lower() not in invalids:
                                return value
            except Exception:
                pass

        return "Unknown"

    @classmethod
    def get_power_info(cls):
        """
        Fetch power-related information including both the power supply and battery serial numbers.
        """
        return {
            "Power S/N": cls.get_power_supply_serial(),
            "Battery S/N": cls.get_battery_serial()
        }
    
    @staticmethod
    def _parse_edid(edid):
        """
        Parse the EDID blob to extract the monitor serial number.
        Returns the serial number if found, or "Unknown" otherwise.
        """
        # Initialize serial as None in case no valid serial number is found.
        serial = "Unknown"

        # EDID descriptor blocks are each 18 bytes long.
        # Standard EDID contains 4 descriptor blocks, starting at offsets 54, 72, 90, and 108.
        for offset in (54, 72, 90, 108):
            # Extract an 18-byte block starting at the current offset.
            descriptor = edid[offset:offset + 18]
            
            # Ensure the descriptor is exactly 18 bytes long.
            if len(descriptor) != 18:
                continue
            
            # Check if the descriptor block is designated for the monitor serial number.
            # According to the EDID specification, a descriptor block with the first three bytes 
            # set to 0x00 and the fourth byte equal to 0xFF indicates a monitor serial number block.
            if descriptor[0:3] == b"\x00\x00\x00" and descriptor[3] == 0xFF:
                # The serial number is stored in bytes 5 through 17 (13 bytes total).
                raw_serial = descriptor[5:18]
                
                # Decode the serial number from bytes to a string using ASCII encoding.
                # 'errors="ignore"' ignores any bytes that can't be decoded.
                serial = raw_serial.decode("ascii", errors="ignore").strip()
                
                # If a valid (non-empty) serial number is found, break out of the loop.
                if serial:
                    break

        # Return the extracted serial number, or "Unknown" if not found.
        return serial

    @staticmethod
    def _get_fallback_identifier(edid):
        """
        Returns a unique identifier by hashing the EDID data.
        Uses the full SHA-256 hash as a hex string.
        """
        return hashlib.sha256(edid).hexdigest()

    @staticmethod
    def get_display_identifiers():
        """
        Searches for EDID files in /sys/class/drm and returns a dictionary
        mapping each EDID file path to its identifier. If a monitor serial number
        is not found, a hash of the EDID is used as a unique identifier.
        """
        identifiers = {}
        for edid_path in glob.glob("/sys/class/drm/card*-*/edid"):
            try:
                with open(edid_path, "rb") as f:
                    edid = f.read()
                    if len(edid) < 128:
                        continue
                    serial = HardwareInfo._parse_edid(edid)
                    if not serial:
                        serial = HardwareInfo._get_fallback_identifier(edid)
                    identifiers[edid_path] = serial
            except Exception:
                continue
        return identifiers

    @classmethod
    def get_serial_numbers(cls):
        """Fetch all serial numbers and return them in JSON format."""
        serial_numbers = {
            "Machine S/N": cls.get_machine_serial(),
            "CPU S/N": cls.get_cpu_serial(),
            "BIOS S/N": cls.get_bios_serial(),
            "GPU S/N": cls.get_gpu_serial(),
            "NIC S/N": cls.get_nic_serial(),
            "Power S/N": cls.get_power_info().get("Power S/N", "N/A"),
            "Battery S/N": cls.get_power_info().get("Battery S/N", "N/A"),
            "RAM S/N": cls.get_ram_serials(),
            "Display S/N": cls.get_display_identifiers(),
            "Disk S/N" : cls.get_disk_serials()
        }
        return json.dumps(serial_numbers, indent=4)

if __name__ == '__main__':
    # Fetch the JSON string of serial numbers.
    serial_numbers_json = HardwareInfo.get_serial_numbers()
    
    # Parse the JSON string back into a dictionary.
    serial_numbers = json.loads(serial_numbers_json)
    
    # Iterate over the dictionary to print the results.
    for component, serial in serial_numbers.items():
        if isinstance(serial, dict):
            print(f"{component}:")
            for sub_component, sub_serial in serial.items():
                print(f"  {sub_component}: {sub_serial}")
        else:
            print(f"{component}: {serial}")
