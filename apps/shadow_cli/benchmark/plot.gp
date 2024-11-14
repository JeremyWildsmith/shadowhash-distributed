set terminal png size 1200,800
set output 'output.png'


set title "Impact of Nodes on Bruteforce Time"
set xlabel "Nodes"
set ylabel "Time (Seconds)"

# Set the position of the legend
set key outside right top

# Optionally, adjust the box and spacing
set key box

set xtics 1 
set yrange [0:*]

set multiplot layout 3,1 rowsfirst
plot 'md5crypt.dat' with lines title("md5crypt"), \
     'bcrypt.dat' with lines title("bcrypt"), \
     'bcrypt-a.dat' with lines title("bcrypt-a"), \
     'sha512crypt.dat' with lines title("sha512crypt"), \
     'sha256crypt.dat' with lines title("sha256crypt"), \
     'descrypt.dat' with lines title("descrypt"), \
     'nt.dat' with lines title("nt")

plot 'yescrypt.dat' with lines title("yescrypt"), \
     'gost-yescrypt.dat' with lines title("gost-yescrypt"), \

plot 'scrypt.dat' with lines title("scrypt"), \
     'sunmd5.dat' with lines title("sunmd5")
unset multiplot