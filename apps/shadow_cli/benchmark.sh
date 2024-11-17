#!/bin/bash

FULL_PATH_TO_SCRIPT="$(realpath "${BASH_SOURCE[-1]}")"
SCRIPT_DIRECTORY="$(dirname "$FULL_PATH_TO_SCRIPT")"

node_count="10,4,3,2,1"

algos="yescrypt,bcrypt,sha512crypt,sha256crypt,md5crypt"

IFS=',' read -r -a algo_array <<< "$algos"
IFS=',' read -r -a node_array <<< "$node_count"


echo "==Network Configuration=="
echo "If the data-node & worker nodes are executing on the same local machine, these parameters can be left blank."
read -p "  * Specify data-node fully qualified name: " data_node
read -p "  * Specify data-node security cookie: " cookie_arg
read -p "  * Specify local machine ip (must be accessible to data-node): " interface_name

read -p "Optionally, specify a custom password to use for benchmarking [tpw]: " benchmark_password

if [ -z "$benchmark_password"]; then
    benchmark_password=tpw
fi

if [ -n "$cookie_arg" ]; then
    cookie_arg="--cookie $cookie_arg"
fi

if [ -n "$data_node" ]; then
    data_node="--data-node $data_node"
fi

if [ -n "$interface_name" ]; then
    interface_name="--interface $interface_name"
fi

echo ""

echo "Will submit jobs with the following command form:"
echo "    mix shadow_cli submit --password \$(mkpasswd -m ... $benchmark_password) --get-results $data_node $cookie_arg $interface_name"
echo ""
read -p "Press enter to accept or CTRL + C to abort."

echo ""

echo "Starting benchmark"

mkdir -p $SCRIPT_DIRECTORY/benchmark

rm $SCRIPT_DIRECTORY/benchmark/*.dat &> /dev/null
rm $SCRIPT_DIRECTORY/benchmark/*.png &> /dev/null


for t in "${node_array[@]}"; do
    echo "To configure collecting benchmark data, please configure cluster with only $t nodes."
    read -p "Press enter when configured for $t nodes..."

    for algo in "${algo_array[@]}"; do
        echo "Benchmarking Node Performance for: $algo and $t nodes"
        a=$(mix shadow_cli submit --password $(mkpasswd -m $algo $benchmark_password) --get-results $data_node $cookie_arg $interface_name)
        echo $t $a >> $SCRIPT_DIRECTORY/benchmark/$algo.dat
        echo "Done, sleeping to stabilize..."
        sleep 20
    done
done

(cd $SCRIPT_DIRECTORY/benchmark && gnuplot plot.gp)
cp $SCRIPT_DIRECTORY/benchmark/output.png benchmark_graph.png
