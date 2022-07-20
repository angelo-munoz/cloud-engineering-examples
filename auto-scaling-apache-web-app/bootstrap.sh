#!/bin/bash
echo "Hello go cloud engineers!"

# using the ip command since the ifconfig requires package install
ipaddress=$( ip address show | grep "eth0$" | awk '{ print $2 }' )
echo $ipaddress

# showos parameter to determine support for certain functions
if [[ $1 == "showos" ]]; then
	uname -a
fi


# Build an Apache web application, with autoscaling
# install web server
sudo apt update -y #<< 7/16 added
sudo apt install apache2 -y
sudo service apache2 start

#save ip address to the index.html file for display and potential troubleshooting
# if needed
echo $ipaddress > /var/www/html/index.html
echo "hello, Go Cloud Engineers" >> /var/www/html/index.html

# demonstrate autoscaling
sudo apt install stress -y

# run stress! 
stress --cpu 1 --io 4 --vm 2 --vm-bytes 128M --timeout 30s

echo "done"














