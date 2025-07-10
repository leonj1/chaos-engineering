#!/usr/bin/env python3
"""
Resource Exhaustion Chaos Scenario
Simulates resource limits and quota exhaustion for various AWS services
"""

import requests
import json
import time
import sys
from datetime import datetime
import random

class ResourceExhaustionChaos:
    def __init__(self, service, resource_type="throughput"):
        self.service = service
        self.resource_type = resource_type
        self.chaos_api_url = "http://localhost:4566/_localstack/chaos/faults"
        self.fault_ids = []
        
        # Resource-specific error configurations
        self.resource_errors = {
            "dynamodb": {
                "throughput": {
                    "code": "ProvisionedThroughputExceededException",
                    "message": "The level of configured provisioned throughput for the table was exceeded.",
                    "status": 400
                },
                "storage": {
                    "code": "ResourceInUseException",
                    "message": "Table storage limit exceeded.",
                    "status": 400
                }
            },
            "lambda": {
                "concurrency": {
                    "code": "TooManyRequestsException",
                    "message": "Rate exceeded. Concurrent execution limit reached.",
                    "status": 429
                },
                "storage": {
                    "code": "CodeStorageExceededException",
                    "message": "Maximum code storage exceeded.",
                    "status": 400
                }
            },
            "s3": {
                "storage": {
                    "code": "QuotaExceeded",
                    "message": "Service quota for bucket storage exceeded.",
                    "status": 400
                },
                "requests": {
                    "code": "SlowDown",
                    "message": "Please reduce your request rate.",
                    "status": 503
                }
            },
            "kinesis": {
                "shards": {
                    "code": "LimitExceededException",
                    "message": "Shard limit for the account has been reached.",
                    "status": 400
                },
                "throughput": {
                    "code": "ProvisionedThroughputExceededException",
                    "message": "Rate exceeded for stream.",
                    "status": 400
                }
            }
        }
    
    def inject_exhaustion(self):
        """Inject resource exhaustion fault"""
        print(f"\n💨 CHAOS: Injecting {self.resource_type} exhaustion for {self.service}")
        print("=" * 50)
        
        error_config = self.resource_errors.get(self.service, {}).get(self.resource_type, {})
        if not error_config:
            print(f"  ✗ No configuration for {self.service} {self.resource_type} exhaustion")
            return False
        
        # Primary fault - consistent failures
        primary_fault = {
            "service": self.service,
            "region": "us-east-1",
            "probability": 0.8,  # 80% failure rate
            "error": {
                "statusCode": error_config["status"],
                "code": error_config["code"]
            }
        }
        
        print(f"  Resource type: {self.resource_type}")
        print(f"  Error code: {error_config['code']}")
        print(f"  Failure rate: 80%")
        
        try:
            # Inject primary fault - LocalStack expects an array
            response = requests.post(self.chaos_api_url, json=[primary_fault])
            if response.status_code == 200:
                result = response.json()
                if isinstance(result, list) and len(result) > 0:
                    self.fault_ids.append(result[0].get("id"))
                    print(f"  ✓ Primary fault injected (ID: {result[0].get('id')})")
                
                # Add intermittent fault for realistic behavior
                intermittent_fault = primary_fault.copy()
                intermittent_fault["probability"] = 0.3  # 30% for intermittent
                
                response = requests.post(self.chaos_api_url, json=[intermittent_fault])
                if response.status_code == 200:
                    result = response.json()
                    if isinstance(result, list) and len(result) > 0:
                        self.fault_ids.append(result[0].get("id"))
                        print(f"  ✓ Warning fault injected (ID: {result[0].get('id')})")
                
                return True
            else:
                print(f"  ✗ Failed to inject exhaustion: {response.status_code}")
                return False
        except Exception as e:
            print(f"  ✗ Error: {e}")
            return False
    
    def simulate_resource_consumption(self):
        """Simulate gradual resource consumption leading to exhaustion"""
        print("\n📈 Simulating Resource Consumption Pattern...")
        print("=" * 50)
        
        if self.service == "dynamodb" and self.resource_type == "throughput":
            self._simulate_dynamodb_throughput()
        elif self.service == "lambda" and self.resource_type == "concurrency":
            self._simulate_lambda_concurrency()
        elif self.service == "s3" and self.resource_type == "storage":
            self._simulate_s3_storage()
        else:
            self._simulate_generic_consumption()
    
    def _simulate_dynamodb_throughput(self):
        """Simulate DynamoDB throughput consumption"""
        print("  Simulating DynamoDB read/write consumption...")
        print("  Provisioned: 100 RCU, 100 WCU")
        print("  Consumption pattern:")
        
        for minute in range(5):
            rcu_consumed = random.randint(20, 150)
            wcu_consumed = random.randint(20, 150)
            
            rcu_status = "⚠️ THROTTLED" if rcu_consumed > 100 else "✅ OK"
            wcu_status = "⚠️ THROTTLED" if wcu_consumed > 100 else "✅ OK"
            
            print(f"\n  Minute {minute + 1}:")
            print(f"    RCU: {rcu_consumed}/100 {rcu_status}")
            print(f"    WCU: {wcu_consumed}/100 {wcu_status}")
            
            # Simulate operations
            success_count = 0
            throttled_count = 0
            
            for _ in range(10):
                if random.random() < 0.8 and (rcu_consumed > 100 or wcu_consumed > 100):
                    throttled_count += 1
                else:
                    success_count += 1
            
            print(f"    Operations: {success_count} success, {throttled_count} throttled")
            time.sleep(2)
    
    def _simulate_lambda_concurrency(self):
        """Simulate Lambda concurrent execution limits"""
        print("  Simulating Lambda concurrent executions...")
        print("  Account limit: 1000 concurrent executions")
        print("  Reserved concurrency: 800")
        print("  Unreserved pool: 200")
        
        for i in range(5):
            concurrent_executions = random.randint(150, 250)
            reserved_used = random.randint(700, 850)
            
            available = 200 - concurrent_executions
            status = "⚠️ THROTTLED" if available < 0 else "✅ AVAILABLE"
            
            print(f"\n  Check {i + 1}:")
            print(f"    Unreserved pool usage: {concurrent_executions}/200 {status}")
            print(f"    Reserved usage: {reserved_used}/800")
            print(f"    Total concurrent: {concurrent_executions + reserved_used}/1000")
            
            if available < 0:
                print(f"    ❌ {abs(available)} invocations throttled")
            
            time.sleep(2)
    
    def _simulate_s3_storage(self):
        """Simulate S3 storage quota exhaustion"""
        print("  Simulating S3 bucket storage consumption...")
        print("  Bucket quota: 1TB")
        
        current_storage = 900  # GB
        
        for hour in range(5):
            upload_size = random.randint(20, 80)  # GB
            current_storage += upload_size
            
            percentage = (current_storage / 1024) * 100
            status = "⚠️ QUOTA EXCEEDED" if current_storage > 1024 else "✅ OK"
            
            print(f"\n  Hour {hour + 1}:")
            print(f"    Storage used: {current_storage}GB / 1024GB ({percentage:.1f}%)")
            print(f"    Uploaded: +{upload_size}GB")
            print(f"    Status: {status}")
            
            if current_storage > 1024:
                print(f"    ❌ Upload rejected - quota exceeded by {current_storage - 1024}GB")
            
            time.sleep(2)
    
    def _simulate_generic_consumption(self):
        """Generic resource consumption simulation"""
        print(f"  Simulating {self.service} {self.resource_type} consumption...")
        
        for i in range(5):
            usage = random.randint(60, 120)
            status = "⚠️ EXHAUSTED" if usage > 100 else "✅ AVAILABLE"
            
            print(f"\n  Check {i + 1}: {usage}% utilization {status}")
            
            if usage > 100:
                print(f"    ❌ Requests failing due to resource exhaustion")
            
            time.sleep(2)
    
    def test_backpressure_handling(self):
        """Test how the system handles backpressure"""
        print("\n🔄 Testing Backpressure Handling...")
        print("=" * 50)
        
        strategies = [
            ("Retry with exponential backoff", self._test_exponential_backoff),
            ("Circuit breaker pattern", self._test_circuit_breaker),
            ("Load shedding", self._test_load_shedding)
        ]
        
        for strategy_name, strategy_func in strategies:
            print(f"\n[{strategy_name}]")
            strategy_func()
    
    def _test_exponential_backoff(self):
        """Test exponential backoff strategy"""
        max_retries = 4
        base_delay = 1
        
        for attempt in range(max_retries):
            # Simulate request
            if random.random() < 0.8:  # 80% failure rate
                delay = base_delay * (2 ** attempt)
                print(f"  Attempt {attempt + 1}: ❌ Failed - waiting {delay}s")
                if attempt < max_retries - 1:
                    time.sleep(1)  # Simulated wait
            else:
                print(f"  Attempt {attempt + 1}: ✅ Success")
                break
    
    def _test_circuit_breaker(self):
        """Test circuit breaker pattern"""
        failure_threshold = 5
        failures = 0
        circuit_open = False
        
        for i in range(10):
            if circuit_open:
                print(f"  Request {i + 1}: ⛔ Circuit open - request rejected")
                if i == 7:  # Try to close circuit
                    print("  🔄 Attempting to close circuit...")
                    circuit_open = False
            else:
                if random.random() < 0.8:  # 80% failure rate
                    failures += 1
                    print(f"  Request {i + 1}: ❌ Failed ({failures}/{failure_threshold})")
                    if failures >= failure_threshold:
                        circuit_open = True
                        print("  ⚡ Circuit breaker opened!")
                else:
                    failures = 0
                    print(f"  Request {i + 1}: ✅ Success - circuit healthy")
    
    def _test_load_shedding(self):
        """Test load shedding strategy"""
        capacity = 10
        queue = []
        
        for i in range(15):
            if len(queue) < capacity:
                queue.append(i)
                print(f"  Request {i + 1}: ✅ Accepted (queue: {len(queue)}/{capacity})")
            else:
                print(f"  Request {i + 1}: ❌ Rejected - at capacity")
            
            # Process some requests
            if random.random() < 0.3 and queue:
                processed = queue.pop(0)
                print(f"    → Processed request from queue")
    
    def recover(self):
        """Remove resource exhaustion faults"""
        print(f"\n🔧 RECOVERY: Removing resource exhaustion for {self.service}")
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
    if len(sys.argv) < 3:
        print("Usage: python resource_exhaustion.py <service> <resource_type>")
        print("\nSupported combinations:")
        print("  dynamodb throughput  - DynamoDB read/write capacity")
        print("  dynamodb storage     - DynamoDB table storage limit")
        print("  lambda concurrency   - Lambda concurrent execution limit")
        print("  lambda storage       - Lambda code storage limit")
        print("  s3 storage          - S3 bucket storage quota")
        print("  s3 requests         - S3 request rate limit")
        print("  kinesis shards      - Kinesis shard limit")
        print("  kinesis throughput  - Kinesis stream throughput")
        print("\nExample: python resource_exhaustion.py dynamodb throughput")
        sys.exit(1)
    
    service = sys.argv[1]
    resource_type = sys.argv[2]
    
    print("🧪 Resource Exhaustion Chaos Test")
    print("=" * 50)
    print(f"Service: {service}")
    print(f"Resource: {resource_type}")
    print(f"Time: {datetime.now()}")
    
    chaos = ResourceExhaustionChaos(service, resource_type)
    
    # Inject resource exhaustion
    if chaos.inject_exhaustion():
        # Simulate consumption pattern
        chaos.simulate_resource_consumption()
        
        # Test backpressure handling
        input("\nPress Enter to test backpressure handling strategies...")
        chaos.test_backpressure_handling()
        
        # Recovery
        input("\nPress Enter to remove resource exhaustion...")
        chaos.recover()
        
        print("\n✅ Resource exhaustion test completed!")
    else:
        print("\n❌ Failed to inject resource exhaustion")

if __name__ == "__main__":
    main()