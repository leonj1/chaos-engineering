#!/usr/bin/env python3
"""
Latency Injection Chaos Scenario
Simulates network latency by creating delayed responses
"""

import subprocess
import time
import sys
import tempfile
import os
from datetime import datetime

class LatencyInjectionChaos:
    def __init__(self, region, latency_ms=2000):
        self.region = region
        self.latency_ms = latency_ms
        self.bucket_name = "nginx-hello-world"
        self.aws_endpoint = "http://localhost:4566"
        self.original_content = {}
        
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
    
    def inject_latency(self):
        """Inject latency by replacing content with a delayed loading version"""
        print(f"\n⏱️  CHAOS: Injecting {self.latency_ms}ms latency in {self.region}")
        print("=" * 50)
        
        # Get region-specific object key
        object_key = f"{self.region}.html"
        
        # Download original content
        print(f"  Backing up original content...")
        code, stdout, stderr = self.run_aws_command(f"s3 cp s3://{self.bucket_name}/{object_key} -")
        if code != 0:
            print(f"  ✗ Failed to download original content: {stderr}")
            return False
        
        self.original_content[object_key] = stdout
        
        # Create delayed response HTML
        delayed_html = f"""<!DOCTYPE html>
<html>
<head>
    <title>Nginx - {self.region.upper()} Region (Delayed)</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: #f0f0f0;
        }}
        .loading {{
            text-align: center;
            padding: 50px;
        }}
        .spinner {{
            border: 4px solid #f3f3f3;
            border-top: 4px solid #3498db;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 20px auto;
        }}
        @keyframes spin {{
            0% {{ transform: rotate(0deg); }}
            100% {{ transform: rotate(360deg); }}
        }}
        .container {{
            display: none;
            text-align: center;
            padding: 50px;
            background-color: white;
            border-radius: 10px;
            box-shadow: 0 0 30px rgba(0,0,0,0.2);
        }}
        .region {{
            font-size: 48px;
            font-weight: bold;
            color: #e74c3c;
            margin: 30px 0;
            padding: 20px;
            border: 3px solid #e74c3c;
            border-radius: 10px;
            background-color: #ffe6e6;
        }}
        .latency-notice {{
            background-color: #fff3cd;
            border: 1px solid #ffeaa7;
            color: #856404;
            padding: 10px;
            border-radius: 5px;
            margin: 20px 0;
        }}
    </style>
</head>
<body>
    <div class="loading" id="loading">
        <h2>Loading from {self.region.upper()}...</h2>
        <div class="spinner"></div>
        <p>Simulating {self.latency_ms}ms latency</p>
    </div>
    
    <div class="container" id="content">
        <h1>🐌 Slow Response from Nginx!</h1>
        <div class="region">{self.region.upper()}</div>
        <div class="latency-notice">
            ⚠️ This region is experiencing simulated latency of {self.latency_ms}ms
        </div>
        <div class="info">
            <p>This response was delayed to simulate network latency</p>
            <p>Chaos Engineering Demo - Latency Injection</p>
        </div>
        <div class="timestamp">
            <p id="time"></p>
        </div>
    </div>
    
    <script>
        // Simulate latency with JavaScript
        setTimeout(function() {{
            document.getElementById('loading').style.display = 'none';
            document.getElementById('content').style.display = 'block';
            document.getElementById('time').textContent = 'Loaded at: ' + new Date().toLocaleString();
        }}, {self.latency_ms});
    </script>
</body>
</html>"""
        
        # Write to temp file and upload
        with tempfile.NamedTemporaryFile(mode='w', suffix='.html', delete=False) as f:
            f.write(delayed_html)
            temp_file = f.name
        
        # Upload the delayed version
        print(f"  Uploading delayed version with {self.latency_ms}ms latency...")
        upload_cmd = [
            "docker", "run", "--rm", "--network", "host",
            "-v", f"{os.path.dirname(temp_file)}:{os.path.dirname(temp_file)}",
            "-e", "AWS_ACCESS_KEY_ID=test",
            "-e", "AWS_SECRET_ACCESS_KEY=test",
            "-e", f"AWS_DEFAULT_REGION={self.region}",
            "amazon/aws-cli",
            "--endpoint-url", self.aws_endpoint,
            "s3", "cp", temp_file, f"s3://{self.bucket_name}/{object_key}",
            "--content-type", "text/html",
            "--acl", "public-read"
        ]
        
        result = subprocess.run(upload_cmd, capture_output=True, text=True)
        os.unlink(temp_file)
        
        if result.returncode == 0:
            print(f"  ✓ Latency injection active for {self.region}")
            return True
        else:
            print(f"  ✗ Failed to upload delayed version: {result.stderr}")
            return False
    
    def recover(self):
        """Remove latency by restoring original content"""
        print(f"\n🔧 RECOVERY: Removing latency from {self.region}")
        print("=" * 50)
        
        for object_key, content in self.original_content.items():
            print(f"  Restoring original {object_key}...")
            
            # Write content to temp file
            with tempfile.NamedTemporaryFile(mode='w', suffix='.html', delete=False) as f:
                f.write(content)
                temp_file = f.name
            
            # Upload original content
            upload_cmd = [
                "docker", "run", "--rm", "--network", "host",
                "-v", f"{os.path.dirname(temp_file)}:{os.path.dirname(temp_file)}",
                "-e", "AWS_ACCESS_KEY_ID=test",
                "-e", "AWS_SECRET_ACCESS_KEY=test",
                "-e", f"AWS_DEFAULT_REGION={self.region}",
                "amazon/aws-cli",
                "--endpoint-url", self.aws_endpoint,
                "s3", "cp", temp_file, f"s3://{self.bucket_name}/{object_key}",
                "--content-type", "text/html",
                "--acl", "public-read"
            ]
            
            result = subprocess.run(upload_cmd, capture_output=True, text=True)
            os.unlink(temp_file)
            
            if result.returncode == 0:
                print(f"  ✓ Restored {object_key}")
            else:
                print(f"  ✗ Failed to restore {object_key}")
        
        print(f"  ✓ Latency removed from {self.region}")

