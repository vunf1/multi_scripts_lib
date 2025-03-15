#!/bin/bash

if [ ! -d "venv" ]; then
    echo "Virtual environment 'venv' not found. Creating one..."
    python3 -m venv venv
else
    echo "Virtual environment 'venv' already exists."
fi

source venv/bin/activate

packages=(PyQt6 wmi)

for package in "${packages[@]}"; do
    if pip show "$package" > /dev/null 2>&1; then
        echo "Package '$package' is already installed."
    else
        echo "Installing package '$package'..."
        pip install "$package"
    fi
done

echo "Setup complete. Virtual environment is active and required packages are installed. Run "source venv/bin/activate" to start"
