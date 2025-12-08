#!/bin/bash

# =================================================================
# github_actions_cpu_power_analyzer.sh - Enhanced v2.0
# 
# Combines system spec reporting (like spec_sniffer) with actual 
# computational power measurement.
# 
# What makes this better:
# 1. Shows actual CORE POWER (not just clock speed)
# 2. Measures real computational throughput
# 3. Works on Ubuntu 24.04 LTS and ARM runners
# 4. Fallback methods for different environments
# =================================================================

set -e

# --- ANSI Color Codes ---
C_BLUE='\033[1;34m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'
C_CYAN='\033[1;36m'
C_RESET='\033[0m'

print_header() {
    echo -e "\n${C_BLUE}=== $1 ===${C_RESET}"
}

print_subheader() {
    echo -e "\n${C_CYAN}→ $1${C_RESET}"
}

# ===================================================================
# SECTION 1: SYSTEM & OS INFORMATION
# ===================================================================
print_header "System & OS Information"

echo "Hostname: $(hostname)"

if [ -f /etc/os-release ]; then
    PRETTY_OS=$(grep 'PRETTY_NAME' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    echo "OS: $PRETTY_OS"
fi

KERNEL_INFO=$(uname -r)
echo "Kernel: $KERNEL_INFO"

ARCH=$(uname -m)
echo "Architecture: $ARCH"

# ===================================================================
# SECTION 2: CPU SPECIFICATIONS (like spec_sniffer)
# ===================================================================
print_header "CPU Specifications"

echo "Detailed CPU info from lscpu:"
lscpu

# ===================================================================
# SECTION 3: CPU CLOCK SPEEDS (Enhanced)
# ===================================================================
print_header "CPU Clock Speed Information"

print_subheader "Max Frequency (from sysfs)"

# Try multiple policy paths (policy0, policy1, etc.)
MAX_FREQ_FILE=""
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    if [ -r "$policy/cpuinfo_max_freq" ]; then
        MAX_FREQ_FILE="$policy/cpuinfo_max_freq"
        break
    fi
done

if [ -n "$MAX_FREQ_FILE" ]; then
    max_freq_khz=$(cat "$MAX_FREQ_FILE")
    max_freq_mhz=$((max_freq_khz / 1000))
    max_freq_ghz=$(echo "scale=2; $max_freq_mhz / 1000" | bc 2>/dev/null || echo "N/A")
    echo "Max Frequency: $max_freq_mhz MHz (~$max_freq_ghz GHz)"
else
    echo "Max Frequency: Could not determine from sysfs"
fi

print_subheader "Current Frequency (per core)"

if [ -f /proc/cpuinfo ]; then
    # Extract CPU MHz for each core
    echo "CPU MHz per core:"
    grep "^cpu MHz" /proc/cpuinfo | head -10 | nl

    # Calculate average
    AVG_MHZ=$(grep "^cpu MHz" /proc/cpuinfo | awk -F': ' '{sum+=$2; count++} END {if (count>0) printf "%.2f", sum/count}')
    if [ ! -z "$AVG_MHZ" ] && [ "$AVG_MHZ" != "0" ]; then
        echo "Average Clock Speed: $AVG_MHZ MHz"
    fi

    # Count actual cores
    CORE_COUNT=$(grep -c "^processor" /proc/cpuinfo)
    echo "Total Cores Detected: $CORE_COUNT"
else
    echo "Could not read /proc/cpuinfo"
fi

# ===================================================================
# SECTION 4: MEMORY INFORMATION
# ===================================================================
print_header "Memory Information"

echo "Memory Summary:"
free -h

echo ""
echo "Memory Details:"
if [ -f /proc/meminfo ]; then
    grep -E "^MemTotal|^MemAvailable|^MemFree|^Buffers|^Cached" /proc/meminfo
fi

# ===================================================================
# SECTION 5: DISK INFORMATION
# ===================================================================
print_header "Disk Information"

echo "Root Filesystem:"
df -h / | tail -1

echo ""
echo "All Filesystems:"
df -h

# ===================================================================
# SECTION 6: ACTUAL COMPUTATIONAL POWER MEASUREMENT
# ===================================================================
print_header "Computational Power Measurement"

echo -e "${C_YELLOW}This section measures ACTUAL CPU POWER, not just specs${C_RESET}"

print_subheader "Arithmetic Benchmark (CPU-bound)"

# Bash arithmetic loop
echo "Performing 50 million addition operations..."
START=$(date +%s%N)

total=0
for ((i=0; i<50000000; i++)); do
    ((total += i))
done

END=$(date +%s%N)
DURATION_MS=$(( (END - START) / 1000000 ))

echo "Result: Completed in ${DURATION_MS} ms"
echo "Throughput: $(echo "scale=0; 50000000 * 1000 / $DURATION_MS" | bc 2>/dev/null || echo "N/A") ops/sec"

print_subheader "Prime Number Check (Mathematical)"

echo "Finding primes from 2 to 10000..."
START=$(date +%s%N)

count=0
for ((n=2; n<10000; n++)); do
    is_prime=1
    for ((i=2; i*i<=n; i++)); do
        if [ $((n % i)) -eq 0 ]; then
            is_prime=0
            break
        fi
    done
    if [ $is_prime -eq 1 ]; then
        ((count++))
    fi
done

END=$(date +%s%N)
DURATION_MS=$(( (END - START) / 1000000 ))

echo "Found $count primes in ${DURATION_MS} ms"

print_subheader "Python Benchmark (if available)"

if command -v python3 &> /dev/null; then
    echo "Running Python computational benchmark..."

    python3 << 'PYTHON_EOF'
import time

# Fibonacci - recursive CPU bound
def fib(n):
    if n <= 1:
        return n
    return fib(n-1) + fib(n-2)

print("Computing Fibonacci(35)...")
start = time.time()
result = fib(35)
duration = (time.time() - start) * 1000

print(f"Result: {result}")
print(f"Time: {duration:.2f} ms")

# List sorting - memory + CPU
print("\nSorting 1 million elements...")
lst = list(range(1000000, 0, -1))
start = time.time()
lst.sort()
duration = (time.time() - start) * 1000

print(f"Time: {duration:.2f} ms")

# Matrix-like operations
print("\nPerforming 10 million arithmetic ops...")
start = time.time()
total = sum(range(10000000))
duration = (time.time() - start) * 1000

print(f"Time: {duration:.2f} ms")
print(f"Ops: {10000000 / (duration/1000):.0f} ops/sec")
PYTHON_EOF
else
    echo "Python3 not found, skipping Python benchmarks"
fi

# ===================================================================
# SECTION 7: THEORETICAL COMPUTATIONAL POWER
# ===================================================================
print_header "Theoretical Computational Power"

if [ ! -z "$CORE_COUNT" ] && [ ! -z "$AVG_MHZ" ] && [ "$AVG_MHZ" != "0" ]; then
    echo "Calculation: cores × clock_speed × instructions_per_cycle"
    echo "Cores: $CORE_COUNT"
    echo "Average Clock: $AVG_MHZ MHz"

    # Assuming IPC (Instructions Per Cycle) of 1 for single-threaded operations
    # Real IPC varies 1-4 depending on workload

    IPC=1
    THEORETICAL_GFLOPS=$(echo "scale=2; $CORE_COUNT * $AVG_MHZ * $IPC / 1000" | bc)
    echo ""
    echo "Theoretical Peak (IPC=1): $THEORETICAL_GFLOPS GFLOPS"
    echo "Theoretical Peak (IPC=2): $(echo "scale=2; $CORE_COUNT * $AVG_MHZ * 2 / 1000" | bc) GFLOPS"
    echo "Theoretical Peak (IPC=4): $(echo "scale=2; $CORE_COUNT * $AVG_MHZ * 4 / 1000" | bc) GFLOPS"
    echo ""
    echo "⚠️  Note: Actual performance depends on workload, cache efficiency, and thermal conditions"
fi

# ===================================================================
# SECTION 8: CPU GOVERNOR & THERMAL INFO
# ===================================================================
print_header "CPU Governor & Performance Settings"

if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
    echo "CPU Frequency Governor: $GOVERNOR"
else
    echo "CPU Frequency Governor: Could not determine"
fi

print_subheader "Thermal Information"

if [ -d /sys/class/thermal ]; then
    for zone in /sys/class/thermal/thermal_zone*; do
        if [ -f "$zone/temp" ]; then
            temp=$(cat "$zone/temp")
            temp_c=$(echo "scale=1; $temp / 1000" | bc)
            name=$(cat "$zone/type" 2>/dev/null || echo "Unknown")
            echo "$name: ${temp_c}°C"
        fi
    done
else
    echo "No thermal zone information available"
fi

# ===================================================================
# SECTION 9: NETWORK INFORMATION
# ===================================================================
print_header "Network Information"

echo "Local IP Addresses:"
ip -4 addr show 2>/dev/null | grep 'inet ' | awk '{print $NF, $2}' || echo "Could not retrieve"

print_subheader "Public IP Address (optional)"
PUBLIC_IP=$(curl -s --max-time 2 ifconfig.me 2>/dev/null || echo "Not available")
echo "Public IP: $PUBLIC_IP"

# ===================================================================
# SECTION 10: KEY TOOLS & VERSIONS
# ===================================================================
print_header "Key Tools & Versions"

tools=(
    "bash:bash --version"
    "git:git --version"
    "docker:docker --version"
    "node:node --version"
    "npm:npm --version"
    "python3:python3 --version"
    "go:go version"
    "rustc:rustc --version"
    "java:java -version"
)

for tool_info in "${tools[@]}"; do
    IFS=':' read -r tool cmd <<< "$tool_info"

    if command -v "$tool" &> /dev/null; then
        version=$($cmd 2>&1 | head -n1)
        printf "  %-15s: %s\n" "$tool" "$version"
    else
        printf "  %-15s: ${C_YELLOW}Not installed${C_RESET}\n" "$tool"
    fi
done

# ===================================================================
# SECTION 11: SUMMARY & INTERPRETATION
# ===================================================================
print_header "Summary & Interpretation"

echo -e "${C_GREEN}Key Metrics for GitHub Actions:${C_RESET}"
echo ""

if [ ! -z "$CORE_COUNT" ]; then
    echo "✓ Cores: $CORE_COUNT"
fi

if [ ! -z "$AVG_MHZ" ] && [ "$AVG_MHZ" != "0" ]; then
    echo "✓ Clock Speed: $AVG_MHZ MHz"
fi

if [ ! -z "$DURATION_MS" ]; then
    echo "✓ Arithmetic Performance: ${DURATION_MS} ms (50M ops)"

    if [ "$DURATION_MS" -lt 100 ]; then
        echo "  → ${C_GREEN}EXCELLENT${C_RESET} (well-provisioned runner)"
    elif [ "$DURATION_MS" -lt 200 ]; then
        echo "  → ${C_GREEN}GOOD${C_RESET} (normal runner)"
    elif [ "$DURATION_MS" -lt 400 ]; then
        echo "  → ${C_YELLOW}ACCEPTABLE${C_RESET} (some load or throttling)"
    else
        echo "  → ${C_RED}SLOW${C_RESET} (possible throttling or high system load)"
    fi
fi

echo ""
echo -e "${C_CYAN}GitHub Actions Standard Expectations:${C_RESET}"
echo "  Public Repo:  4 cores, 16GB RAM, 2.8-3.5 GHz"
echo "  Private Repo: 2 cores, 7GB RAM, 2.0-3.0 GHz"
echo "  ARM Runner:   4 cores, 16GB RAM, 2.4-3.2 GHz"

echo ""
echo -e "${C_GREEN}✅ Analysis complete!${C_RESET}"
echo ""
