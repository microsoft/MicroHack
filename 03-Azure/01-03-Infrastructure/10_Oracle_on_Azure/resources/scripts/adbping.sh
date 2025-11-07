#!/bin/bash
# ADB Ping Script - Test connectivity and latency to Oracle Autonomous Database
# Usage: ./adbping.sh <connection_string> <username> <password> [iterations]

set -e

CONNECTION_STRING="${1}"
USERNAME="${2}"
PASSWORD="${3}"
ITERATIONS="${4:-10}"

if [ -z "$CONNECTION_STRING" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Usage: $0 <connection_string> <username> <password> [iterations]"
    echo "Example: $0 '(description=...)' admin Welcome1234# 10"
    exit 1
fi

echo "=== ADB Connectivity Test ==="
echo "Target: ${CONNECTION_STRING}"
echo "User: ${USERNAME}"
echo "Iterations: ${ITERATIONS}"
echo "================================"
echo ""

# Test 1: TNS Ping
echo "1. Testing TNS connectivity..."
if command -v tnsping &> /dev/null; then
    tnsping "${CONNECTION_STRING}" || echo "   ⚠️  TNS ping failed"
else
    echo "   ⚠️  tnsping not available"
fi
echo ""

# Test 2: SQL*Plus Connection Time
echo "2. Measuring SQL*Plus connection time (${ITERATIONS} attempts)..."
total_time=0
success_count=0

for i in $(seq 1 ${ITERATIONS}); do
    start_time=$(date +%s%3N)
    
    # Attempt connection with simple query
    if echo "SELECT 1 FROM DUAL; EXIT;" | sqlplus -S "${USERNAME}/${PASSWORD}@${CONNECTION_STRING}" > /dev/null 2>&1; then
        end_time=$(date +%s%3N)
        elapsed=$((end_time - start_time))
        total_time=$((total_time + elapsed))
        success_count=$((success_count + 1))
        echo "   Attempt ${i}: ${elapsed} ms ✓"
    else
        echo "   Attempt ${i}: Failed ✗"
    fi
    
    sleep 1
done

echo ""
if [ ${success_count} -gt 0 ]; then
    avg_time=$((total_time / success_count))
    echo "✓ Success Rate: ${success_count}/${ITERATIONS}"
    echo "✓ Average Connection Time: ${avg_time} ms"
else
    echo "✗ All connection attempts failed"
    exit 1
fi
echo ""

# Test 3: Network Round-Trip Latency (using SQL query)
echo "3. Measuring network round-trip latency..."
sqlplus -S "${USERNAME}/${PASSWORD}@${CONNECTION_STRING}" <<'EOF'
SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET HEADING OFF
DECLARE
    v_start NUMBER;
    v_end NUMBER;
    v_roundtrips_start NUMBER;
    v_roundtrips_end NUMBER;
    v_latency NUMBER;
BEGIN
    -- Get initial stats
    SELECT value INTO v_roundtrips_start
    FROM v$mystat m, v$statname n
    WHERE m.statistic# = n.statistic#
    AND n.name = 'SQL*Net roundtrips to/from client';
    
    v_start := DBMS_UTILITY.GET_TIME;
    
    -- Perform dummy queries to generate round trips
    FOR i IN 1..100 LOOP
        EXECUTE IMMEDIATE 'SELECT 1 FROM DUAL' INTO v_end;
    END LOOP;
    
    v_end := DBMS_UTILITY.GET_TIME;
    
    -- Get final stats
    SELECT value INTO v_roundtrips_end
    FROM v$mystat m, v$statname n
    WHERE m.statistic# = n.statistic#
    AND n.name = 'SQL*Net roundtrips to/from client';
    
    v_latency := ((v_end - v_start) * 10) / (v_roundtrips_end - v_roundtrips_start);
    
    DBMS_OUTPUT.PUT_LINE('   Network Round Trips: ' || (v_roundtrips_end - v_roundtrips_start));
    DBMS_OUTPUT.PUT_LINE('   Average Latency per Round Trip: ' || ROUND(v_latency, 3) || ' ms');
END;
/
EXIT
EOF

echo ""
echo "=== Test Complete ==="
