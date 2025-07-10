#!/usr/bin/env python3
"""
Base class for chaos tests with automatic cleanup
"""

import atexit
import signal
import sys
import requests
import json
from abc import ABC, abstractmethod

class ChaosTestBase(ABC):
    """Base class for all chaos tests with automatic cleanup"""
    
    def __init__(self):
        self.chaos_api_url = "http://localhost:4566/_localstack/chaos/faults"
        self.fault_ids = []
        self._setup_cleanup_handlers()
    
    def _setup_cleanup_handlers(self):
        """Setup cleanup handlers for graceful shutdown"""
        # Register cleanup on normal exit
        atexit.register(self._cleanup)
        
        # Register cleanup on signals
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handle interrupt signals"""
        print("\n\n⚠️  Interrupted! Cleaning up...")
        self._cleanup()
        sys.exit(1)
    
    def _cleanup(self):
        """Clean up all injected faults"""
        if not self.fault_ids:
            return
            
        print("\n🧹 Cleaning up chaos faults...")
        cleaned = 0
        
        # Try to remove individual faults first
        for fault_id in self.fault_ids:
            if fault_id:
                try:
                    response = requests.delete(f"{self.chaos_api_url}/{fault_id}")
                    if response.status_code in [200, 204]:
                        cleaned += 1
                except:
                    pass
        
        # If we couldn't clean all faults individually, clear all
        if cleaned < len(self.fault_ids):
            try:
                # Clear all faults by posting empty array
                requests.post(self.chaos_api_url, json=[])
                print("  ✓ All faults cleared")
            except:
                print("  ✗ Failed to clear some faults")
        else:
            print(f"  ✓ Cleaned up {cleaned} fault(s)")
    
    def add_fault_id(self, fault_id):
        """Track a fault ID for cleanup"""
        if fault_id:
            self.fault_ids.append(fault_id)
    
    @abstractmethod
    def inject_chaos(self):
        """Inject the chaos scenario - must be implemented by subclass"""
        pass
    
    @abstractmethod
    def test_impact(self):
        """Test the impact of the chaos - must be implemented by subclass"""
        pass
    
    @abstractmethod
    def recover(self):
        """Recover from the chaos - must be implemented by subclass"""
        pass
    
    def run(self):
        """Run the complete chaos test lifecycle"""
        try:
            # Inject chaos
            if not self.inject_chaos():
                print("❌ Failed to inject chaos")
                return False
            
            # Test impact
            self.test_impact()
            
            # Wait for user input
            input("\nPress Enter to recover...")
            
            # Recover
            self.recover()
            
            return True
            
        finally:
            # Cleanup will be called automatically
            pass