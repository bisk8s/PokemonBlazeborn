#!/bin/bash

(
    sleep 4
    echo "started-mgba-server"
)&

"$MGBA_EXECUTABLE" $1 -g