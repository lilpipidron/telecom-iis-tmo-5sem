#!/usr/bin/env bash

usedAddresses=0

toBinary() {
    local ip=$1
    local binary=""
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        printf -v binaryPart "%08d" "$(bc <<< "obase=2; $octet")"
        binary+="$binaryPart"
    done
    echo "$binary"
}

fromBinary() {
    local binary=$1
    local ip=""
    for (( i=0; i<32; i+=8 )); do
        part=$(echo "${binary:i:8}" | awk '{ print strtonum("0b"$0) }')
        ip+="$part."
    done
    echo "${ip%?}"  # Удаляем последнюю точку
}

specialXor() {
    local ip=$1
    local mask=$2
    local result=""
    for (( i=0; i<${#ip}; i++ )); do
        if [[ "${ip:i:1}" == "1" ]]; then
            result+="${mask:i:1}"
        else
            result+="0"
        fi
    done
    echo "$result"
}

calculateMask() {
    local machines=$1
    local availableHosts=$((machines + 2))
    local maskBits=$((32 - $(echo "l($availableHosts)/l(2)" | bc -l | awk '{print int($1+0.999)}')))
    local maskBinary=$(printf '1%.0s' $(seq 1 $maskBits) | tr -d '\n')$(printf '0%.0s' $(seq 1 $((32 - maskBits))) | tr -d '\n')
    fromBinary "$maskBinary"
}

newUsedAddresses() {
    local machines=$1
    local availableHosts=$((machines + 2))
    echo $((2 ** $(echo "l($availableHosts)/l(2)" | bc -l | awk '{print int($1+0.999)}')))
}

and() {
    local ip=$1
    local mask=$2
    local result=""
    for (( i=0; i<${#ip}; i++ )); do
        if [[ "${ip:i:1}" == "${mask:i:1}" ]]; then
            result+="${ip:i:1}"
        else
            result+="0"
        fi
    done
    echo "$result"
}

calculateBroadcast() {
    local ip=$1
    local addresses=$2
    IFS='.' read -r octet1 octet2 octet3 octet4 <<< "$ip"
    local newOctet4=$((octet4 + addresses - 1))

    while (( newOctet4 > 255 )); do
        newOctet4=$((newOctet4 - 256))
        ((octet3++))
        if (( octet3 > 255 )); then
            octet3=0
            ((octet2++))
            if (( octet2 > 255 )); then
                octet2=0
                ((octet1++))
            fi
        fi
    done

    echo "$octet1.$octet2.$octet3.$newOctet4"
}

addAddressesToIp() {
    local binaryIp=$1
    local ip=$(fromBinary "$binaryIp")
    IFS='.' read -r octet1 octet2 octet3 octet4 <<< "$ip"
    local newOctet4=$((octet4 + usedAddresses))

    while (( newOctet4 > 255 )); do
        newOctet4=$((newOctet4 - 256))
        ((octet3++))
        if (( octet3 > 255 )); then
            octet3=0
            ((octet2++))
            if (( octet2 > 255 )); then
                octet2=0
                ((octet1++))
            fi
        fi
    done

    echo "$octet1.$octet2.$octet3.$newOctet4"
}

addOneToIp() {
    local ip=$1
    IFS='.' read -r octet1 octet2 octet3 octet4 <<< "$ip"
    local newOctet4=$((octet4 + 1))
    if (( newOctet4 > 255 )); then
        newOctet4=0
        ((octet3++))
        if (( octet3 > 255 )); then
            octet3=0
            ((octet2++))
            if (( octet2 > 255 )); then
                octet2=0
                ((octet1++))
            fi
        fi
    fi
    echo "$octet1.$octet2.$octet3.$newOctet4"
}

subOneFromIp() {
    local ip=$1
    IFS='.' read -r octet1 octet2 octet3 octet4 <<< "$ip"
    local newOctet4=$((octet4 - 1))
    if (( newOctet4 < 0 )); then
        newOctet4=255
        ((octet3--))
        if (( octet3 < 0 )); then
            octet3=255
            ((octet2--))
            if (( octet2 < 0 )); then
                octet2=255
                ((octet1--))
                if (( octet1 < 0 )); then
                    echo "Ошибка: переполнение адреса IP"
                    return
                fi
            fi
        fi
    fi
    echo "$octet1.$octet2.$octet3.$newOctet4"
}

calculate() {
    local ip=$1
    local mask=$2
    local machines=$3
    local binaryIp=$(toBinary "$ip")
    local binaryMask=$(toBinary "$mask")
    local binaryXoredIp=$(specialXor "$binaryIp" "$binaryMask")
    local decimalMaskForSubNetwork=$(calculateMask "$machines")
    local decimalIpForSubNetwork=$(fromBinary "$(addAddressesToIp "$binaryXoredIp")")
    local decimalBroadcastIpForSubNetwork=$(calculateBroadcast "$decimalIpForSubNetwork" "$(newUsedAddresses "$machines")")
    local decimalFirstHost=$(addOneToIp "$decimalIpForSubNetwork")
    local decimalLastHost=$(subOneFromIp "$decimalBroadcastIpForSubNetwork")

    echo "Сеть: $decimalIpForSubNetwork"
    echo "Маска: $decimalMaskForSubNetwork"
    echo "Широковещательный адрес: $decimalBroadcastIpForSubNetwork"
    if (( machines == 0 )); then
        echo "Нет доступных IP-адресов, так как все адреса заняты broadcast и самой подсетью."
    else
        echo "Диапазон хостов: $decimalFirstHost - $decimalLastHost"
    fi
    echo "Количество машин: $machines"
    echo ""

    usedAddresses=$((usedAddresses + $(newUsedAddresses "$machines")))
}

if [[ $# -ne 7 ]]; then
  echo "Использование: <IP> <маска> <машины_сеть1> <машины_сеть2> <машины_сеть3> <машины_сеть4> <машины_сеть5>"
  return
fi

ip=$1
mask=$2
shift 2

for (( i=0; i<5; i++ )); do
  echo "---- Сеть $((i+1)) ----"
  calculate "$ip" "$mask" "$1"
  shift
done

