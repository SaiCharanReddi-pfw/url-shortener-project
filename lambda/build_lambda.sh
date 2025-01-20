#!/bin/bash
set -e

echo "Building Lambda package..."
cd lambda
pip install -r requirements.txt --target .
zip -r lambda.zip .
mv lambda.zip ../terraform/
cd ..
echo "Lambda package built and moved to terraform/ directory."
