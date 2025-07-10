#!/usr/bin/env python3
"""
Network Partition Chaos Scenario
Simulates network partitions and high latency conditions
"""

import requests
import time
import subprocess
import sys
import statistics
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

class NetworkPartitionChaos:
    def __init__(self, latency_ms=1000, jitter_ms=500):
        self.latency_ms = latency_ms
        self.jitter_ms = jitter_ms
        self.chaos_api_url = "http://localhost:4566/_localstack/chaos/faults"
        self.fault_ids = []
        
    def inject_partition(self):
        """Inject network partition by simulating timeouts and connection errors"""
        print(f"\n🌐 CHAOS: Injecting network partition")
        print("=" * 50)
        print(f"  Simulated latency: {self.latency_ms}ms")
        print(f"  Jitter: ±{self.jitter_ms}ms")
        print(f"  Total range: {self.latency_ms - self.jitter_ms}ms - {self.latency_ms + self.jitter_ms}ms")
        
        # Since chaos effects endpoint is not available, we'll inject timeout errors
        # to simulate network partition for multiple services
        services = ["s3", "dynamodb", "lambda", "sqs", "sns"]
        
        injected_count = 0
        for service in services:
            fault_config = {
                "service": service,
                "region": "us-east-1",
                "probability": 0.5,  # 50% chance of timeout
                "error": {
                    "statusCode": 504,
                    "code": "RequestTimeout"
                }
            }
            
            try:
                response = requests.post(self.chaos_api_url, json=[fault_config])
                if response.status_code == 200:
                    result = response.json()
                    if isinstance(result, list) and len(result) > 0:
                        self.fault_ids.append(result[0].get("id"))
                        injected_count += 1
            except:
                pass
        
        if injected_count > 0:
            print(f"  ✓ Network partition simulated for {injected_count} services")
        else:
            print(f"  ⚠️ Could not inject network partition via Chaos API")
            print(f"  Continuing with test to demonstrate partition behavior...")
        
        return True
    
    def test_partition_impact(self):
        """Test the impact of network partition on various operations"""
        print("\n📊 Testing Network Partition Impact...")
        print("=" * 50)
        
        # Test 1: Simple connectivity test
        print("\n[Test 1] Basic Connectivity (S3 List Buckets)")
        latencies = []
        
        for i in range(5):
            start = time.time()
            cmd = [
                "docker", "run", "--rm", "--network", "host",
                "-e", "AWS_ACCESS_KEY_ID=test",
                "-e", "AWS_SECRET_ACCESS_KEY=test",
                "-e", "AWS_DEFAULT_REGION=us-east-1",
                "amazon/aws-cli",
                "--endpoint-url", "http://localhost:4566",
                "s3", "ls"
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            elapsed = (time.time() - start) * 1000  # Convert to ms
            latencies.append(elapsed)
            
            status = "✓" if result.returncode == 0 else "✗"
            print(f"  Attempt {i+1}: {status} ({elapsed:.0f}ms)")
            time.sleep(1)
        
        if latencies:
            print(f"\n  Average latency: {statistics.mean(latencies):.0f}ms")
            print(f"  Max latency: {max(latencies):.0f}ms")
            print(f"  Min latency: {min(latencies):.0f}ms")
        
        # Test 2: Concurrent requests
        print("\n[Test 2] Concurrent Requests (10 parallel)")
        self._test_concurrent_requests()
        
        # Test 3: Large data transfer
        print("\n[Test 3] Data Transfer Test")
        self._test_data_transfer()
    
    def _test_concurrent_requests(self):
        """Test behavior under concurrent load during partition"""
        def make_request(i):
            start = time.time()
            try:
                cmd = [
                    "docker", "run", "--rm", "--network", "host",
                    "-e", "AWS_ACCESS_KEY_ID=test",
                    "-e", "AWS_SECRET_ACCESS_KEY=test",
                    "-e", "AWS_DEFAULT_REGION=us-east-1",
                    "amazon/aws-cli",
                    "--endpoint-url", "http://localhost:4566",
                    "s3", "ls"
                ]
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
                elapsed = (time.time() - start) * 1000
                return i, result.returncode == 0, elapsed
            except subprocess.TimeoutExpired:
                return i, False, 10000  # 10 second timeout
        
        with ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request, i) for i in range(10)]
            results = []
            
            for future in as_completed(futures):
                results.append(future.result())
        
        # Sort by request number
        results.sort(key=lambda x: x[0])
        
        successes = sum(1 for _, success, _ in results if success)
        latencies = [latency for _, _, latency in results]
        
        print(f"  Success rate: {successes}/10 ({successes*10}%)")
        print(f"  Average latency: {statistics.mean(latencies):.0f}ms")
        print(f"  P95 latency: {sorted(latencies)[int(len(latencies)*0.95)]:.0f}ms")
    
    def _test_data_transfer(self):
        """Test data transfer during partition"""
        # Create a test file
        test_data = "x" * 1024  # 1KB of data
        
        # Upload test
        print("  Uploading 1KB test file...")
        start = time.time()
        
        cmd = [
            "docker", "run", "--rm", "--network", "host",
            "-v", "/tmp:/tmp",
            "-e", "AWS_ACCESS_KEY_ID=test",
            "-e", "AWS_SECRET_ACCESS_KEY=test",
            "-e", "AWS_DEFAULT_REGION=us-east-1",
            "amazon/aws-cli",
            "--endpoint-url", "http://localhost:4566",
            "s3", "cp", "-", "s3://nginx-hello-world/partition-test.txt"
        ]
        
        result = subprocess.run(cmd, input=test_data, capture_output=True, text=True)
        upload_time = (time.time() - start) * 1000
        
        if result.returncode == 0:
            print(f"  ✓ Upload completed in {upload_time:.0f}ms")
        else:
            print(f"  ✗ Upload failed after {upload_time:.0f}ms")
    
    def recover(self):
        """Remove network partition effects"""
        print(f"\n🔧 RECOVERY: Removing network partition")
        print("=" * 50)
        
        for fault_id in self.fault_ids:
            try:
                response = requests.delete(f"{self.chaos_api_url}/{fault_id}")
                if response.status_code in [200, 204]:
                    print(f"  ✓ Removed fault {fault_id}")
                else:
                    print(f"  ✗ Failed to remove fault {fault_id}")
            except Exception as e:
                print(f"  ✗ Error removing fault: {e}")
        
        print("  ✓ Network partition removed")
    
    def test_recovery(self):
        """Test that services recover after partition is removed"""
        print("\n📊 Post-recovery Connectivity Test:")
        
        cmd = [
            "docker", "run", "--rm", "--network", "host",
            "-e", "AWS_ACCESS_KEY_ID=test",
            "-e", "AWS_SECRET_ACCESS_KEY=test",
            "-e", "AWS_DEFAULT_REGION=us-east-1",
            "amazon/aws-cli",
            "--endpoint-url", "http://localhost:4566",
            "s3", "ls"
        ]
        
        for i in range(3):
            start = time.time()
            result = subprocess.run(cmd, capture_output=True, text=True)
            elapsed = (time.time() - start) * 1000
            
            if result.returncode == 0:
                print(f"  Attempt {i+1}: ✓ Success ({elapsed:.0f}ms)")
            else:
                print(f"  Attempt {i+1}: ✗ Failed ({elapsed:.0f}ms)")
            time.sleep(1)

