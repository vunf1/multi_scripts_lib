import base64
import os
import tempfile
import subprocess

def encode_ps1(input_file_path, output_encoded_path):
    """
    Encodes a .ps1 file in Base64 format and saves it to a specified file.

    Args:
        input_file_path (str): Path to the input .ps1 file.
        output_encoded_path (str): Path to save the encoded .ps1 content.

    Returns:
        None
    """
    try:
        # Check if the file exists
        if not os.path.isfile(input_file_path):
            raise FileNotFoundError(f"The file '{input_file_path}' does not exist.")

        # Read the content of the .ps1 file
        with open(input_file_path, 'r', encoding='utf-8') as file:
            content = file.read()

        # Encode the content in Base64
        encoded_content = base64.b64encode(content.encode('utf-16-le')).decode('utf-8')

        # Save the encoded content to the output file
        with open(output_encoded_path, 'w', encoding='utf-8') as encoded_file:
            encoded_file.write(encoded_content)

        print(f"Encoded content saved to {output_encoded_path}")

    except Exception as e:
        print(f"An error occurred: {e}")


encode_ps1('infoplus.ps1', 'encoded_infoplus.txt')

