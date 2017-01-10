func SplitRange(rangestart uint16, rangeend uint16, fullmask uint16) (portmasks []*portmask) {
        var pm *portmask
        var bitflag uint16 = 1
        if rangestart == 0 {
                rangestart = 1
        }
        lasttempstart := rangestart
        lasttempend := rangestart

        for {
                if ((lasttempstart & bitflag) == 0) && ((lasttempend | bitflag)) <= rangeend {
                        lasttempend |= bitflag
                        bitflag = bitflag << 1
                } else {
                        mask := fullmask - (bitflag - 1)
                        pm = new(portmask)
                        pm.start = lasttempstart
                        pm.mask = mask
                        portmasks = append(portmasks, pm)
                        if lasttempend >= rangeend {
                                break
                        }
                        bitflag = 1
                        lasttempstart = lasttempend + 1
                        lasttempend = lasttempstart
                }
        }

        return portmasks
}