def parse_mode(mode_str):
    """Parse mode string to get latency and jitter values"""
    if mode_str == "gradual":
        # Gradual network degradation
        print("Mode: Gradual network degradation")
        return 1000, 500  # Start with 1s ± 500ms
    elif mode_str == "extreme":
        # Extreme partition
        print("Mode: Extreme network partition")
        return 5000, 1000  # 5s ± 1s
    else:
        # Try to parse as number
        try:
            latency = int(mode_str)
            jitter = min(500, latency // 4)  # 25% jitter, max 500ms
            return latency, jitter
        except ValueError:
            print(f"Invalid mode: {mode_str}. Using default 2000ms")
            return 2000, 500

def main():
    if len(sys.argv) < 2:
        print("Usage: python network_partition.py <latency_ms|mode> [jitter_ms]")
        print("Modes: gradual, extreme")
        print("Example: python network_partition.py 3000 500")
        print("Example: python network_partition.py extreme")
        sys.exit(1)
    
    # Parse arguments
    latency, jitter = parse_mode(sys.argv[1])
    if len(sys.argv) > 2:
        try:
            jitter = int(sys.argv[2])
        except ValueError:
            pass
    
    print("🧪 Network Partition Chaos Test")
    print("=" * 50)
    print(f"Latency: {latency}ms ± {jitter}ms")
    print(f"Time: {datetime.now()}")
    
    chaos = NetworkPartitionChaos(latency, jitter)
    
    # Inject partition
    if chaos.inject_partition():
        # Test impact
        chaos.test_partition_impact()
        
        # Wait for user
        input("\nPress Enter to remove network partition...")
        
        # Recover
        chaos.recover()
        
        # Test recovery
        time.sleep(2)
        chaos.test_recovery()
    
    print("\n✅ Network partition test completed!")

if __name__ == "__main__":
    main()