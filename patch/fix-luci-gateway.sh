#!/bin/sh
# Fix LuCI Bad Gateway issue - ensure rpcd and uhttpd are running properly

echo "Fixing LuCI Bad Gateway issue..."

# Restart ubus first
/etc/init.d/ubus restart
sleep 2

# Restart rpcd with proper configuration
/etc/init.d/rpcd restart
sleep 2

# Restart uhttpd
/etc/init.d/uhttpd restart
sleep 1

# Check if services are running
if pgrep -x rpcd > /dev/null; then
    echo "✓ rpcd is running"
else
    echo "✗ rpcd failed to start"
    exit 1
fi

if pgrep -x uhttpd > /dev/null; then
    echo "✓ uhttpd is running"
else
    echo "✗ uhttpd failed to start"
    exit 1
fi

echo "LuCI services restarted successfully"