def measure_response_time(url):
    """Measure response time for a URL"""
    try:
        result = subprocess.run(
            ["curl", "-s", "-o", "/dev/null", "-w", "%{time_total}", url],
            capture_output=True, text=True
        )
        return float(result.stdout.strip())
    except:
        return -1

def main():
    if len(sys.argv) < 2:
        print("Usage: python latency_injection.py <us-east-1|us-east-2|both> [latency_ms]")
        sys.exit(1)
    
    target = sys.argv[1]
    latency_ms = int(sys.argv[2]) if len(sys.argv) > 2 else 2000
    base_url = "http://localhost:4566/nginx-hello-world"
    
    print("🧪 Latency Injection Chaos Test")
    print("=" * 50)
    print(f"Target: {target}")
    print(f"Latency: {latency_ms}ms")
    print(f"Time: {datetime.now()}")
    print()
    
    # Pre-test measurements
    print("📊 Pre-test Response Times:")
    us_east_1_time = measure_response_time(f"{base_url}/us-east-1.html")
    us_east_2_time = measure_response_time(f"{base_url}/us-east-2.html")
    print(f"  US-EAST-1: {us_east_1_time:.3f}s")
    print(f"  US-EAST-2: {us_east_2_time:.3f}s")
    
    # Create chaos instances
    chaos_instances = []
    if target in ["us-east-1", "both"]:
        chaos_instances.append(LatencyInjectionChaos("us-east-1", latency_ms))
    if target in ["us-east-2", "both"]:
        chaos_instances.append(LatencyInjectionChaos("us-east-2", latency_ms))
    
    # Inject latency
    for chaos in chaos_instances:
        chaos.inject_latency()
    
    # Monitor response times
    print("\n⏱️  Monitoring response times...")
    print("  (Note: First request after injection may take longer due to caching)")
    
    for i in range(5):
        time.sleep(3)
        us_east_1_time = measure_response_time(f"{base_url}/us-east-1.html")
        us_east_2_time = measure_response_time(f"{base_url}/us-east-2.html")
        print(f"  [{i*3}s] US-E1: {us_east_1_time:.3f}s | US-E2: {us_east_2_time:.3f}s")
    
    # Recover
    input("\nPress Enter to remove latency...")
    for chaos in chaos_instances:
        chaos.recover()
    
    # Post-recovery measurements
    print("\n📊 Post-recovery Response Times:")
    time.sleep(2)
    us_east_1_time = measure_response_time(f"{base_url}/us-east-1.html")
    us_east_2_time = measure_response_time(f"{base_url}/us-east-2.html")
    print(f"  US-EAST-1: {us_east_1_time:.3f}s")
    print(f"  US-EAST-2: {us_east_2_time:.3f}s")
    
    print("\n✅ Latency injection test completed!")

if __name__ == "__main__":
    main()