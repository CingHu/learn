package main

import (
       "fmt"
       "encoding/binary"
       "jd.com/cc/jstack-controller/scripts/ovsdebug/fastping"
       "time"
       "strings"
       "os"
       "bytes"
       "strconv"
       "golang.org/x/net/icmp"
       "golang.org/x/net/ipv4"
)

func timeToBytes(t time.Time) []byte {
        nsec := t.UnixNano()
        b := make([]byte, 8)
        for i := uint8(0); i < 8; i++ {
                b[i] = byte((nsec >> ((7 - i) * 8)) & 0xff)
        }
        return b
}

func convert10(stringSlice []string) ([]byte){
    bytesBuffer := bytes.NewBuffer([]byte{})
    for _, v := range stringSlice {
           i, _ := strconv.ParseInt(v, 10, 64)
           binary.Write(bytesBuffer, binary.BigEndian, uint8(i))
    }
    return bytesBuffer.Bytes()
}

func convert16(stringSlice []string) ([]byte){
    bytesBuffer := bytes.NewBuffer([]byte{})
    for _, v := range stringSlice {
           i, _ := strconv.ParseInt(v, 16, 64)
           binary.Write(bytesBuffer, binary.BigEndian, uint8(i))
    }
    return bytesBuffer.Bytes()
}

func main() {
        if len(os.Args) < 7 {
                fmt.Println("inpute param error:")
                fmt.Println("        srcmac srcip dstmac dstip id seq")
                return
        }
        srcmac := convert16(strings.Split(os.Args[1], ":"))
        srcip := convert10(strings.Split(os.Args[2], "."))
        dstmac := convert16(strings.Split(os.Args[3], ":"))
        dstip := convert10(strings.Split(os.Args[4], "."))
        id, _ := strconv.Atoi(os.Args[5])
        seq, _ := strconv.Atoi(os.Args[6])

        t := timeToBytes(time.Now())

        bytes, _:= (&icmp.Message{
                Type: ipv4.ICMPTypeEcho, Code: 0,
                Body: &icmp.Echo{
                        ID: id, Seq: seq,
                        Data: t,
                },
        }).Marshal(nil)

        ip := fastping.IPv4New()
//        ip.NWSrc = []byte{192, 168, 1, 5}
//        ip.NWDst = []byte{192, 168, 1, 4}
        ip.NWSrc = []byte{srcip[0], srcip[1], srcip[2], srcip[3]}
        ip.NWDst = []byte{dstip[0], dstip[1], dstip[2], dstip[3]}
        ip.Protocol = 0x01
        ip.Data = bytes
        ip.Length = uint16(ip.Len())
        ip.CheckSum()
        
  //      ethSrc := [6]byte{0xfa, 0x16, 0x3e, 0xa2, 0x39, 0x1c}
   //     ethDst := [6]byte{0xfa, 0x16, 0x3e, 0x0d, 0x19, 0xa8}
        ethSrc := [6]byte{srcmac[0], srcmac[1], srcmac[2], srcmac[3], srcmac[4], srcmac[5]}
        ethDst := [6]byte{dstmac[0], dstmac[1], dstmac[2], dstmac[3], dstmac[4], dstmac[5]}
        eth := fastping.Ethernet{HWDst:ethDst, HWSrc:ethSrc, ProtoType:0x0800}
        eth.Data = ip
        
        data, _ := eth.Serialize()
        datastr := fmt.Sprintf("%02x", data)
        fmt.Println(datastr)
}
