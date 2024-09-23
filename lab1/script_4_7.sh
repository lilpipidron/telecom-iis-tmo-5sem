#!/bin/bash

date +%T
cat /proc/net/dev | tail -n +4 | awk '{print $1, "recieve", $2, "transmit", $10}'
