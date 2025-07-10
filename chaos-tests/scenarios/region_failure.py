#!/usr/bin/env python3
"""
Region Failure Chaos Scenario
Simulates a complete region outage by making S3 objects inaccessible
"""

import subprocess
import time
import sys
import json
from datetime import datetime

class RegionFailureChaos:
    def __init__(self, region, bucket_name="nginx-hello-world"):
        self.region = region
        self.bucket_name = bucket_name
        self.aws_endpoint = "http://localhost:4566"
        self.backup_objects = {}
        
    def run_aws_command(self, cmd):
        """Execute AWS CLI command via docker"""
        full_cmd = [
            "docker", "run", "--rm", "--network", "host",
            "-e", "AWS_ACCESS_KEY_ID=test",
            "-e", "AWS_SECRET_ACCESS_KEY=test",
            "-e", f"AWS_DEFAULT_REGION={self.region}",
            "amazon/aws-cli",
            "--endpoint-url", self.aws_endpoint
        ] + cmd.split()
        
        result = subprocess.run(full_cmd, capture_output=True, text=True)
        return result.returncode, result.stdout, result.stderr
    
    def backup_object(self, key):
        """Backup S3 object content before deletion"""
        print(f"  Backing up {key}...")
        code, stdout, stderr = self.run_aws_command(f"s3 cp s3://{self.bucket_name}/{key} -")
        if code == 0:
            self.backup_objects[key] = stdout
            return True
        return False
    
    def inject_failure(self):
        """Simulate region failure by removing/corrupting S3 objects"""
        print(f"\n🔥 CHAOS: Injecting failure in {self.region}")
        print("=" * 50)
        
        # Get region-specific object key
        if self.region == "us-east-1":
            object_key = "us-east-1.html"
        else:
            object_key = "us-east-2.html"
        
        # Backup the object
        if self.backup_object(object_key):
            # Delete the object to simulate failure
            print(f"  Deleting {object_key} to simulate region failure...")
            code, stdout, stderr = self.run_aws_command(
                f"s3 rm s3://{self.bucket_name}/{object_key}"
            )
            
            if code == 0:
                print(f"  ✓ Region {self.region} is now in failure state")
                return True
            else:
                print(f"  ✗ Failed to delete object: {stderr}")
                return False
        else:
            print(f"  ✗ Failed to backup object")
            return False
    
    def recover(self):
        """Recover from the failure by restoring objects"""
        print(f"\n🔧 RECOVERY: Restoring {self.region}")
        print("=" * 50)
        
        for key, content in self.backup_objects.items():
            print(f"  Restoring {key}...")
            # Write content to temp file and upload
            with open(f"/tmp/{key}", "w") as f:
                f.write(content)
            
            # Upload the file back
            code, stdout, stderr = subprocess.run([
                "docker", "run", "--rm", "--network", "host",
                "-v", "/tmp:/tmp",
                "-e", "AWS_ACCESS_KEY_ID=test",
                "-e", "AWS_SECRET_ACCESS_KEY=test",
                "-e", f"AWS_DEFAULT_REGION={self.region}",
                "amazon/aws-cli",
                "--endpoint-url", self.aws_endpoint,
                "s3", "cp", f"/tmp/{key}", f"s3://{self.bucket_name}/{key}",
                "--content-type", "text/html",
                "--acl", "public-read"
            ], capture_output=True, text=True).returncode, "", ""
            
            if code == 0:
                print(f"  ✓ Restored {key}")
            else:
                print(f"  ✗ Failed to restore {key}")
        
        print(f"  ✓ Region {self.region} has been recovered")

def test_availability(url):
    """Test if a URL is accessible"""
    try:
        result = subprocess.run(
            ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", url],
            capture_output=True, text=True
        )
        return result.stdout.strip() == "200"
    except:
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python region_failure.py <us-east-1|us-east-2|both>")
        sys.exit(1)
    
    target = sys.argv[1]
    base_url = "http://localhost:4566/nginx-hello-world"
    
    print("🧪 Region Failure Chaos Test")
    print("=" * 50)
    print(f"Target: {target}")
    print(f"Time: {datetime.now()}")
    print()
    
    # Pre-test health check
    print("📊 Pre-test Health Check:")
    us_east_1_healthy = test_availability(f"{base_url}/us-east-1.html")
    us_east_2_healthy = test_availability(f"{base_url}/us-east-2.html")
    print(f"  US-EAST-1: {'✓ Healthy' if us_east_1_healthy else '✗ Unhealthy'}")
    print(f"  US-EAST-2: {'✓ Healthy' if us_east_2_healthy else '✗ Unhealthy'}")
    
    # Create chaos instances
    chaos_instances = []
    if target in ["us-east-1", "both"]:
        chaos_instances.append(RegionFailureChaos("us-east-1"))
    if target in ["us-east-2", "both"]:
        chaos_instances.append(RegionFailureChaos("us-east-2"))
    
    # Inject failures
    for chaos in chaos_instances:
        chaos.inject_failure()
    
    # Wait and monitor
    print("\n⏱️  Monitoring system behavior for 30 seconds...")
    for i in range(6):
        time.sleep(5)
        us_east_1_status = test_availability(f"{base_url}/us-east-1.html")
        us_east_2_status = test_availability(f"{base_url}/us-east-2.html")
        print(f"  [{i*5}s] US-EAST-1: {'✓' if us_east_1_status else '✗'} | "
              f"US-EAST-2: {'✓' if us_east_2_status else '✗'}")
    
    # Recover
    input("\nPress Enter to recover...")
    for chaos in chaos_instances:
        chaos.recover()
    
    # Post-recovery health check
    print("\n📊 Post-recovery Health Check:")
    time.sleep(2)
    us_east_1_healthy = test_availability(f"{base_url}/us-east-1.html")
    us_east_2_healthy = test_availability(f"{base_url}/us-east-2.html")
    print(f"  US-EAST-1: {'✓ Healthy' if us_east_1_healthy else '✗ Unhealthy'}")
    print(f"  US-EAST-2: {'✓ Healthy' if us_east_2_healthy else '✗ Unhealthy'}")
    
    print("\n✅ Chaos test completed!")

if __name__ == "__main__":
    main()