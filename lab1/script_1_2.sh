#!/bin/bash

recieve_hardware_information () {
  card_model=$(lshw -c network | grep product | awk '{print substr( $0, index($0,$2) )}')
  mac=$(lshw -c network | grep serial | awk '{print substr( $0, index($0,$2) )}')
  speed=$(ethtool enp0s3 | grep Speed | awk '{print $2}')
  duplex=$(ethtool enp0s3 | grep Duplex | awk '{print $2}')
  link=$(ethtool enp0s3 | grep Link | awk '{print $3}')
  echo "Network card model: $card_model\nChannel speed: $speed\nWork type: $duplex\nLink: $link\nMac: $mac"
}

recieve_ipv4_information () {
  ip=$(ip a | grep enp0s3 | head -n 2 | tail -n 1 | awk '{print $2}')
  mask=$(ip a | grep enp0s3 | head -n 2 | tail -n 1 | awk '{print $4}')
  gate=$(ip r | grep default | awk '{print $3}')
  dns=$(cat /etc/resolv.conf)
  echo "IP: $ip\nMask: $mask\nGate: $gate\nDNS: $dns"
}

setup_first_scenario () {
  ip -4 a flush dev enp0s3
  ip a add 10.100.0.2 brd 255.255.255.0 dev enp0s3
  if ip r | grep -q "default"; then
    ip r del default
  fi
  ip a add 10.100.0.1 dev enp0s3
  ip r add default via 10.100.0.1 dev enp0s3
  if grep -q "nameserver 8.8.8.8" /etc/resolv.conf; then
    :
  else
    sed -i '1i nameserver 8.8.8.8' /etc/resolv.conf
  fi
}

setup_second_scenario () {
  dhclient -r enp0s3
  dhclient enp0s3
}

answer=""

while true; do
  clear
  echo -e "Chose wisely:\n1)Recieve hardware information\n2)Recieve IPv4 config information\n3)Set up first scenario\n4)Set up second scenario\n5)exit"
  read -r answer
  clear
  case $answer in
    1)
      echo -e "$(recieve_hardware_information)"
      ;;

    2)
      echo -e "$(recieve_ipv4_information)"
      ;;

    3)
      setup_first_scenario
      echo 'done'
      ;;

    4)
      setup_second_scenario
      echo 'done'
      ;;

    5)
      exit 1
      ;;

    *)
      echo "Try again"
      ;;
  esac
  read -rp "Press any button to continue..."
done
