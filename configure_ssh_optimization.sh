#!/bin/bash

# Function to update a configuration file
update_config() {
    local file="$1"
    local setting="$2"
    local value="$3"

    # Check if the setting exists
    if grep -q "^setting" "setting" "file"; then
        # Update the setting
        sudo sed -i "s|^setting.*|setting.*|setting value|" "value|" "file"
    else
        # Add the setting
        echo "setting setting value" | sudo tee -a "$file"
    fi
}

# Step 1: Update SSH configuration
echo "Configuring SSH settings..."
sudo sed -i 's/^#MaxSessions.*/MaxSessions 50/' /etc/ssh/sshd_config
sudo sed -i 's/^#MaxStartups.*/MaxStartups 70:30:100/' /etc/ssh/sshd_config

# Step 2: Increase file descriptor limits
echo "Updating file descriptor limits..."
sudo tee -a /etc/security/limits.conf > /dev/null <<EOL
*       soft    nofile  65535
*       hard    nofile  65535
EOL

# Ensure PAM enforces limits
echo "Ensuring PAM enforces limits..."
update_config "/etc/pam.d/common-session" "session required pam_limits.so" ""

# Step 3: Update systemd resource limits
echo "Updating systemd limits..."
update_config "/etc/systemd/system.conf" "DefaultLimitNOFILE=" "65535"
update_config "/etc/systemd/system.conf" "DefaultLimitNPROC=" "65535"
update_config "/etc/systemd/user.conf" "DefaultLimitNOFILE=" "65535"
update_config "/etc/systemd/user.conf" "DefaultLimitNPROC=" "65535"

# Step 4: Increase network connection limit
echo "Increasing network connection limit..."
sudo sysctl -w net.core.somaxconn=1024
echo "net.core.somaxconn = 1024" | sudo tee -a /etc/sysctl.conf

# Step 5: Restart SSH service and reload systemd
echo "Restarting SSH service and reloading systemd..."
sudo systemctl restart ssh
sudo systemctl daemon-reexec

# Step 6: Check for active Fail2Ban and UFW services
if sudo systemctl is-active --quiet fail2ban; then
    echo "Fail2Ban is running. Check if it is blocking any users."
    sudo fail2ban-client status
fi

if sudo systemctl is-active --quiet ufw; then
    echo "UFW (Uncomplicated Firewall) is running. Check its status."
    sudo ufw status
fi

# Step 7: System restart message
echo "Configuration completed. Please restart the system for all changes to take effect."
