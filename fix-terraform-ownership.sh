#!/bin/bash

echo "Fixing terraform file ownership..."
echo "Please run: sudo chown -R $(id -u):$(id -g) terraform/"
echo ""
echo "This will fix the ownership of all terraform files to match your user."