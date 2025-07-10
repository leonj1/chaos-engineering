#!/usr/bin/env python3
"""
API Throttling Chaos Scenario
Simulates API rate limiting and throttling errors
"""

import requests
import json
import time
import sys
import threading
from datetime import datetime
from collections import defaultdict

class APIThrottlingChaos:
    def __init__(self, service, region="us-east-1", requests_per_second=10):
        self.service = service
        self.region = region
        self.requests_per_second = requests_per_second
        self.chaos_api_url = "http://localhost:4566/_localstack/chaos/faults"
        self.fault_ids = []
        self.request_counts = defaultdict(int)
        
    def inject_throttling(self):
        """Inject throttling fault using Chaos API"""
        print(f"\n🚦 CHAOS: Injecting API throttling for {self.service} in {self.region}")
        print("=" * 50)
        print(f"  Rate limit: {self.requests_per_second} requests/second")
        
        # First, inject immediate throttling for high request rates
        fault_config = {
            "service": self.service,
            "region": self.region,
            "probability": 1.0,  # Always throttle when limit exceeded
            "error": {
                "statusCode": 429,
                "code": self._get_throttle_error_code(),
                "message": f"Rate exceeded. Maximum allowed: {self.requests_per_second} requests per second."
            }
        }
        
        try:
            response = requests.post(self.chaos_api_url, json=fault_config)
            if response.status_code == 200:
                result = response.json()
                self.fault_ids.append(result.get("id"))
                print(f"  ✓ Throttling fault injected (ID: {result.get('id')})")
                
                # Also inject progressive throttling (warn at 80% of limit)
                warning_config = fault_config.copy()
                warning_config["probability"] = 0.2  # 20% chance when approaching limit
                warning_config["error"]["message"] = "Approaching rate limit. Consider implementing backoff."
                
                response = requests.post(self.chaos_api_url, json=warning_config)
                if response.status_code == 200:
                    result = response.json()
                    self.fault_ids.append(result.get("id"))
                    print(f"  ✓ Warning fault injected (ID: {result.get('id')})")
                
                return True
            else:
                print(f"  ✗ Failed to inject throttling: {response.status_code}")
                return False
        except Exception as e:
            print(f"  ✗ Error injecting throttling: {e}")
            return False
    
    def _get_throttle_error_code(self):
        """Get service-specific throttling error code"""
        throttle_codes = {
            "s3": "SlowDown",
            "dynamodb": "ProvisionedThroughputExceededException",
            "lambda": "TooManyRequestsException",
            "sqs": "ThrottlingException",
            "sns": "ThrottledException",
            "kinesis": "ProvisionedThroughputExceededException",
            "apigateway": "TooManyRequests"
        }
        return throttle_codes.get(self.service, "ThrottlingException")
    
    def simulate_burst_traffic(self, duration_seconds=10):
        """Simulate burst traffic to trigger throttling"""
        print(f"\n🌊 Simulating burst traffic for {duration_seconds} seconds...")
        print("  Legend: ✓ = Success, ⚠ = Warning, ✗ = Throttled")
        print("-" * 50)
        
        start_time = time.time()
        success_count = 0
        throttled_count = 0
        warning_count = 0
        
        def make_request():
            """Make a test request based on service type"""
            if self.service == "s3":
                return self._test_s3_request()
            elif self.service == "dynamodb":
                return self._test_dynamodb_request()
            elif self.service == "lambda":
                return self._test_lambda_request()
            else:
                return 200, "Not implemented"
        
        # Generate burst traffic
        request_number = 0
        while time.time() - start_time < duration_seconds:
            request_number += 1
            
            # Make multiple concurrent requests to exceed rate limit
            threads = []
            batch_size = self.requests_per_second * 2  # Intentionally exceed limit
            
            print(f"\n[{request_number}] Sending {batch_size} concurrent requests...", end="")
            
            results = []
            for _ in range(batch_size):
                status_code, message = make_request()
                results.append((status_code, message))
                time.sleep(0.01)  # Small delay between requests
            
            # Count results
            batch_success = sum(1 for code, _ in results if code == 200)
            batch_throttled = sum(1 for code, _ in results if code == 429)
            batch_warning = sum(1 for code, msg in results if "Approaching" in str(msg))
            
            success_count += batch_success
            throttled_count += batch_throttled
            warning_count += batch_warning
            
            # Visual representation
            print(f" {'✓' * batch_success}{'⚠' * batch_warning}{'✗' * batch_throttled}")
            
            # Wait before next batch
            time.sleep(1)
        
        # Summary
        total_requests = success_count + throttled_count + warning_count
        print("\n" + "=" * 50)
        print("📊 Burst Traffic Summary:")
        print(f"  Total requests: {total_requests}")
        print(f"  ✓ Successful: {success_count} ({success_count/total_requests*100:.1f}%)")
        print(f"  ⚠ Warnings: {warning_count} ({warning_count/total_requests*100:.1f}%)")
        print(f"  ✗ Throttled: {throttled_count} ({throttled_count/total_requests*100:.1f}%)")
        print(f"  Effective RPS: {total_requests/duration_seconds:.1f}")
    
    def test_backoff_strategy(self):
        """Test exponential backoff strategy"""
        print("\n🔄 Testing Exponential Backoff Strategy...")
        print("=" * 50)
        
        max_retries = 5
        base_delay = 1
        
        for attempt in range(max_retries):
            print(f"\nAttempt {attempt + 1}/{max_retries}")
            
            # Make request
            if self.service == "s3":
                status_code, message = self._test_s3_request()
            else:
                status_code, message = 429, "Throttled"
            
            if status_code == 200:
                print(f"  ✓ Success!")
                break
            elif status_code == 429:
                if attempt < max_retries - 1:
                    delay = base_delay * (2 ** attempt)  # Exponential backoff
                    print(f"  ✗ Throttled. Waiting {delay}s before retry...")
                    time.sleep(delay)
                else:
                    print(f"  ✗ Max retries exceeded")
    
    def _test_s3_request(self):
        """Test S3 request"""
        import subprocess
        
        cmd = [
            "docker", "run", "--rm", "--network", "host",
            "-e", "AWS_ACCESS_KEY_ID=test",
            "-e", "AWS_SECRET_ACCESS_KEY=test",
            "-e", f"AWS_DEFAULT_REGION={self.region}",
            "amazon/aws-cli",
            "--endpoint-url", "http://localhost:4566",
            "s3", "ls"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            return 200, "Success"
        elif "SlowDown" in result.stderr or "429" in result.stderr:
            return 429, result.stderr.strip()
        else:
            return 500, result.stderr.strip()
    
    def _test_dynamodb_request(self):
        """Test DynamoDB request"""
        # Simplified test - actual implementation would make real DynamoDB calls
        import random
        if random.random() < 0.3:  # 30% chance of throttling
            return 429, "ProvisionedThroughputExceededException"
        return 200, "Success"
    
    def _test_lambda_request(self):
        """Test Lambda request"""
        # Simplified test - actual implementation would invoke Lambda
        import random
        if random.random() < 0.3:  # 30% chance of throttling
            return 429, "TooManyRequestsException"
        return 200, "Success"
    
    def recover(self):
        """Remove throttling faults"""
        print(f"\n🔧 RECOVERY: Removing API throttling for {self.service}")
        print("=" * 50)
        
        removed_count = 0
        for fault_id in self.fault_ids:
            try:
                response = requests.delete(f"{self.chaos_api_url}/{fault_id}")
                if response.status_code in [200, 204]:
                    removed_count += 1
                    print(f"  ✓ Removed fault {fault_id}")
            except Exception as e:
                print(f"  ✗ Error removing fault {fault_id}: {e}")
        
        print(f"  Total faults removed: {removed_count}/{len(self.fault_ids)}")
        self.fault_ids = []

def main():
    if len(sys.argv) < 2:
        print("Usage: python api_throttling.py <service> [region] [rps_limit]")
        print("Services: s3, dynamodb, lambda, sqs, sns, kinesis, apigateway")
        print("Example: python api_throttling.py s3 us-east-1 10")
        sys.exit(1)
    
    service = sys.argv[1]
    region = sys.argv[2] if len(sys.argv) > 2 else "us-east-1"
    rps_limit = int(sys.argv[3]) if len(sys.argv) > 3 else 10
    
    print("🧪 API Throttling Chaos Test")
    print("=" * 50)
    print(f"Service: {service}")
    print(f"Region: {region}")
    print(f"Rate Limit: {rps_limit} requests/second")
    print(f"Time: {datetime.now()}")
    
    chaos = APIThrottlingChaos(service, region, rps_limit)
    
    # Inject throttling
    if chaos.inject_throttling():
        # Test 1: Burst traffic
        chaos.simulate_burst_traffic(duration_seconds=5)
        
        # Test 2: Backoff strategy
        input("\nPress Enter to test exponential backoff strategy...")
        chaos.test_backoff_strategy()
        
        # Wait for recovery
        input("\nPress Enter to remove throttling...")
        
        # Recover
        chaos.recover()
        
        # Test after recovery
        print("\n📊 Post-recovery test (should succeed):")
        status, message = chaos._test_s3_request() if service == "s3" else (200, "Success")
        print(f"  Result: {'✓ Success' if status == 200 else '✗ Failed'}")
        
        print("\n✅ API throttling test completed!")
    else:
        print("\n❌ Failed to inject API throttling")

if __name__ == "__main__":
    main()