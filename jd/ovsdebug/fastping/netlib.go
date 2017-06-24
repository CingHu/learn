package fastping

import (
        "bytes"
        "net"
        "encoding/binary"
)

const (
        PROTO_TYPE_IPv4 = 0x0800
        PROTO_TYPE_ARP  = 0x0806
        PROTO_TYPE_VLAN = 0x8100
        PROTO_TYPE_LLDP = 0x88CC
        PROTO_TYPE_VRDP = 0x88CD
)

const (
        IPPROTO_ICMP = 0x01
        IPPROTO_TCP  = 0x06
        IPPROTO_UDP  = 0x11
        IPPROTO_GRE  = 0x2F
)

type Msg interface {
        Serialize() (data []byte, err error)
        UnSerialize(data []byte) (err error)
        Len() int
}

type Ethernet struct {
        HWDst     [6]byte
        HWSrc     [6]byte
        ProtoType uint16
        Data      Msg
}

func (e *Ethernet) Len() (l int) {
        l = 14
        return
}

func (e *Ethernet) Serialize() (data []byte, err error) {
        buf := bytes.NewBuffer(make([]byte, 0))
        binary.Write(buf, binary.BigEndian, e.HWDst)
        binary.Write(buf, binary.BigEndian, e.HWSrc)
        binary.Write(buf, binary.BigEndian, e.ProtoType)

        if e.Data != nil {
                var datalen uint16
                if e.ProtoType == PROTO_TYPE_IPv4 {
                        datalen = uint16(e.Len()) + e.Data.(*IPv4).Length
                }
                bs := make([]byte, datalen)
                bs, err = e.Data.Serialize()
                if err != nil {
                        return
                }
                binary.Write(buf, binary.BigEndian, bs)
        }

        data = buf.Bytes()
        return
}

func (e *Ethernet) UnSerialize(data []byte) (err error) {
        return
}

type Buffer struct {
        bytes.Buffer
}

func (b *Buffer) Len() (l int) {
        return b.Buffer.Len()
}

func (b *Buffer) Serialize() (data []byte, err error) {
        return b.Buffer.Bytes(), nil
}

func (b *Buffer) UnSerialize(data []byte) error {
        b.Buffer.Reset()
        _, err := b.Buffer.Write(data)
        return err
}

type IPv4 struct {
        Version        uint8 //4-bits
        IHL            uint8 //4-bits
        DSCP           uint8 //6-bits
        ECN            uint8 //2-bits
        Length         uint16
        Id             uint16
        Flags          uint16 //3-bits
        FragmentOffset uint16 //13-bits
        TTL            uint8
        Protocol       uint8
        Checksum       uint16
        NWSrc          net.IP
        NWDst          net.IP
        Options        Buffer
        Data           []byte
}

func IPv4New() *IPv4 {
        ip := new(IPv4)
        ip.Version = 4
        ip.TTL = 64
        ip.NWSrc = make([]byte, 4)
        ip.NWDst = make([]byte, 4)
        ip.Options = *new(Buffer)
        ip.Data = make([]byte, 0)
        return ip
}

func (i *IPv4) Len() (l int) {
        i.IHL = 5
        if i.Data != nil {
                return int(i.IHL)*4 + len(i.Data)
        }
        return int(i.IHL * 4)
}

func (i *IPv4) CheckSum() {
        var (
                sum    uint32
                length int = 20
                index  int
        )
        data, _ := i.Serialize()
        for length > 1 {
                sum += uint32(data[index])<<8 + uint32(data[index+1])
                index += 2
                length -= 2
        }
        if length > 0 {
                sum += uint32(data[index])
        }
        sum = (sum >> 16) + (sum & 0xffff)
        sum += (sum >> 16)

        i.Checksum = uint16(^sum)
}

func (i *IPv4) Serialize() (data []byte, err error) {
        data = make([]byte, int(i.Len()))
        b := make([]byte, 0)
        n := 0

        var ihl uint8 = (i.Version << 4) + i.IHL
        data[n] = ihl
        n += 1
        var ecn uint8 = (i.DSCP << 2) + i.ECN
        data[n] = ecn
        n += 1
        binary.BigEndian.PutUint16(data[n:], i.Length)
        n += 2
        binary.BigEndian.PutUint16(data[n:], i.Id)
        n += 2
        var flg uint16 = (i.Flags << 13) + i.FragmentOffset
        binary.BigEndian.PutUint16(data[n:], flg)
        n += 2
        data[n] = i.TTL
        n += 1
        data[n] = i.Protocol
        n += 1
        binary.BigEndian.PutUint16(data[n:], i.Checksum)
        n += 2

        copy(data[n:], i.NWSrc.To4())
        n += 4 // Underlying rep can be 16 bytes.
        copy(data[n:], i.NWDst.To4())
        n += 4 // Underlying rep can be 16 bytes.

        b, err = i.Options.Serialize()
        copy(data[n:], b)
        n += len(b)

        if i.Data != nil {
                copy(data[n:], i.Data)
                n += len(i.Data)
        }
        return
}

func (i *IPv4) UnSerialize(data []byte) (err error) {
        return
}

type ICMP struct {
        Type     uint8
        Code     uint8
        Checksum uint16
        Data     []byte
}

func ICMPNew() (i *ICMP) {
        i = new(ICMP)
        i.Data = make([]byte, 0)
        return
}

func (i *ICMP) Len() (l int) {
        l = 4
        return
}

func (i *ICMP) Serialize() (data []byte, err error) {
        buf := bytes.NewBuffer(make([]byte, 0))
        binary.Write(buf, binary.BigEndian, i.Type)
        binary.Write(buf, binary.BigEndian, i.Code)
        binary.Write(buf, binary.BigEndian, i.Checksum)
        for _, b := range i.Data {
                binary.Write(buf, binary.BigEndian, b)
        }
        return
}


func (i *ICMP) UnSerialize(data []byte) (err error) {
        return
}
