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

# Check for CPU frequency using the most reliable methods for ARM runners
echo -e "\n${C_YELLOW}CPU Frequency Information:${C_RESET}"
FREQ_FILE="/sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq"

# Primary Method: Try reading from sysfs, which is fast and direct.
if [ -r "$FREQ_FILE" ]; then
    echo "  Method Used: Reading from sysfs"
    max_freq_khz=$(cat "$FREQ_FILE")
    max_freq_mhz=$((max_freq_khz / 1000))
    printf "  %-25s: %s MHz\n" "Max Frequency" "$max_freq_mhz"

    CUR_FREQ_FILE="/sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq"
    if [ -r "$CUR_FREQ_FILE" ]; then
        cur_freq_khz=$(cat "$CUR_FREQ_FILE")
        cur_freq_mhz=$((cur_freq_khz / 1000))
        printf "  %-25s: %s MHz\n" "Current Frequency" "$cur_freq_mhz"
    fi
# Fallback Method: Use 'perf' to measure real-time cycles if sysfs is unavailable.
elif command -v perf &> /dev/null; then
    echo "  Method Used: Measuring with perf (sysfs path not found)"
    # Run perf and capture stderr, then filter for the relevant line of output.
    perf_output=$(perf stat -e cycles sleep 1 2>&1)
    cycles_line=$(echo "$perf_output" | grep 'cycles' | sed 's/^[ \t]*//') # Trim leading whitespace
    printf "  %-25s: %s\n" "Perf Measurement" "$cycles_line"
else
    echo "  Could not determine CPU frequency. Neither sysfs nor perf is available."
fi

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
