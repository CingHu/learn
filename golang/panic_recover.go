	defer func() {
		delete(e.chanMap, ip)
		log.Debugf("delete e.chanMap %+v", ip)
		if e := recover(); e != nil {
			log.Errorf("[SendPktOut] Panic %s: %s", e, debug.Stack())
		}
	}()