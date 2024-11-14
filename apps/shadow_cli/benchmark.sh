#!/bin/bash

FULL_PATH_TO_SCRIPT="$(realpath "${BASH_SOURCE[-1]}")"
SCRIPT_DIRECTORY="$(dirname "$FULL_PATH_TO_SCRIPT")"

mkdir -p $SCRIPT_DIRECTORY/benchmark

rm $SCRIPT_DIRECTORY/benchmark/*.dat &> /dev/null
rm $SCRIPT_DIRECTORY/benchmark/*.png &> /dev/null

node_count="10,4,3,2,1"

algos="yescrypt,gost-yescrypt,scrypt,bcrypt,bcrypt-a,sha512crypt,sha256crypt,sunmd5,md5crypt,descrypt,nt"
#algos="yescrypt,md5crypt"
IFS=',' read -r -a algo_array <<< "$algos"
IFS=',' read -r -a node_array <<< "$node_count"

for t in "${node_array[@]}"; do
    echo "Truncating for $t nodes..."
    #sleep 10 #Sleep to stabalize / flush from work pools...
    #number_clients="" #$(| sed -nE 's/.*Password cracked for command_line_entry in ([0-9\.]+) seconds.*/\1/p'))
    number_clients=$(mix shadow_cli truncate-clients $t | sed -nE 's/.*Number of active clients: ([0-9\.]+)*/\1/p')
    
    if [ $number_clients != $t ]; then
        echo "Error, incorrect number of active clients. Terminating early."
        echo "Make sure you've spawned the correct number of initial nodes for benchmarking (10)"
        exit 1
    fi

    #sleep 10
    for algo in "${algo_array[@]}"; do
        echo "Benchmarking Thread Performance for: $algo and $t nodes"
        a=$(mix shadow_cli submit --password $(mkpasswd -m $algo tp) --get-results | sed -nE 's/.*Result :: .* :: ([0-9\.]+)s*/\1/p')
        echo $t $a >> $SCRIPT_DIRECTORY/benchmark/$algo.dat
    done
done

(cd $SCRIPT_DIRECTORY/benchmark && gnuplot plot.gp)
cp $SCRIPT_DIRECTORY/benchmark/output.png benchmark_graph.png