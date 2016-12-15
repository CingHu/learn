package main

import (
	"fmt"
	"github.com/zeromq/goczmq"
	"log"
	"time"
	"encoding/json"
)

/* Publish message */
type VrPingerCollectionMsg struct {
	Seq       string    `json:"seq"`
	Timestamp time.Time `json:"timestamp"`
}

func main() {
	port := 9769
	endpoint := fmt.Sprintf("tcp://*:%d", port)
	pubSock, err := goczmq.NewPub(endpoint)
	if err != nil {
		log.Fatal(err)
	}
	topic := "vstovr-pinger"
	ticker := time.NewTicker(10 * time.Second)
	for {
		select {
		case <-ticker.C:
			fmt.Println("Send vr pinger publish")
			now := time.Now().Local()
			msg := &VrPingerCollectionMsg{
				Seq:       now.String(),
				Timestamp: now,
			}
			bt, _ := json.Marshal(msg)
			var raw [][]byte
			raw = append(raw, []byte(topic))
			raw = append(raw, bt)
			err := pubSock.SendMessage(raw)
			if err != nil {
				fmt.Printf("[service][Pub] Send rpc publish error: %s\n", err.Error())
				continue
		}
		}
	}
}
