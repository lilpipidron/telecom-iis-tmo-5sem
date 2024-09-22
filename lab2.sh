#!/bin/bash

mask_to_cidr() {
  local IFS=.
  local -a octets=($1)
  local cidr=0

  for octet in "${octets[@]}"; do
    case $octet in
      255) cidr=$((cidr + 8)) ;;
      254) cidr=$((cidr + 7)) ;;
      252) cidr=$((cidr + 6)) ;;
      248) cidr=$((cidr + 5)) ;;
      240) cidr=$((cidr + 4)) ;;
      224) cidr=$((cidr + 3)) ;;
      192) cidr=$((cidr + 2)) ;;
      128) cidr=$((cidr + 1)) ;;
      0) ;;
      *) echo "Неверная маска"; exit 1 ;;
    esac
  done

  echo "$cidr"
}

hosts_per_subnet() {
  local cidr=$1
  echo $((2 ** (32 - cidr) - 2)) 
}

calculate_subnet() {
  local ip=$1
  local mask=$2
  local needed_hosts=$3

  local cidr
  cidr=$(mask_to_cidr "$mask")

  local target_cidr=$cidr
  while [[ $(hosts_per_subnet $target_cidr) -lt $needed_hosts ]]; do
    target_cidr=$((target_cidr - 1))
  done

  local network
  network=$(ipcalc -n "$ip/$target_cidr" | grep Network | awk '{print $2}')

  local broadcast
  broadcast=$(ipcalc -b "$network/$target_cidr" | grep Broadcast | awk '{print $2}')

  local first_host
  local last_host
  first_host=$(ipcalc -r "$network/$target_cidr" | grep HostMin | awk '{print $2}')
  last_host=$(ipcalc -r "$network/$target_cidr" | grep HostMax | awk '{print $2}')

  echo "Сеть: $network/$target_cidr"
  echo "Широковещательный адрес: $broadcast"
  echo "Диапазон хостов: $first_host - $last_host"
  echo "Количество хостов: $(hosts_per_subnet $target_cidr)"
  echo ""
}

main() {
  if [[ $# -ne 7 ]]; then
    echo "Использование: $0 <IP> <маска> <хосты_сеть1> <хосты_сеть2> <хосты_сеть3> <хосты_сеть4> <хосты_сеть5>"
    exit 1
  fi

  local ip=$1
  local mask=$2
  shift 2

  for i in {1..5}; do
    echo "---- Сеть $i ----"
    calculate_subnet "$ip" "$mask" "$1"
    shift
  done
}

main "$@"
