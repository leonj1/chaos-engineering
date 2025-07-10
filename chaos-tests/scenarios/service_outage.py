#!/usr/bin/env python3
"""
Service Outage Chaos Scenario
Simulates AWS service failures using LocalStack Chaos API
"""

import requests
import json
import time
import sys
from datetime import datetime

class ServiceOutageChaos:
    def __init__(self, service, region="us-east-1", probability=1.0, error_code=503):
        self.service = service
        self.region = region
        self.probability = probability
        self.error_code = error_code
        self.chaos_api_url = "http://localhost:4566/_localstack/chaos/faults"
        self.fault_id = None
        
    def inject_fault(self):
        """Inject service fault using Chaos API"""
        print(f"\n🔥 CHAOS: Injecting {self.service} service outage in {self.region}")
        print("=" * 50)
        
        fault_config = {
            "service": self.service,
            "region": self.region,
            "probability": self.probability,
            "error": {
                "statusCode": self.error_code,
                "code": self._get_error_code()
            }
        }
        
        print(f"  Service: {self.service}")
        print(f"  Region: {self.region}")
        print(f"  Failure probability: {self.probability * 100}%")
        print(f"  Error code: {self.error_code}")
        
        try:
            # LocalStack Chaos API expects an array of faults
            response = requests.post(self.chaos_api_url, json=[fault_config])
            if response.status_code == 200:
                result = response.json()
                if isinstance(result, list) and len(result) > 0:
                    self.fault_id = result[0].get("id")
                print(f"  ✓ Fault injected successfully (ID: {self.fault_id})")
                return True
            else:
                print(f"  ✗ Failed to inject fault: {response.status_code}")
                print(f"  Response: {response.text}")
                return False
        except Exception as e:
            print(f"  ✗ Error injecting fault: {e}")
            return False
    
    def _get_error_code(self):
        """Get appropriate error code based on service and status"""
        error_codes = {
            503: {
                "s3": "ServiceUnavailable",
                "dynamodb": "ServiceUnavailable",
                "lambda": "ServiceException",
                "sqs": "ServiceUnavailable",
                "sns": "ServiceUnavailable"
            },
            500: {
                "s3": "InternalError",
                "dynamodb": "InternalServerError",
                "lambda": "ServiceException",
                "sqs": "InternalError",
                "sns": "InternalError"
            },
            429: {
                "s3": "SlowDown",
                "dynamodb": "ProvisionedThroughputExceededException",
                "lambda": "TooManyRequestsException",
                "sqs": "ThrottlingException",
                "sns": "ThrottledException"
            }
        }
        return error_codes.get(self.error_code, {}).get(self.service, "ServiceException")
    
    def _get_error_message(self):
        """Get appropriate error message"""
        messages = {
            503: f"The {self.service.upper()} service is currently unavailable. Please try again later.",
            500: f"Internal error in {self.service.upper()} service.",
            429: f"Request rate exceeded for {self.service.upper()} service."
        }
        return messages.get(self.error_code, f"Error in {self.service.upper()} service.")
    
    def list_faults(self):
        """List all active faults"""
        try:
            response = requests.get(self.chaos_api_url)
            if response.status_code == 200:
                faults = response.json()
                if faults:
                    print("\n📋 Active Faults:")
                    for fault in faults:
                        print(f"  - ID: {fault.get('id')}")
                        print(f"    Service: {fault.get('service')}")
                        print(f"    Region: {fault.get('region')}")
                        print(f"    Probability: {fault.get('probability', 1.0) * 100}%")
                else:
                    print("\n  No active faults")
                return faults
        except Exception as e:
            print(f"  ✗ Error listing faults: {e}")
        return []
    
    def recover(self):
        """Remove the injected fault"""
        print(f"\n🔧 RECOVERY: Removing {self.service} service outage")
        print("=" * 50)
        
        if not self.fault_id:
            # Try to find the fault by listing all faults
            faults = self.list_faults()
            for fault in faults:
                if fault.get('service') == self.service and fault.get('region') == self.region:
                    self.fault_id = fault.get('id')
                    break
        
        if self.fault_id:
            try:
                response = requests.delete(f"{self.chaos_api_url}/{self.fault_id}")
                if response.status_code in [200, 204]:
                    print(f"  ✓ Service outage removed for {self.service}")
                    return True
                else:
                    print(f"  ✗ Failed to remove fault: {response.status_code}")
                    return False
            except Exception as e:
                print(f"  ✗ Error removing fault: {e}")
                return False
        else:
            print("  ⚠️  No fault ID found to remove")
            return False
    
    def test_service(self):
        """Test if the service is responding with faults"""
        print(f"\n🧪 Testing {self.service} service...")
        
        # Test based on service type
        if self.service == "s3":
            self._test_s3()
        elif self.service == "dynamodb":
            self._test_dynamodb()
        elif self.service == "lambda":
            self._test_lambda()
        else:
            print(f"  ⚠️  No test implemented for {self.service}")
    
    def _test_s3(self):
        """Test S3 operations"""
        import subprocess
        test_bucket = "test-chaos-bucket"
        
        # Try to list buckets
        cmd = [
            "docker", "run", "--rm", "--network", "host",
            "-e", "AWS_ACCESS_KEY_ID=test",
            "-e", "AWS_SECRET_ACCESS_KEY=test",
            "-e", f"AWS_DEFAULT_REGION={self.region}",
            "amazon/aws-cli",
            "--endpoint-url", "http://localhost:4566",
            "s3", "ls"
        ]
        
        for i in range(3):
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"  Attempt {i+1}: ❌ Failed - {result.stderr.strip()}")
            else:
                print(f"  Attempt {i+1}: ✅ Success")
            time.sleep(1)
    
    def _test_dynamodb(self):
        """Test DynamoDB operations"""
        # Implementation for DynamoDB testing
        print("  Testing DynamoDB list-tables operation...")
        # Add actual DynamoDB test implementation
    
    def _test_lambda(self):
        """Test Lambda operations"""
        # Implementation for Lambda testing
        print("  Testing Lambda list-functions operation...")
        # Add actual Lambda test implementation

def main():
    if len(sys.argv) < 2:
        print("Usage: python service_outage.py <service> [region] [probability] [error_code]")
        print("Services: s3, dynamodb, lambda, sqs, sns")
        print("Example: python service_outage.py s3 us-east-1 0.5 503")
        sys.exit(1)
    
    service = sys.argv[1]
    region = sys.argv[2] if len(sys.argv) > 2 else "us-east-1"
    probability = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
    error_code = int(sys.argv[4]) if len(sys.argv) > 4 else 503
    
    print("🧪 Service Outage Chaos Test")
    print("=" * 50)
    print(f"Service: {service}")
    print(f"Region: {region}")
    print(f"Probability: {probability * 100}%")
    print(f"Error Code: {error_code}")
    print(f"Time: {datetime.now()}")
    
    chaos = ServiceOutageChaos(service, region, probability, error_code)
    
    # Inject fault
    if chaos.inject_fault():
        # Test the service
        chaos.test_service()
        
        # Show active faults
        chaos.list_faults()
        
        # Wait for user input
        input("\nPress Enter to remove service outage...")
        
        # Recover
        chaos.recover()
        
        # Test again after recovery
        print("\n📊 Post-recovery test:")
        chaos.test_service()
        
        print("\n✅ Service outage test completed!")
    else:
        print("\n❌ Failed to inject service outage")

if __name__ == "__main__":
    main()