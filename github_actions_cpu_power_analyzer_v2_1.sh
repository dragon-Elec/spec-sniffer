#!/bin/bash

# =================================================================
# github_actions_cpu_power_analyzer.sh - Enhanced v2.1 (FIXED)
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

    # Calculate average - more robust parsing
    AVG_MHZ=$(grep "^cpu MHz" /proc/cpuinfo | awk -F': ' '{sum+=$2; count++} END {if (count>0) printf "%.2f", sum/count; else print 0}')
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

# Use Python for more reliable arithmetic benchmark
if command -v python3 &> /dev/null; then
    echo "Running 100 million addition operations..."
    python3 << 'PYTHON_BENCHMARK'
import time
import sys

try:
    start = time.time()
    total = 0
    for i in range(100_000_000):
        total += i
    end = time.time()

    duration_ms = (total - start) * 1000 if total > 0 else (end - start) * 1000
    actual_duration = (end - start) * 1000

    print(f"Result: Completed in {actual_duration:.2f} ms")
    print(f"Throughput: {100_000_000 / (end - start):,.0f} ops/sec")

    if actual_duration < 100:
        rating = "EXCELLENT"
    elif actual_duration < 200:
        rating = "GOOD"
    elif actual_duration < 400:
        rating = "ACCEPTABLE"
    else:
        rating = "DEGRADED"

    print(f"Performance Rating: {rating}")
except Exception as e:
    print(f"Error in arithmetic benchmark: {e}", file=sys.stderr)
PYTHON_BENCHMARK
else
    # Fallback to bash if Python not available
    echo "Running 50 million addition operations (bash)..."
    START=$(date +%s%N)

    total=0
    for ((i=0; i<50000000; i++)); do
        ((total += i))
    done

    END=$(date +%s%N)
    DURATION_MS=$(( (END - START) / 1000000 ))

    echo "Result: Completed in ${DURATION_MS} ms"
    echo "Throughput: $(echo "scale=0; 50000000 * 1000 / $DURATION_MS" | bc 2>/dev/null || echo "N/A") ops/sec"
fi

print_subheader "Prime Number Check (Mathematical)"

if command -v python3 &> /dev/null; then
    echo "Finding primes from 2 to 100000..."
    python3 << 'PYTHON_PRIMES'
import time
import math

start = time.time()
def is_prime(n):
    if n < 2:
        return False
    if n == 2:
        return True
    if n % 2 == 0:
        return False
    for i in range(3, int(math.sqrt(n)) + 1, 2):
        if n % i == 0:
            return False
    return True

primes = [n for n in range(2, 100000) if is_prime(n)]
end = time.time()
duration_ms = (end - start) * 1000

print(f"Found {len(primes)} primes in {duration_ms:.2f} ms")
PYTHON_PRIMES
else
    echo "Finding primes from 2 to 10000 (bash)..."
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
fi

print_subheader "Python Advanced Benchmarks (if available)"

if command -v python3 &> /dev/null; then
    echo "Running comprehensive Python benchmarks..."
    python3 << 'PYTHON_ADVANCED'
import time

# Fibonacci - recursive CPU bound
print("\nFibonacci(35) - Recursive computation:")
def fib(n):
    if n <= 1:
        return n
    return fib(n-1) + fib(n-2)

start = time.time()
result = fib(35)
duration = (time.time() - start) * 1000
print(f"  Result: {result}")
print(f"  Time: {duration:.2f} ms")

# List sorting - memory + CPU
print("\nList Sort - 1 million elements:")
lst = list(range(1000000, 0, -1))
start = time.time()
lst.sort()
duration = (time.time() - start) * 1000
print(f"  Time: {duration:.2f} ms")

# Matrix-like operations
print("\nArithmetic - 50 million operations:")
start = time.time()
total = sum(range(50_000_000))
duration = (time.time() - start) * 1000
print(f"  Time: {duration:.2f} ms")
print(f"  Ops: {50_000_000 / (duration/1000):,.0f} ops/sec")
PYTHON_ADVANCED
else
    echo "Python3 not found, skipping advanced benchmarks"
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
    THEORETICAL_GFLOPS=$(echo "scale=2; $CORE_COUNT * $AVG_MHZ * $IPC / 1000" | bc 2>/dev/null || echo "N/A")
    echo ""
    echo "Theoretical Peak (IPC=1): $THEORETICAL_GFLOPS GFLOPS"
    echo "Theoretical Peak (IPC=2): $(echo "scale=2; $CORE_COUNT * $AVG_MHZ * 2 / 1000" | bc 2>/dev/null || echo "N/A") GFLOPS"
    echo "Theoretical Peak (IPC=4): $(echo "scale=2; $CORE_COUNT * $AVG_MHZ * 4 / 1000" | bc 2>/dev/null || echo "N/A") GFLOPS"
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
    has_thermal=0
    for zone in /sys/class/thermal/thermal_zone*; do
        if [ -f "$zone/temp" ]; then
            temp=$(cat "$zone/temp")
            temp_c=$(echo "scale=1; $temp / 1000" | bc 2>/dev/null || echo "?")
            name=$(cat "$zone/type" 2>/dev/null || echo "Unknown")
            echo "$name: ${temp_c}°C"
            has_thermal=1
        fi
    done
    if [ $has_thermal -eq 0 ]; then
        echo "No thermal zone information available"
    fi
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
    echo "✓ Clock Speed: $AVG_MHZ MHz ($(echo "scale=2; $AVG_MHZ / 1000" | bc 2>/dev/null || echo "?") GHz)"
fi

echo ""
echo -e "${C_CYAN}GitHub Actions Specifications (Your Runner):${C_RESET}"
if [ "$CORE_COUNT" -eq 4 ]; then
    echo "  Public Repo Runner ✓"
    echo "  Expected: 4 cores, 16GB RAM, 2.8-3.5 GHz"
elif [ "$CORE_COUNT" -eq 2 ]; then
    echo "  Private Repo Runner ✓"
    echo "  Expected: 2 cores, 7GB RAM, 2.0-3.0 GHz"
else
    echo "  Custom/Self-hosted Runner ✓"
    echo "  Cores: $CORE_COUNT"
fi

echo ""
echo -e "${C_YELLOW}Understanding Performance:${C_RESET}"
echo "  Arithmetic Benchmark:"
echo "    < 100 ms   = 🟢 EXCELLENT (well-provisioned)"
echo "    100-200 ms = 🟢 GOOD (normal performance)"
echo "    200-400 ms = 🟡 ACCEPTABLE (some load/throttling)"
echo "    > 400 ms   = 🔴 DEGRADED (heavy throttling)"

echo ""
echo -e "${C_GREEN}✅ Analysis complete!${C_RESET}"
echo ""
