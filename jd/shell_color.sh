#!/bin/bash  
# 先定义一些颜色:
  
red='\e[0;41m' # 红色  
RED='\e[1;31m' 
green='\e[0;32m' # 绿色  
GREEN='\e[1;32m' 
yellow='\e[5;43m' # 黄色  
YELLOW='\e[1;33m' 
blue='\e[0;34m' # 蓝色  
BLUE='\e[1;34m' 
purple='\e[0;35m' # 紫色  
PURPLE='\e[1;35m' 
cyan='\e[4;36m' # 蓝绿色  
CYAN='\e[1;36m' 
WHITE='\e[1;37m' # 白色
  
NC='\e[0m' # 没有颜色
 
echo -e "${red}显示红色0 ${NC}"
echo -e "${RED}显示红色1 ${NC}"    
echo -e "${green}显示绿色0 ${NC}"
echo -e "${GREEN}显示绿色1 ${NC}"  
echo -e "${yellow}显示黄色0 ${NC}"
echo -e "${YELLOW}显示黄色1 ${NC}"    
echo -e "${cyan}显示蓝绿色0 ${NC}"
echo -e "${CYAN}显示蓝绿色1 ${NC}"  