#!/usr/bin/env bash

usedAddresses=0

function toBinary() {
    local variable="$1"
    local octets=($(echo "$variable" | tr '.' ' '))
    local binary=""
    for octet in "${octets[@]}"; do
        binary+=$(printf '%08s' "$(echo "obase=2; $((octet))" | bc)")
    done
    echo "${binary// /0}"
}

function fromBinary() {
  local variable="$1"

  local decimal=""
  for ((i=0; i<32; i+=8)); do
    decimal+=$(echo "obase=10; $((2#"${variable:$i:8}"))" | bc)
    decimal+="."
  done
  echo "${decimal%.*}"
}

function specialXor() {
  local ip="$1"
  local mask="$2"
  local result=""
  local len=${#ip}

  for ((i=0; i<len; i++)); do
    bit1="${ip:$i:1}"
    bit2="${mask:$i:1}"
    if [[ "$bit1" = "1" ]]; then
      result+="$bit2"
    else
      result+="0"
    fi
  done

  echo "$result"
}

function calculateMask() {
  local machines="$1"
  local available_hosts=$((machines + 2))
  local mask_bits=$((32 - $(echo "(l($available_hosts) / l(2))" | bc -l | awk '{printf "%d\n", $1+0.9999}')))
  local maskBinary=$(printf '%*s' "$mask_bits" '' | tr ' ' '1')$(printf '%*s' "$((32 - mask_bits))" '' | tr ' ' '0')
  local maskDecimal=$(fromBinary "$maskBinary")
  echo "$maskDecimal"
}

function newUsedAddresses() {
    local machines="$1"
    local available_hosts=$((machines + 2))
    echo $((2 ** $(echo "(l($available_hosts) / l(2))" | bc -l | awk '{printf "%d\n", $1+0.9999}')))
}

function and() {
  local ip="$1"
  local mask="$2"
  local len=${#ip}
  local result=""

  for ((i=0; i<len; i++)); do
    bit1="${ip:$i:1}"
    bit2="${mask:$i:1}"
    if [[ "$bit1" = "$bit2" ]]; then
      result+="$bit1"
    else
      result+="0"
    fi
  done

  echo "$result"
}

function inversion() {
  local variable="$1"
  local len=${#variable}
  local result=""

  for ((i=0; i<len; i++)); do
    if [[ "${variable:$i:1}" = "1" ]]; then
      result+="0"
    else
      result+="1"
    fi
  done

  echo "$result"
}

function or() {
  local ip="$1"
  local mask="$2"
  local len=${#ip}
  local result=""

  for ((i=0; i<len; i++)); do
    bit1="${ip:$i:1}"
    bit2="${mask:$i:1}"
    if [[ "$bit1" = "1" || "$bit2" = "1" ]]; then
      result+="1"
    else
      result+="0"
    fi
  done

  echo "$result"
}

function addAddressesToIp() {
  local binaryIp="$1"
  local binaryAddresses=$(echo "obase=2; $usedAddresses" | bc)
  local sum=$(echo "$binaryIp + $binaryAddresses" | bc)
  
  while [ ${#sum} -lt 32 ]; do
    sum="0$sum"
  done
  echo "$sum"
}

function calculate() {
  local ip="$1"
  local mask="$2"
  local machines="$3"

  binaryIp=$(toBinary "$ip")
  binaryMask=$(toBinary "$mask")
  binaryXoredIp=$(specialXor "$binaryIp" "$binaryMask")
  decimalMaskForSubNetwork=$(calculateMask "$machines")
  binaryMaskForSubNetwork=$(toBinary "$decimalMaskForSubNetwork")
  binaryIpForSubNetwork=$(addAddressesToIp "$(and "$binaryXoredIp" "$binaryMaskForSubNetwork")")
  decimalIpForSubNetwork=$(fromBinary "$binaryIpForSubNetwork")
  invertedBinaryMaskForSubNetwork=$(inversion "$binaryMaskForSubNetwork")
  binaryBroadcastIpForSubNetwork=$(or "$binaryIpForSubNetwork" "$invertedBinaryMaskForSubNetwork")
  decimalBroadcastIpForSubNetwork=$(fromBinary "$binaryBroadcastIpForSubNetwork")
  binaryFirstHost=$(or "$binaryIpForSubNetwork" "00000000000000000000000000000001")
  decimalFirstHost=$(fromBinary "$binaryFirstHost")
  binaryLastHost=$(and "$binaryBroadcastIpForSubNetwork" "11111111111111111111111111111110")
  decimalLastHost=$(fromBinary "$binaryLastHost")

    echo "Сеть: $decimalIpForSubNetwork"
    echo "Маска: $decimalMaskForSubNetwork"
    echo "Широковещательный адрес: $decimalBroadcastIpForSubNetwork"
    if [[ "$machines" -eq 0 ]]; then
      echo "Нет доступных IP-адресов, так как все адреса заняты broadcast и самой подсетью."
    else
    echo "Диапазон хостов: $decimalFirstHost - $decimalLastHost"
    fi
    echo "Количество машин: $machines"
    echo ""

  usedAddresses=$((usedAddresses + $(newUsedAddresses "$machines")))
}

if [[ $# -ne 7 ]]; then
  echo "Использование: $0 <IP> <маска> <машины_сеть1> <машины_сеть2> <машины_сеть3> <машины_сеть4> <машины_сеть5>"
  exit 1
fi

ip=$1
mask=$2
shift 2
for i in {1..5}; do
  echo "---- Сеть $i ----"
  calculate "$ip" "$mask" "$1"
  shift
done
