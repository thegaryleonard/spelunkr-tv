#!/bin/bash
cd "$(dirname "$0")"
rm -f actual.txt
node ../tools/node_modules/@rokucommunity/brs/bin/cli.js --root . ../app/source/engine.brs compare_main.brs > run_all.log 2>&1 < /dev/null
diff expected.txt actual.txt > diff.txt
echo "DIFF: $(grep -c '^<' diff.txt) of $(wc -l < expected.txt)" >> run_all.log
