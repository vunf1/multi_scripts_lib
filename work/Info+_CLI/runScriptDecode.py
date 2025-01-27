import base64
import os
import tempfile
import subprocess
def decode_ps1(encoded_file_path):
    """
    Reads an already encoded .ps1 file and decodes it.

    Args:
        encoded_file_path (str): Path to the Base64-encoded .ps1 file.

    Returns:
        str: Decoded content of the PowerShell script.
    """
    try:
        # Check if the file exists
        if not os.path.isfile(encoded_file_path):
            raise FileNotFoundError(f"The file '{encoded_file_path}' does not exist.")

        # Read the encoded content from the file
        with open(encoded_file_path, 'r', encoding='utf-8') as encoded_file:
            encoded_content = encoded_file.read()

        # Decode the content
        decoded_content = base64.b64decode(encoded_content).decode('utf-16-le')
        print("Successfully decoded the script.")
        return decoded_content

    except Exception as e:
        print(f"An error occurred: {e}")
        return None

def execute_ps1(decoded_content):
    """
    Executes a decoded PowerShell script in a new PowerShell console.

    Args:
        decoded_content (str): The decoded content of the PowerShell script.

    Returns:
        None
    """
    try:
        # Write the decoded content directly into a temporary script file
        temp_script_path = os.path.join(tempfile.gettempdir(), 'decoded_script.ps1')
        with open(temp_script_path, 'w', encoding='utf-8') as temp_script:
            temp_script.write(decoded_content)

        print(f"Decoded script saved temporarily at {temp_script_path}")

        # Launch a new PowerShell console to run the script and close the console afterward
        subprocess.run([
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File",
            temp_script_path
        ])

    except Exception as e:
        print(f"An error occurred: {e}")

    finally:
        # Ensure the temporary script file is deleted after execution
        if os.path.isfile(temp_script_path):
            os.remove(temp_script_path)
            print(f"Temporary script file {temp_script_path} deleted.")

decoded_content = decode_ps1('encoded_infoplus.txt')
if decoded_content:
    execute_ps1(decoded_content)