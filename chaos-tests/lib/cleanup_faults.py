#!/usr/bin/env python3
"""
Cleanup all active chaos faults
"""

import requests
import json

def cleanup_all_faults():
    """Remove all active chaos faults from LocalStack"""
    chaos_api_url = "http://localhost:4566/_localstack/chaos/faults"
    
    try:
        # Get all active faults
        response = requests.get(chaos_api_url)
        if response.status_code == 200:
            faults = response.json()
            if not faults:
                print("No active faults to clean up")
                return True
                
            print(f"Found {len(faults)} active fault(s) to clean up:")
            
            # LocalStack doesn't support individual fault deletion by ID
            # We need to clear all faults by setting an empty array
            clear_response = requests.post(chaos_api_url, json=[])
            
            if clear_response.status_code == 200:
                print("✓ All faults cleared successfully")
                return True
            else:
                print(f"✗ Failed to clear faults: {clear_response.status_code}")
                return False
        else:
            print(f"Failed to get faults: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"Error during cleanup: {e}")
        return False

if __name__ == "__main__":
    cleanup_all_faults()