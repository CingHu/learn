#!/bin/bash

tools=apt-get\ install\ -y


#test loss packet
$tools mtr

#test nic rate
$tools iftop

#hping3, much process
$tools hping3

#http send tools 
# http POST :6002/v1/testruns testset_id=1 test_item_name=test_list_loadbalancers
$toos httpid

#zshell
$toos zsh && git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh && cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc && chsh -s /bin/zsh && sudo usermod -s /bin/zsh stack
