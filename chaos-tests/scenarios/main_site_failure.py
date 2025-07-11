#!/usr/bin/env python3
"""
Main Site Failure Test
Verifies that the main site (VIP) is considered offline when both regions are down
"""

import subprocess
import time
import sys
import json
import os
from datetime import datetime

# Report test status to monitoring
def report_status(test_type, target, status, details):
    """Report test status for monitoring"""
    try:
        status_cmd = [
            "/bin/bash", "-c",
            f"source {os.path.dirname(__file__)}/../lib/test_status.sh && write_test_status '{test_type}' '{target}' '{status}' '{details}'"
        ]
        subprocess.run(status_cmd, capture_output=True)
    except:
        pass  # Don't fail the test if status reporting fails

class MainSiteFailureTest:
    def __init__(self):
        self.bucket_name = "nginx-hello-world"
        self.aws_endpoint = "http://localhost:4566"
        self.backup_objects = {}
        self.main_site_url = "http://localhost:4566/nginx-hello-world/index.html"
        self.us_east_1_url = "http://localhost:4566/nginx-hello-world/us-east-1.html"
        self.us_east_2_url = "http://localhost:4566/nginx-hello-world/us-east-2.html"
        
    def run_aws_command(self, cmd, region="us-east-1"):
        """Execute AWS CLI command via docker"""
        full_cmd = [
            "docker", "run", "--rm", "--network", "host",
            "-e", "AWS_ACCESS_KEY_ID=test",
            "-e", "AWS_SECRET_ACCESS_KEY=test",
            "-e", f"AWS_DEFAULT_REGION={region}",
            "amazon/aws-cli",
            "--endpoint-url", self.aws_endpoint
        ] + cmd.split()
        
        result = subprocess.run(full_cmd, capture_output=True, text=True)
        return result.returncode, result.stdout, result.stderr
    
    def backup_object(self, key, region="us-east-1"):
        """Backup S3 object content before deletion"""
        print(f"  Backing up {key}...")
        code, stdout, stderr = self.run_aws_command(f"s3 cp s3://{self.bucket_name}/{key} -", region)
        if code == 0:
            self.backup_objects[key] = stdout
            return True
        return False
    
    def test_endpoint(self, url, name):
        """Test if an endpoint is accessible and return detailed status"""
        try:
            # Get both status code and response time
            result = subprocess.run(
                ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code},%{time_total}", url, "--max-time", "5"],
                capture_output=True, text=True
            )
            output = result.stdout.strip()
            if "," in output:
                http_code, response_time = output.split(",")
                is_healthy = http_code == "200"
                return {
                    "name": name,
                    "url": url,
                    "healthy": is_healthy,
                    "http_code": http_code,
                    "response_time": float(response_time)
                }
            else:
                return {
                    "name": name,
                    "url": url,
                    "healthy": False,
                    "http_code": "000",
                    "response_time": 5.0
                }
        except Exception as e:
            return {
                "name": name,
                "url": url,
                "healthy": False,
                "http_code": "error",
                "response_time": 0.0,
                "error": str(e)
            }
    
    def print_status_table(self, statuses):
        """Print a formatted status table"""
        print("\n  ┌─────────────────┬──────────┬──────────────┬───────────────┐")
        print("  │ Endpoint        │ Status   │ HTTP Code    │ Response Time │")
        print("  ├─────────────────┼──────────┼──────────────┼───────────────┤")
        for status in statuses:
            status_icon = "✓" if status["healthy"] else "✗"
            status_text = "OK" if status["healthy"] else "FAILED"
            response_time = f"{status['response_time']:.3f}s"
            print(f"  │ {status['name']:<15} │ {status_icon} {status_text:<6} │ {status['http_code']:<12} │ {response_time:<13} │")
        print("  └─────────────────┴──────────┴──────────────┴───────────────┘")
    
    def check_all_endpoints(self):
        """Check all endpoints and return their status"""
        return [
            self.test_endpoint(self.main_site_url, "Main Site"),
            self.test_endpoint(self.us_east_1_url, "US-EAST-1"),
            self.test_endpoint(self.us_east_2_url, "US-EAST-2")
        ]
    
    def take_down_region(self, region):
        """Simulate region failure by removing S3 object"""
        object_key = f"{region}.html"
        
        # Backup the object
        if self.backup_object(object_key):
            # Delete the object to simulate failure
            print(f"  Taking down {region}...")
            code, stdout, stderr = self.run_aws_command(
                f"s3 rm s3://{self.bucket_name}/{object_key}"
            )
            
            if code == 0:
                print(f"  ✓ Region {region} is now offline")
                return True
            else:
                print(f"  ✗ Failed to take down region: {stderr}")
                return False
        else:
            print(f"  ✗ Failed to backup object")
            return False
    
    def restore_region(self, region):
        """Restore region by uploading backed up object"""
        object_key = f"{region}.html"
        
        if object_key in self.backup_objects:
            print(f"  Restoring {region}...")
            # Write content to temp file and upload
            with open(f"/tmp/{object_key}", "w") as f:
                f.write(self.backup_objects[object_key])
            
            # Upload the file back
            code, stdout, stderr = subprocess.run([
                "docker", "run", "--rm", "--network", "host",
                "-v", "/tmp:/tmp",
                "-e", "AWS_ACCESS_KEY_ID=test",
                "-e", "AWS_SECRET_ACCESS_KEY=test",
                "-e", f"AWS_DEFAULT_REGION=us-east-1",
                "amazon/aws-cli",
                "--endpoint-url", self.aws_endpoint,
                "s3", "cp", f"/tmp/{object_key}", f"s3://{self.bucket_name}/{object_key}",
                "--content-type", "text/html",
                "--acl", "public-read"
            ], capture_output=True, text=True).returncode, "", ""
            
            if code == 0:
                print(f"  ✓ Region {region} restored")
                return True
            else:
                print(f"  ✗ Failed to restore {region}")
                return False
        return False
    
    def run_test(self):
        """Run the main site failure test"""
        print("🧪 Main Site Failure Test")
        print("=" * 60)
        print("This test verifies that the main site is considered offline")
        print("when both regions are down, simulating a complete outage.")
        print(f"Time: {datetime.now()}")
        print()
        
        # Report test starting
        report_status("main-site-failure", "both-regions", "active", 
                     "Testing main site behavior with both regions down")
        
        # Phase 1: Initial health check
        print("📊 Phase 1: Initial Health Check")
        print("-" * 40)
        statuses = self.check_all_endpoints()
        self.print_status_table(statuses)
        
        # Verify all endpoints are healthy
        if not all(s["healthy"] for s in statuses):
            print("\n❌ ERROR: Not all endpoints are healthy at start!")
            print("   Please ensure the infrastructure is properly deployed.")
            return False
        
        print("\n✅ All endpoints are healthy. Proceeding with test...")
        time.sleep(2)
        
        # Phase 2: Take down US-EAST-1
        print("\n📊 Phase 2: Taking down US-EAST-1")
        print("-" * 40)
        if not self.take_down_region("us-east-1"):
            print("❌ Failed to take down US-EAST-1")
            return False
        
        time.sleep(3)
        statuses = self.check_all_endpoints()
        self.print_status_table(statuses)
        
        # Verify US-EAST-1 is down but main site still up (via US-EAST-2)
        us_east_1_status = next(s for s in statuses if s["name"] == "US-EAST-1")
        main_site_status = next(s for s in statuses if s["name"] == "Main Site")
        
        if us_east_1_status["healthy"]:
            print("\n❌ ERROR: US-EAST-1 should be down!")
            return False
        
        print(f"\n✅ US-EAST-1 is down. Main site status: {'UP' if main_site_status['healthy'] else 'DOWN'}")
        
        # Phase 3: Take down US-EAST-2
        print("\n📊 Phase 3: Taking down US-EAST-2 (both regions down)")
        print("-" * 40)
        if not self.take_down_region("us-east-2"):
            print("❌ Failed to take down US-EAST-2")
            return False
        
        time.sleep(3)
        statuses = self.check_all_endpoints()
        self.print_status_table(statuses)
        
        # Verify both regions and main site are down
        us_east_1_status = next(s for s in statuses if s["name"] == "US-EAST-1")
        us_east_2_status = next(s for s in statuses if s["name"] == "US-EAST-2")
        main_site_status = next(s for s in statuses if s["name"] == "Main Site")
        
        print("\n🔍 Test Results:")
        print(f"   US-EAST-1: {'DOWN ✓' if not us_east_1_status['healthy'] else 'UP ✗'}")
        print(f"   US-EAST-2: {'DOWN ✓' if not us_east_2_status['healthy'] else 'UP ✗'}")
        print(f"   Main Site: {'DOWN ✓' if not main_site_status['healthy'] else 'UP ✗'}")
        
        # This is the key test: main site should be down when both regions are down
        test_passed = (not us_east_1_status["healthy"] and 
                      not us_east_2_status["healthy"] and 
                      not main_site_status["healthy"])
        
        if test_passed:
            print("\n✅ TEST PASSED: Main site correctly shows as offline when both regions are down!")
        else:
            print("\n❌ TEST FAILED: Main site behavior incorrect!")
            if main_site_status["healthy"]:
                print("   Main site is still showing as UP when both regions are DOWN!")
        
        # Phase 4: Recovery
        print("\n📊 Phase 4: Recovery")
        print("-" * 40)
        report_status("main-site-failure", "both-regions", "recovering", 
                     "Restoring both regions")
        
        print("Restoring regions...")
        self.restore_region("us-east-1")
        self.restore_region("us-east-2")
        
        time.sleep(3)
        statuses = self.check_all_endpoints()
        self.print_status_table(statuses)
        
        # Verify all endpoints are healthy again
        all_healthy = all(s["healthy"] for s in statuses)
        if all_healthy:
            print("\n✅ All endpoints successfully recovered!")
        else:
            print("\n⚠️  Warning: Not all endpoints recovered properly")
        
        # Clean up status
        report_status("main-site-failure", "both-regions", "completed", 
                     f"Test {'passed' if test_passed else 'failed'}")
        
        return test_passed


def main():
    test = MainSiteFailureTest()
    
    # Run the test
    success = test.run_test()
    
    print("\n" + "=" * 60)
    if success:
        print("✅ Main Site Failure Test: PASSED")
        print("The main site correctly shows as offline when both regions are down.")
        sys.exit(0)
    else:
        print("❌ Main Site Failure Test: FAILED")
        print("The main site behavior is incorrect when both regions are down.")
        sys.exit(1)


if __name__ == "__main__":
    main()