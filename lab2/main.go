package main

import (
	"fmt"
	"math"
	"os"
	"sort"
	"strconv"
	"strings"
)

var additionalIps = map[int]int{
	1: 1,
	2: 2,
	3: 3,
	4: 1,
	5: 1,
}

var usedAddresses int = 0

type Pair struct {
	machines int
	net      int
}

func toBinary(ip string) string {
	octets := strings.Split(ip, ".")
	binary := ""
	for _, octet := range octets {
		num, _ := strconv.Atoi(octet)
		binary += fmt.Sprintf("%08b", num)
	}

	return binary
}

func fromBinary(binary string) string {
	parts := make([]string, 4)
	for i := 0; i < 32; i += 8 {
		part, _ := strconv.ParseInt(binary[i:i+8], 2, 64)
		parts[i/8] = strconv.Itoa(int(part))
	}
	return strings.Join(parts, ".")
}

func specialXor(ip string, mask string) string {
	result := ""
	for i := 0; i < len(ip); i++ {
		if ip[i] == '1' {
			result += string(mask[i])
		} else {
			result += "0"
		}
	}
	return result
}

func calculateMask(machines int, net int) string {
	availableHosts := machines + 2 + additionalIps[net]
	maskBits := 32 - int(math.Ceil(math.Log2(float64(availableHosts))))
	maskBinary := strings.Repeat("1", maskBits) + strings.Repeat("0", 32-maskBits)
	return fromBinary(maskBinary)
}

func newUsedAddresses(machines int, net int) int {
	availableHosts := machines + 2 + additionalIps[net]
	return int(math.Pow(2, math.Ceil(math.Log2(float64(availableHosts)))))
}

func and(ip string, mask string) string {
	result := ""
	for i := 0; i < len(ip); i++ {
		if ip[i] == mask[i] {
			result += string(ip[i])
		} else {
			result += "0"
		}
	}
	return result
}

func calculateBroadcast(ip string, addresses int) string {
	octets := strings.Split(ip, ".")
	octet1, _ := strconv.Atoi(octets[0])
	octet2, _ := strconv.Atoi(octets[1])
	octet3, _ := strconv.Atoi(octets[2])
	octet4, _ := strconv.Atoi(octets[3])

	newOctet4 := octet4 + addresses - 1

	for newOctet4 > 255 {
		newOctet4 -= 256
		octet3++
		if octet3 > 255 {
			octet3 -= 256
			octet2++
			if octet2 > 255 {
				octet2 -= 256
				octet1++
				if octet1 > 255 {
					fmt.Println("IP address overflow")
					return ""
				}
			}
		}
	}

	newIp := fmt.Sprintf("%d.%d.%d.%d", octet1, octet2, octet3, newOctet4)
	return newIp
}

func addAddressesToIp(binaryIp string) string {
	ip := fromBinary(binaryIp)
	octets := strings.Split(ip, ".")
	octet1, _ := strconv.Atoi(octets[0])
	octet2, _ := strconv.Atoi(octets[1])
	octet3, _ := strconv.Atoi(octets[2])
	octet4, _ := strconv.Atoi(octets[3])

	newOctet4 := octet4 + usedAddresses

	for newOctet4 > 255 {
		newOctet4 -= 256
		octet3++
		if octet3 > 255 {
			octet3 -= 256
			octet2++
			if octet2 > 255 {
				octet2 -= 256
				octet1++
				if octet1 > 255 {
					fmt.Println("IP address overflow")
					return ""
				}
			}
		}
	}

	newIp := fmt.Sprintf("%d.%d.%d.%d", octet1, octet2, octet3, newOctet4)
	return toBinary(newIp)
}

func addOneToIp(ip string) string {
	octets := strings.Split(ip, ".")
	octet1, _ := strconv.Atoi(octets[0])
	octet2, _ := strconv.Atoi(octets[1])
	octet3, _ := strconv.Atoi(octets[2])
	octet4, _ := strconv.Atoi(octets[3])

	newOctet4 := octet4 + 1
	if newOctet4 > 255 {
		newOctet4 = 0
		octet3++
		if octet3 > 255 {
			octet3 = 0
			octet2++
			if octet2 > 255 {
				octet2 = 0
				octet1++
				if octet1 > 255 {
					fmt.Println("IP address overflow")
					return ""
				}
			}
		}
	}

	return fmt.Sprintf("%d.%d.%d.%d", octet1, octet2, octet3, newOctet4)
}

func subOneFromIp(ip string) string {
	octets := strings.Split(ip, ".")
	octet1, _ := strconv.Atoi(octets[0])
	octet2, _ := strconv.Atoi(octets[1])
	octet3, _ := strconv.Atoi(octets[2])
	octet4, _ := strconv.Atoi(octets[3])

	newOctet4 := octet4 - 1
	if newOctet4 < 0 {
		newOctet4 = 255
		octet3--
		if octet3 < 0 {
			octet3 = 255
			octet2--
			if octet2 < 0 {
				octet2 = 255
				octet1--
				if octet1 < 0 {
					fmt.Println("IP address underflow")
					return ""
				}
			}
		}
	}

	return fmt.Sprintf("%d.%d.%d.%d", octet1, octet2, octet3, newOctet4)
}

func calculate(ip string, mask string, machines int, net int) {
	binaryIp := toBinary(ip)
	binaryMask := toBinary(mask)
	binaryXoredIp := specialXor(binaryIp, binaryMask)
	decimalMaskForSubNetwork := calculateMask(machines, net)
	decimalIpForSubNetwork := fromBinary(addAddressesToIp(binaryXoredIp))
	decimalBroadcastIpForSubNetwork := calculateBroadcast(decimalIpForSubNetwork, newUsedAddresses(machines, net))
	decimalFirstHost := addOneToIp(decimalIpForSubNetwork)
	decimalLastHost := subOneFromIp(decimalBroadcastIpForSubNetwork)

	fmt.Printf("Сеть: %s\n", decimalIpForSubNetwork)
	fmt.Printf("Маска: %s\n", decimalMaskForSubNetwork)
	fmt.Printf("Широковещательный адрес: %s\n", decimalBroadcastIpForSubNetwork)
	if machines == 0 {
		fmt.Println("Нет доступных IP-адресов, так как все адреса заняты broadcast и самой подсетью.")
	} else {
		fmt.Printf("Диапазон хостов: %s - %s\n", decimalFirstHost, decimalLastHost)
	}
	fmt.Printf("Количество машин: %d\n\n", machines)

	usedAddresses += newUsedAddresses(machines, net)
}

func main() {
	if len(os.Args) != 8 {
		fmt.Println("Использование: <IP> <маска> <машины_сеть1> <машины_сеть2> <машины_сеть3> <машины_сеть4> <машины_сеть5>")
		return
	}

	ip := os.Args[1]
	mask := os.Args[2]
	machines := os.Args[3:]
	arr := make([]Pair, len(machines))
	for i := range machines {
		machinesInt, _ := strconv.Atoi(machines[i])
		arr[i] = Pair{machines: machinesInt, net: i + 1}
	}

	sort.Slice(arr, func(i, j int) bool { return arr[i].machines > arr[j].machines })

	for i := range 5 {
		fmt.Printf("---- Сеть %d ----\n", arr[i].net)
		calculate(ip, mask, arr[i].machines, arr[i].net)
	}
}
