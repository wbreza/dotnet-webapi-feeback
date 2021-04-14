#!/usr/bin/env bash

echo-azure-credentials() {
    echo $AZURE_CREDENTIALS
}

# Call requested function and pass arguments as-they-are
"$@"
