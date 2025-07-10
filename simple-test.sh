#!/bin/bash

echo "Testing nginx deployment with region-specific content"
echo "===================================================="
echo ""

echo "1. Testing main index.html (client-side round-robin):"
echo "   curl http://localhost:4566/nginx-hello-world/index.html"
echo ""

echo "2. Direct access to region-specific pages:"
echo ""
echo "   US-EAST-1 page:"
echo "   curl http://localhost:4566/nginx-hello-world/us-east-1.html"
echo ""
echo "   US-EAST-2 page:"  
echo "   curl http://localhost:4566/nginx-hello-world/us-east-2.html"
echo ""

echo "Note: The main index.html uses JavaScript to simulate round-robin"
echo "      behavior in the browser. Open it in a web browser and refresh"
echo "      to see the regions alternate."