#!/bin/bash

#Get the PID of my_program, which is the Interoperability code, and write it inti Interop.pid file

sleep 1

nohup /home/indicatic-e1/Desktop/code/Interop_code/my_program > /dev/null 2>&1 & echo $! > /tmp/Interop.pid
