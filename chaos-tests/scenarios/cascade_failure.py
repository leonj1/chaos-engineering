#!/usr/bin/env python3
"""
Cascade Failure Chaos Scenario
Simulates cascading failures across multiple AWS services
"""

import requests
import json
import time
import sys
import threading
from datetime import datetime
from collections import defaultdict

class CascadeFailureChaos:
    def __init__(self, initial_service="s3", region="us-east-1"):
        self.initial_service = initial_service
        self.region = region
        self.chaos_api_url = "http://localhost:4566/_localstack/chaos/faults"
        self.fault_ids = []
        self.service_dependencies = {
            "s3": ["lambda", "cloudfront"],
            "dynamodb": ["lambda", "apigateway"],
            "lambda": ["sqs", "sns"],
            "rds": ["lambda", "ecs"],
            "sqs": ["lambda"],
            "apigateway": ["lambda", "dynamodb"]
        }
        
    def inject_cascade(self):
        """Inject cascading failures starting from initial service"""
        print(f"\n💥 CHAOS: Initiating cascade failure from {self.initial_service}")
        print("=" * 50)
        
        # Phase 1: Initial service failure
        print(f"\n[Phase 1] Initial Service Failure: {self.initial_service}")
        if not self._inject_service_fault(self.initial_service, 1.0, 503):
            return False
        
        time.sleep(2)
        
        # Phase 2: First-level dependencies fail
        dependencies = self.service_dependencies.get(self.initial_service, [])
        if dependencies:
            print(f"\n[Phase 2] Dependent Services Failing: {', '.join(dependencies)}")
            for dep_service in dependencies:
                time.sleep(1)
                self._inject_service_fault(dep_service, 0.7, 500)
        
        time.sleep(2)
        
        # Phase 3: Second-level dependencies fail
        second_level_deps = set()
        for dep in dependencies:
            second_level_deps.update(self.service_dependencies.get(dep, []))
        
        if second_level_deps:
            print(f"\n[Phase 3] Secondary Dependencies Failing: {', '.join(second_level_deps)}")
            for service in second_level_deps:
                time.sleep(1)
                self._inject_service_fault(service, 0.5, 503)
        
        # Show cascade visualization
        self._visualize_cascade()
        
        return True
    
    def _inject_service_fault(self, service, probability, error_code):
        """Inject fault for a specific service"""
        print(f"  → Injecting fault in {service} (probability: {probability*100}%)")
        
        fault_config = {
            "service": service,
            "region": self.region,
            "probability": probability,
            "error": {
                "statusCode": error_code,
                "code": f"{service.upper()}ServiceException"
            }
        }
        
        try:
            # LocalStack Chaos API expects an array of faults
            response = requests.post(self.chaos_api_url, json=[fault_config])
            if response.status_code == 200:
                result = response.json()
                if isinstance(result, list) and len(result) > 0:
                    fault_id = result[0].get("id")
                    self.fault_ids.append(fault_id)
                    print(f"    ✓ Fault injected (ID: {fault_id})")
                return True
            else:
                print(f"    ✗ Failed to inject fault: {response.status_code}")
                return False
        except Exception as e:
            print(f"    ✗ Error: {e}")
            return False
    
    def _visualize_cascade(self):
        """Visualize the cascade failure pattern"""
        print("\n📊 Cascade Failure Visualization:")
        print("=" * 50)
        
        # ASCII art representation of cascade
        viz = f"""
        {self.initial_service} (100% failure)
            ├── {self.service_dependencies.get(self.initial_service, ['none'])[0]} (70% failure)
            │   └── {self.service_dependencies.get(self.service_dependencies.get(self.initial_service, ['none'])[0], ['none'])[0]} (50% failure)
            └── {self.service_dependencies.get(self.initial_service, ['none', 'none'])[1] if len(self.service_dependencies.get(self.initial_service, [])) > 1 else 'none'} (70% failure)
        """
        print(viz)
    
    def monitor_cascade_impact(self, duration=30):
        """Monitor the impact of cascade failure"""
        print(f"\n📈 Monitoring Cascade Impact for {duration} seconds...")
        print("  Legend: ✓ = Healthy, ⚠ = Degraded, ✗ = Failed")
        print("-" * 50)
        
        start_time = time.time()
        
        # Services to monitor
        all_services = [self.initial_service]
        all_services.extend(self.service_dependencies.get(self.initial_service, []))
        
        while time.time() - start_time < duration:
            elapsed = int(time.time() - start_time)
            print(f"\n[T+{elapsed}s] Service Status:")
            
            for service in all_services:
                status = self._check_service_health(service)
                status_icon = "✓" if status == "healthy" else ("⚠" if status == "degraded" else "✗")
                print(f"  {status_icon} {service}: {status}")
            
            time.sleep(3)
    
    def _check_service_health(self, service):
        """Check health of a service (simulated)"""
        # In a real scenario, this would make actual health check calls
        import random
        
        # Check if service has active faults
        try:
            response = requests.get(self.chaos_api_url)
            if response.status_code == 200:
                faults = response.json()
                for fault in faults:
                    if fault.get('service') == service:
                        probability = fault.get('probability', 1.0)
                        if random.random() < probability:
                            return "failed"
                        else:
                            return "degraded"
            return "healthy"
        except:
            return "unknown"
    
    def simulate_recovery_sequence(self):
        """Simulate gradual recovery from cascade failure"""
        print("\n🔧 Initiating Recovery Sequence...")
        print("=" * 50)
        
        # Recovery happens in reverse order
        print("\n[Recovery Phase 1] Stabilizing edge services...")
        time.sleep(2)
        
        # Remove some faults to simulate partial recovery
        if len(self.fault_ids) > 2:
            for fault_id in self.fault_ids[-2:]:
                self._remove_fault(fault_id)
            self.fault_ids = self.fault_ids[:-2]
        
        print("\n[Recovery Phase 2] Restoring dependent services...")
        time.sleep(2)
        
        # Remove more faults
        if len(self.fault_ids) > 1:
            for fault_id in self.fault_ids[1:]:
                self._remove_fault(fault_id)
            self.fault_ids = self.fault_ids[:1]
        
        print("\n[Recovery Phase 3] Restoring primary service...")
        time.sleep(2)
        
        # Remove final fault
        if self.fault_ids:
            self._remove_fault(self.fault_ids[0])
            self.fault_ids = []
        
        print("\n✅ Recovery sequence completed")
    
    def _remove_fault(self, fault_id):
        """Remove a specific fault"""
        try:
            response = requests.delete(f"{self.chaos_api_url}/{fault_id}")
            if response.status_code in [200, 204]:
                print(f"  ✓ Removed fault {fault_id}")
                return True
        except Exception as e:
            print(f"  ✗ Error removing fault {fault_id}: {e}")
        return False
    
    def recover(self):
        """Remove all cascade faults"""
        print(f"\n🔧 RECOVERY: Removing all cascade failures")
        print("=" * 50)
        
        for fault_id in self.fault_ids:
            self._remove_fault(fault_id)
        
        self.fault_ids = []
        print("  ✓ All cascade failures removed")

def main():
    if len(sys.argv) < 2:
        print("Usage: python cascade_failure.py <initial_service> [region]")
        print("Services: s3, dynamodb, lambda, rds, sqs, apigateway")
        print("Example: python cascade_failure.py s3 us-east-1")
        sys.exit(1)
    
    initial_service = sys.argv[1]
    region = sys.argv[2] if len(sys.argv) > 2 else "us-east-1"
    
    print("🧪 Cascade Failure Chaos Test")
    print("=" * 50)
    print(f"Initial Service: {initial_service}")
    print(f"Region: {region}")
    print(f"Time: {datetime.now()}")
    
    chaos = CascadeFailureChaos(initial_service, region)
    
    # Inject cascade failure
    if chaos.inject_cascade():
        # Monitor impact
        chaos.monitor_cascade_impact(duration=15)
        
        # Simulate recovery
        input("\nPress Enter to start recovery sequence...")
        chaos.simulate_recovery_sequence()
        
        # Final cleanup
        input("\nPress Enter to complete cleanup...")
        chaos.recover()
        
        print("\n✅ Cascade failure test completed!")
    else:
        print("\n❌ Failed to initiate cascade failure")

if __name__ == "__main__":
    main()