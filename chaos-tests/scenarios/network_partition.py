#!/usr/bin/env python3
"""
Network Partition Chaos Scenario
Simulates network partitions and variable latency using LocalStack Chaos API
"""

import requests
import json
import time
import sys
import statistics
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

class NetworkPartitionChaos:
    def __init__(self, latency_ms=1000, jitter_ms=500):
        self.latency_ms = latency_ms
        self.jitter_ms = jitter_ms
        self.chaos_api_url = "http://localhost:4566/_localstack/chaos/effects"
        self.effect_id = None
        
    def inject_partition(self):
        """Inject network partition by adding extreme latency"""
        print(f"\n🌐 CHAOS: Injecting network partition")
        print("=" * 50)
        print(f"  Base latency: {self.latency_ms}ms")
        print(f"  Jitter: ±{self.jitter_ms}ms")
        print(f"  Total range: {self.latency_ms - self.jitter_ms}ms - {self.latency_ms + self.jitter_ms}ms")
        
        # Configure network effect with latency
        effect_config = {
            "latency": self.latency_ms
        }
        
        try:
            response = requests.post(self.chaos_api_url, json=effect_config)
            if response.status_code == 200:
                result = response.json()
                self.effect_id = result.get("id")
                print(f"  ✓ Network partition injected (ID: {self.effect_id})")
                return True
            else:
                print(f"  ✗ Failed to inject partition: {response.status_code}")
                print(f"  Response: {response.text}")
                return False
        except Exception as e:
            print(f"  ✗ Error injecting partition: {e}")
            return False
    
    def test_partition_impact(self):
        """Test the impact of network partition on various operations"""
        print("\n📊 Testing Network Partition Impact...")
        print("=" * 50)
        
        # Test 1: Simple connectivity test
        print("\n[Test 1] Basic Connectivity (S3 List Buckets)")
        latencies = []
        
        for i in range(5):
            start_time = time.time()
            status = self._test_s3_connectivity()
            elapsed = (time.time() - start_time) * 1000  # Convert to ms
            latencies.append(elapsed)
            
            status_icon = "✓" if status else "✗"
            print(f"  Attempt {i+1}: {status_icon} Response time: {elapsed:.0f}ms")
            time.sleep(0.5)
        
        if latencies:
            print(f"\n  Statistics:")
            print(f"    Mean latency: {statistics.mean(latencies):.0f}ms")
            print(f"    Std deviation: {statistics.stdev(latencies):.0f}ms" if len(latencies) > 1 else "    Std deviation: N/A")
            print(f"    Min/Max: {min(latencies):.0f}ms / {max(latencies):.0f}ms")
        
        # Test 2: Concurrent requests
        print("\n[Test 2] Concurrent Requests (simulating split-brain)")
        self._test_concurrent_requests()
        
        # Test 3: Timeout behavior
        print("\n[Test 3] Timeout Behavior")
        self._test_timeout_behavior()
    
    def _test_s3_connectivity(self):
        """Test S3 connectivity"""
        import subprocess
        
        cmd = [
            "docker", "run", "--rm", "--network", "host",
            "-e", "AWS_ACCESS_KEY_ID=test",
            "-e", "AWS_SECRET_ACCESS_KEY=test",
            "-e", "AWS_DEFAULT_REGION=us-east-1",
            "amazon/aws-cli",
            "--endpoint-url", "http://localhost:4566",
            "s3", "ls"
        ]
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            return result.returncode == 0
        except subprocess.TimeoutExpired:
            return False
    
    def _test_concurrent_requests(self):
        """Test concurrent requests during partition"""
        print("  Sending 10 concurrent requests...")
        
        def make_request(request_id):
            start_time = time.time()
            status = self._test_s3_connectivity()
            elapsed = (time.time() - start_time) * 1000
            return request_id, status, elapsed
        
        with ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request, i) for i in range(10)]
            
            results = []
            for future in as_completed(futures):
                request_id, status, elapsed = future.result()
                results.append((request_id, status, elapsed))
            
            # Sort by request ID for display
            results.sort(key=lambda x: x[0])
            
            success_count = sum(1 for _, status, _ in results if status)
            avg_latency = statistics.mean([elapsed for _, _, elapsed in results])
            
            print(f"  Results: {success_count}/10 successful")
            print(f"  Average latency: {avg_latency:.0f}ms")
            
            # Show timing distribution
            print("  Latency distribution:")
            for i in range(0, 10, 2):
                if i < len(results):
                    lat1 = results[i][2]
                    lat2 = results[i+1][2] if i+1 < len(results) else 0
                    print(f"    Requests {i+1}-{i+2}: {lat1:.0f}ms, {lat2:.0f}ms")
    
    def _test_timeout_behavior(self):
        """Test how services behave with different timeout settings"""
        timeouts = [1, 3, 5, 10]  # seconds
        
        print("  Testing different timeout settings...")
        for timeout in timeouts:
            start_time = time.time()
            
            import subprocess
            cmd = [
                "docker", "run", "--rm", "--network", "host",
                "-e", "AWS_ACCESS_KEY_ID=test",
                "-e", "AWS_SECRET_ACCESS_KEY=test",
                "-e", "AWS_DEFAULT_REGION=us-east-1",
                "amazon/aws-cli",
                "--endpoint-url", "http://localhost:4566",
                "--cli-read-timeout", str(timeout),
                "--cli-connect-timeout", str(timeout),
                "s3", "ls"
            ]
            
            try:
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout+1)
                elapsed = time.time() - start_time
                if result.returncode == 0:
                    print(f"    {timeout}s timeout: ✓ Success ({elapsed:.1f}s)")
                else:
                    print(f"    {timeout}s timeout: ✗ Failed ({elapsed:.1f}s)")
            except subprocess.TimeoutExpired:
                elapsed = time.time() - start_time
                print(f"    {timeout}s timeout: ⏱ Timeout ({elapsed:.1f}s)")
    
    def simulate_gradual_degradation(self):
        """Simulate gradual network degradation"""
        print("\n📉 Simulating Gradual Network Degradation...")
        print("=" * 50)
        
        latencies = [100, 500, 1000, 2000, 5000]
        
        for latency in latencies:
            print(f"\n[Latency: {latency}ms]")
            
            # Remove previous effect
            if self.effect_id:
                self.recover()
            
            # Apply new latency
            self.latency_ms = latency
            if self.inject_partition():
                # Test at this latency level
                start_time = time.time()
                status = self._test_s3_connectivity()
                elapsed = (time.time() - start_time) * 1000
                
                status_text = "Operational" if status else "Failed"
                print(f"  Status: {status_text}")
                print(f"  Response time: {elapsed:.0f}ms")
                
                time.sleep(1)
    
    def recover(self):
        """Remove network partition effect"""
        print(f"\n🔧 RECOVERY: Removing network partition")
        print("=" * 50)
        
        if self.effect_id:
            try:
                response = requests.delete(f"{self.chaos_api_url}/{self.effect_id}")
                if response.status_code in [200, 204]:
                    print(f"  ✓ Network partition removed")
                    self.effect_id = None
                    return True
                else:
                    print(f"  ✗ Failed to remove partition: {response.status_code}")
                    return False
            except Exception as e:
                print(f"  ✗ Error removing partition: {e}")
                return False
        else:
            # Try to clear all effects
            try:
                response = requests.get(self.chaos_api_url)
                if response.status_code == 200:
                    effects = response.json()
                    for effect in effects:
                        effect_id = effect.get('id')
                        requests.delete(f"{self.chaos_api_url}/{effect_id}")
                    print("  ✓ All network effects cleared")
                    return True
            except:
                pass
            
            print("  ⚠️  No partition to remove")
            return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python network_partition.py <latency_ms> [jitter_ms]")
        print("Example: python network_partition.py 2000 500")
        print("Special modes:")
        print("  python network_partition.py gradual    - Test gradual degradation")
        print("  python network_partition.py extreme    - Test extreme partition (10s latency)")
        sys.exit(1)
    
    if sys.argv[1] == "gradual":
        # Gradual degradation mode
        print("🧪 Network Partition Chaos Test - Gradual Degradation")
        print("=" * 50)
        print(f"Time: {datetime.now()}")
        
        chaos = NetworkPartitionChaos(100, 50)
        chaos.simulate_gradual_degradation()
        
        input("\nPress Enter to restore normal network...")
        chaos.recover()
        
    elif sys.argv[1] == "extreme":
        # Extreme partition mode
        print("🧪 Network Partition Chaos Test - Extreme Partition")
        print("=" * 50)
        print(f"Time: {datetime.now()}")
        
        chaos = NetworkPartitionChaos(10000, 2000)  # 10 second latency
        if chaos.inject_partition():
            chaos.test_partition_impact()
            
            input("\nPress Enter to remove partition...")
            chaos.recover()
            
            print("\n📊 Post-recovery test:")
            start_time = time.time()
            status = chaos._test_s3_connectivity()
            elapsed = (time.time() - start_time) * 1000
            print(f"  Status: {'✓ Success' if status else '✗ Failed'}")
            print(f"  Response time: {elapsed:.0f}ms")
    
    else:
        # Normal mode with specified latency
        latency_ms = int(sys.argv[1])
        jitter_ms = int(sys.argv[2]) if len(sys.argv) > 2 else latency_ms // 5
        
        print("🧪 Network Partition Chaos Test")
        print("=" * 50)
        print(f"Latency: {latency_ms}ms ± {jitter_ms}ms")
        print(f"Time: {datetime.now()}")
        
        chaos = NetworkPartitionChaos(latency_ms, jitter_ms)
        
        if chaos.inject_partition():
            chaos.test_partition_impact()
            
            input("\nPress Enter to remove partition...")
            chaos.recover()
            
            print("\n📊 Post-recovery test:")
            start_time = time.time()
            status = chaos._test_s3_connectivity()
            elapsed = (time.time() - start_time) * 1000
            print(f"  Status: {'✓ Success' if status else '✗ Failed'}")
            print(f"  Response time: {elapsed:.0f}ms")
    
    print("\n✅ Network partition test completed!")

if __name__ == "__main__":
    main()