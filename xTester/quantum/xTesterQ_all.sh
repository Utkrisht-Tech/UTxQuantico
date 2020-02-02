#!/bin/bash
try() {
    want = "$1"
    inp = "$2"

    ./UTxQ "$inp" > UTxQ_Gen.s
    gcc -o UTxQ_Gen UTxQ_Gen.s
    ./UTxQ_Gen
    out = "$?"

    if [ "$out" = "$want" ]; then
        echo "$inp => $want"
    else
        echo "$inp => $want expected, got $out"
        exit 1
    fi
}

try 0 0
try 150 150
try 100 100

echo "TESTS PASSED"