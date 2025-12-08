#!/usr/bin/env python3
"""
GitHub Actions CPU Core Power Analyzer - Enhanced v2.0

Unlike spec_sniffer which just reports specs, this measures:
1. **Actual computational power per core**
2. **Real throughput numbers**
3. **GFLOPS (Gigaflops)**
4. **Core power rating**
5. **Performance bottlenecks**

Works on Ubuntu 24.04 LTS and ARM runners
"""

import os
import sys
import subprocess
import time
import json
import math
from pathlib import Path

class CorePowerAnalyzer:
    """Analyze actual computational power of CPU cores"""

    def __init__(self):
        self.results = {}
        self.core_count = os.cpu_count()

    def get_system_info(self):
        """Get system specifications"""
        print("\n" + "="*70)
        print("SYSTEM INFORMATION")
        print("="*70)

        # OS
        if Path("/etc/os-release").exists():
            with open("/etc/os-release") as f:
                for line in f:
                    if line.startswith("PRETTY_NAME"):
                        os_name = line.split("=")[1].strip().strip('"')
                        print(f"OS: {os_name}")
                        break

        # Kernel
        kernel = subprocess.check_output(["uname", "-r"]).decode().strip()
        print(f"Kernel: {kernel}")

        # Architecture
        arch = subprocess.check_output(["uname", "-m"]).decode().strip()
        print(f"Architecture: {arch}")
        self.results["arch"] = arch

    def get_cpu_specs(self):
        """Get CPU specifications using lscpu"""
        print("\n" + "="*70)
        print("CPU SPECIFICATIONS")
        print("="*70)

        try:
            output = subprocess.check_output(["lscpu"]).decode()
            print(output)

            # Parse key info
            for line in output.split("\n"):
                if "Model name" in line:
                    cpu_model = line.split(":")[1].strip()
                    self.results["cpu_model"] = cpu_model
                    print(f"\n→ CPU Model: {cpu_model}")
                elif "CPU(s)" in line and ":" in line:
                    try:
                        cpus = int(line.split(":")[1].strip())
                        print(f"→ Total CPUs: {cpus}")
                        self.results["cpu_count"] = cpus
                    except:
                        pass
                elif "Thread(s) per core" in line:
                    try:
                        threads = int(line.split(":")[1].strip())
                        print(f"→ Threads per core: {threads}")
                    except:
                        pass
        except Exception as e:
            print(f"Error running lscpu: {e}")

    def get_cpu_frequencies(self):
        """Get actual CPU frequencies from /proc/cpuinfo"""
        print("\n" + "="*70)
        print("CPU CLOCK SPEEDS")
        print("="*70)

        if Path("/proc/cpuinfo").exists():
            with open("/proc/cpuinfo") as f:
                content = f.read()

            # Extract MHz values
            mhz_values = []
            for line in content.split("\n"):
                if line.startswith("cpu MHz"):
                    try:
                        mhz = float(line.split(":")[1].strip())
                        mhz_values.append(mhz)
                    except:
                        pass

            if mhz_values:
                print(f"\nClock speeds for each core:")
                for i, mhz in enumerate(mhz_values[:8]):
                    ghz = mhz / 1000
                    print(f"  Core {i}: {mhz:.2f} MHz ({ghz:.2f} GHz)")

                if len(mhz_values) > 8:
                    print(f"  ... and {len(mhz_values) - 8} more cores")

                avg_mhz = sum(mhz_values) / len(mhz_values)
                avg_ghz = avg_mhz / 1000
                print(f"\nAverage Clock Speed: {avg_mhz:.2f} MHz ({avg_ghz:.2f} GHz)")
                self.results["avg_clock_mhz"] = avg_mhz
                self.results["all_clock_speeds"] = mhz_values

        # Get max frequency from sysfs
        for policy in Path("/sys/devices/system/cpu/cpufreq").glob("policy*"):
            max_freq_file = policy / "cpuinfo_max_freq"
            if max_freq_file.exists():
                with open(max_freq_file) as f:
                    max_freq_khz = int(f.read().strip())
                max_freq_mhz = max_freq_khz / 1000
                print(f"\nMax Frequency (sysfs): {max_freq_mhz:.2f} MHz")
                self.results["max_freq_mhz"] = max_freq_mhz
                break

    def get_memory_info(self):
        """Get memory information"""
        print("\n" + "="*70)
        print("MEMORY INFORMATION")
        print("="*70)

        if Path("/proc/meminfo").exists():
            with open("/proc/meminfo") as f:
                for line in f:
                    if line.startswith("MemTotal"):
                        total_kb = int(line.split()[1])
                        total_gb = total_kb / (1024 * 1024)
                        print(f"Total Memory: {total_gb:.2f} GB")
                        self.results["total_mem_gb"] = total_gb
                    elif line.startswith("MemAvailable"):
                        avail_kb = int(line.split()[1])
                        avail_gb = avail_kb / (1024 * 1024)
                        print(f"Available Memory: {avail_gb:.2f} GB")
                        self.results["avail_mem_gb"] = avail_gb

    def benchmark_single_core_arithmetic(self, iterations=100_000_000):
        """Measure single-core arithmetic performance"""
        print("\n" + "="*70)
        print("SINGLE-CORE ARITHMETIC BENCHMARK")
        print(f"({iterations:,} operations)")
        print("="*70)

        start = time.time()
        total = 0
        for i in range(iterations):
            total += i
        duration = time.time() - start

        duration_ms = duration * 1000
        ops_per_sec = iterations / duration
        gops = ops_per_sec / 1_000_000_000

        print(f"Time: {duration_ms:.2f} ms")
        print(f"Throughput: {ops_per_sec:,.0f} ops/sec")
        print(f"Gigaops: {gops:.3f} GOPS")

        self.results["arithmetic_benchmark_ms"] = duration_ms
        self.results["arithmetic_gops"] = gops

        return duration_ms

    def benchmark_fibonacci_single_thread(self, n=35):
        """Measure recursive computation (single-threaded)"""
        print("\n" + "="*70)
        print(f"FIBONACCI BENCHMARK (n={n})")
        print("(Recursive, CPU-bound)")
        print("="*70)

        def fib(n):
            if n <= 1:
                return n
            return fib(n-1) + fib(n-2)

        start = time.time()
        result = fib(n)
        duration = time.time() - start

        duration_ms = duration * 1000
        print(f"Fib({n}) = {result}")
        print(f"Time: {duration_ms:.2f} ms")

        self.results["fibonacci_ms"] = duration_ms

    def benchmark_prime_finding(self, limit=100_000):
        """Find primes - mathematical computation"""
        print("\n" + "="*70)
        print(f"PRIME NUMBER BENCHMARK")
        print(f"(Finding primes up to {limit:,})")
        print("="*70)

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

        start = time.time()
        primes = [n for n in range(2, limit) if is_prime(n)]
        duration = time.time() - start

        duration_ms = duration * 1000
        numbers_per_sec = limit / duration

        print(f"Primes found: {len(primes)}")
        print(f"Time: {duration_ms:.2f} ms")
        print(f"Numbers checked per sec: {numbers_per_sec:,.0f}")

        self.results["prime_finding_ms"] = duration_ms
        self.results["primes_found"] = len(primes)

    def benchmark_memory_intensive(self, size=10_000_000):
        """Sort large list - memory + CPU"""
        print("\n" + "="*70)
        print(f"MEMORY-INTENSIVE BENCHMARK")
        print(f"(Sorting {size:,} elements)")
        print("="*70)

        print("Creating list...")
        lst = list(range(size, 0, -1))

        print("Sorting...")
        start = time.time()
        lst.sort()
        duration = time.time() - start

        duration_ms = duration * 1000
        elements_per_sec = size / duration

        print(f"Time: {duration_ms:.2f} ms")
        print(f"Elements sorted per sec: {elements_per_sec:,.0f}")

        self.results["sort_benchmark_ms"] = duration_ms

    def calculate_core_power(self):
        """Calculate computational power per core"""
        print("\n" + "="*70)
        print("CORE POWER CALCULATION")
        print("="*70)

        if "cpu_count" not in self.results or "avg_clock_mhz" not in self.results:
            print("⚠️  Insufficient data for calculation")
            return

        cores = self.results["cpu_count"]
        clock_mhz = self.results["avg_clock_mhz"]
        clock_ghz = clock_mhz / 1000

        print(f"\nFormula: Cores × Clock Speed × IPC (Instructions Per Cycle)")
        print(f"Cores: {cores}")
        print(f"Clock Speed: {clock_ghz:.2f} GHz")

        # Different IPC assumptions
        print(f"\nTheoretical Peak Performance:")
        for ipc in [1, 2, 3, 4]:
            gflops = (cores * clock_mhz * ipc) / 1000
            print(f"  IPC={ipc}: {gflops:.1f} GFLOPS")

        # Calculate per-core power
        per_core_ghz = clock_ghz
        print(f"\nPer-Core Performance:")
        print(f"  Per core @ {clock_ghz:.2f} GHz: ~{clock_ghz:.1f} GFLOPS (IPC=1)")
        print(f"  Per core @ {clock_ghz:.2f} GHz: ~{clock_ghz*2:.1f} GFLOPS (IPC=2)")

        self.results["theoretical_peak_gflops_ipc1"] = (cores * clock_mhz) / 1000
        self.results["theoretical_peak_gflops_ipc2"] = (cores * clock_mhz * 2) / 1000
        self.results["per_core_gflops"] = per_core_ghz

    def generate_performance_rating(self):
        """Generate performance rating"""
        print("\n" + "="*70)
        print("PERFORMANCE RATING")
        print("="*70)

        arithmetic_ms = self.results.get("arithmetic_benchmark_ms")

        if arithmetic_ms:
            print(f"\nArithmetic Performance: {arithmetic_ms:.2f} ms (100M ops)")

            if arithmetic_ms < 80:
                rating = "🟢 EXCELLENT"
                reason = "Well-provisioned, no throttling"
            elif arithmetic_ms < 150:
                rating = "🟢 GOOD"
                reason = "Normal performance"
            elif arithmetic_ms < 250:
                rating = "🟡 ACCEPTABLE"
                reason = "Some system load or throttling"
            elif arithmetic_ms < 400:
                rating = "🟠 DEGRADED"
                reason = "Possible thermal throttling"
            else:
                rating = "🔴 POOR"
                reason = "Significant throttling or overload"

            print(f"Rating: {rating}")
            print(f"Reason: {reason}")

        cores = self.results.get("cpu_count")
        if cores:
            print(f"\nGitHub Actions Comparison:")
            if cores >= 4:
                print(f"  ✓ Public Repo tier (4+ cores)")
            elif cores >= 2:
                print(f"  ✓ Private Repo tier (2+ cores)")
            else:
                print(f"  ⚠️  Limited tier ({cores} core{'s' if cores > 1 else ''})")

    def export_json(self):
        """Export results as JSON"""
        print("\n" + "="*70)
        print("JSON REPORT")
        print("="*70)

        report = {
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "environment": "GitHub Actions",
            "metrics": self.results
        }

        print(json.dumps(report, indent=2))

        return report

    def run_all_tests(self):
        """Run complete analysis"""
        print("\n" + "🔍 GitHub Actions CPU Core Power Analyzer")
        print("="*70)

        self.get_system_info()
        self.get_cpu_specs()
        self.get_cpu_frequencies()
        self.get_memory_info()

        print("\n" + "⚡ Running Performance Benchmarks")
        print("="*70)

        arithmetic_time = self.benchmark_single_core_arithmetic(iterations=100_000_000)
        self.benchmark_fibonacci_single_thread(n=35)
        self.benchmark_prime_finding(limit=100000)
        self.benchmark_memory_intensive(size=5_000_000)

        self.calculate_core_power()
        self.generate_performance_rating()
        self.export_json()

        print("\n" + "✅ Analysis complete!")

if __name__ == "__main__":
    analyzer = CorePowerAnalyzer()
    analyzer.run_all_tests()
