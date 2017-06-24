package fastping

import (
    "os/exec"
    "strings"
)

func RunCommand(name string, args ...string) (string, error) {
        cmd := exec.Command(name, args...)
        buf, _ := cmd.Output()
        result := string(buf)
        result = strings.TrimSuffix(result, "\n")
        return result, nil
}

func executeCMD(args []string) ([]byte, error) {
        return exec.Command("sudo", args...).CombinedOutput()
}

