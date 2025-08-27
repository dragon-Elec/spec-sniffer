#!/bin/bash

# =================================================================
# spec_sniffer.sh - v1.0
#
# A diagnostic script to report the specifications of a GitHub
# Actions runner environment. It covers OS, CPU, RAM, disk,
# network, and key pre-installed software.
#
# Designed for easy use in any CI workflow.
# =================================================================

# --- ANSI Color Codes for Readability ---
C_BLUE='\033[1;34m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_RESET='\033[0m'

# --- Helper function for printing styled headers ---
print_header() {
    echo -e "\n${C_BLUE}--- $1 ---${C_RESET}"
}

# --- Main Logic ---
echo -e "${C_GREEN}==========================================="
echo -e "  GitHub Actions Runner Spec Sniffer"
echo -e "===========================================${C_RESET}"

print_header "System & OS Information"
echo "Hostname: $(hostname)"
# /etc/os-release is a standard way to get distro info
if [ -f /etc/os-release ]; then
    # Use grep to pull the human-friendly name
    grep 'PRETTY_NAME' /etc/os-release | cut -d'=' -f2 | tr -d '"'
fi
echo "Kernel: $(uname -a)"

print_header "CPU Information"
# lscpu provides a detailed and well-formatted summary
lscpu

# Attempt to read CPU frequency from sysfs, with added debugging.
echo -e "\n${C_YELLOW}--- Attempting to read CPU frequency from sysfs ---${C_RESET}"
FREQ_MAX_FILE="/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
FREQ_CUR_FILE="/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"

if [ -r "$FREQ_MAX_FILE" ]; then
    # Read value in KHz and convert to MHz for readability
    max_freq_khz=$(cat "$FREQ_MAX_FILE")
    max_freq_mhz=$((max_freq_khz / 1000))
    echo "Max Scaling Frequency   : ${max_freq_mhz} MHz"

    if [ -r "$FREQ_CUR_FILE" ]; then
        cur_freq_khz=$(cat "$FREQ_CUR_FILE")
        cur_freq_mhz=$((cur_freq_khz / 1000))
        echo "Current Scaling Frequency: ${cur_freq_mhz} MHz"
    fi
else
    echo "CPU frequency files not found at expected path: $FREQ_MAX_FILE"
    echo "Listing available directories for debugging..."
    echo -e "\n${C_YELLOW}--- Contents of /sys/devices/system/cpu/ ---${C_RESET}"
    ls -l /sys/devices/system/cpu/
    echo -e "\n${C_YELLOW}--- Contents of /sys/devices/system/cpu/cpu0/ ---${C_RESET}"
    ls -l /sys/devices/system/cpu/cpu0/
fi
echo -e "${C_YELLOW}--- End of CPU frequency check ---${C_RESET}"

print_header "Memory (RAM) Usage"
# -h flag makes it human-readable (e.g., GiB, MiB)
free -h

print_header "Disk Usage"
# Show all filesystems and highlight the root fs, which is most relevant
df -h
echo -e "\n${C_YELLOW}Specifically for the root filesystem (/):${C_RESET}"
df -h /

print_header "Network Information"
echo "Public IP Address: $(curl -s ifconfig.me || echo "Public IP lookup failed.")"
echo "Local Network Interfaces:"
# ip -4 limits to IPv4 for brevity. The `|| true` prevents failure if `ip` isn't found.
ip -4 addr show | grep 'inet ' || true

print_header "Key Tools & Runtimes"
# Check for common tools and report their versions if found
tools=("gh" "git" "docker" "node" "npm" "python3" "go" "rustc" "java" "mvn")
for tool in "${tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        # Capture the first line of the version output to keep it clean
        version_string=$($tool --version 2>&1 | head -n 1)
        printf "  %-10s: %s\n" "$tool" "$version_string"
    else
        printf "  %-10s: ${C_YELLOW}Not Found${C_RESET}\n" "$tool"
    fi
done

echo -e "\n${C_GREEN}✅ Spec Sniffer finished.${C_RESET}"
