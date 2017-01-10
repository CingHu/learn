	defer func() {
		close(e.chanMap[ip])
		delete(e.chanMap, ip)
		log.Debugf("delete e.chanMap %+v", ip)
		if e := recover(); e != nil {
			log.Errorf("[SendPktOut] Panic %s: %s", e, debug.Stack())
		}
	}()