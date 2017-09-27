package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"github.com/mdlayher/arp"
	"github.com/mdlayher/ethernet"
	"net"
	"os"
	"strconv"
	"strings"
)

func convert10(stringSlice []string) []byte {
	bytesBuffer := bytes.NewBuffer([]byte{})
	for _, v := range stringSlice {
		i, _ := strconv.ParseInt(v, 10, 64)
		binary.Write(bytesBuffer, binary.BigEndian, uint8(i))
	}
	return bytesBuffer.Bytes()
}

func convert16(stringSlice []string) []byte {
	bytesBuffer := bytes.NewBuffer([]byte{})
	for _, v := range stringSlice {
		i, _ := strconv.ParseInt(v, 16, 64)
		binary.Write(bytesBuffer, binary.BigEndian, uint8(i))
	}
	return bytesBuffer.Bytes()
}

func main() {
	if len(os.Args) < 5 {
		fmt.Println("input arp param error:")
		fmt.Println("        sha spa dha dpa")
		return
	}
	sharg := convert16(strings.Split(os.Args[1], ":"))
	sparg := convert10(strings.Split(os.Args[2], "."))
	dharg := convert16(strings.Split(os.Args[3], ":"))
	dparg := convert10(strings.Split(os.Args[4], "."))

	var sha net.HardwareAddr
	var spa net.IP
	var dha net.HardwareAddr
	var dpa net.IP

	spa = []byte{sparg[0], sparg[1], sparg[2], sparg[3]}
	sha = []byte{sharg[0], sharg[1], sharg[2], sharg[3], sharg[4], sharg[5]}
	dpa = []byte{dparg[0], dparg[1], dparg[2], dparg[3]}
	dha = []byte{dharg[0], dharg[1], dharg[2], dharg[3], dharg[4], dharg[5]}

	arp, err := arp.NewPacket(arp.OperationRequest, sha, spa, dha, dpa)
	if err != nil {
		fmt.Println("new arp packet error, %v", err)
		return
	}
	pb, err := arp.MarshalBinary()
	if err != nil {
		fmt.Println("MarshalBinary arp packet error, %v", err)
		return
	}

	f := &ethernet.Frame{
		Destination: dha,
		Source:      sha,
		EtherType:   ethernet.EtherTypeARP,
		Payload:     pb,
	}

	fb, err := f.MarshalBinary()
	if err != nil {
		fmt.Println("MarshalBinary ethernet packet error, %v", err)
		return
	}

	datastr := fmt.Sprintf("%02x", fb)
	fmt.Println(datastr)

}
