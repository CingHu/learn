
#git remote add 命令把它加为当前项目的远程分支之一。我们把它命名为 teamone，以便代替原始的 Git 地址
git fetch teamone
#现在你可以用 git fetch teamone 来获取小组服务器上你还没有的数据了。由于当前该服务器上的内容是你 origin 服务器上的子集，Git 不会下载任何数据，而只是简单地创建一个名为teamone/master 的分支，指向 teamone 服务器上 master分支所在的提交对象31b8e,你在本地有了一个指向 teamone 服务器上 master 分支的索引



git push (远程仓库名) (分支名)         //推送本地分支, 例如：git push origin serverfix

git push origin serverfix:serferfix   //上传我本地的 serverfix 分支到远程仓库中去，仍旧称它为 serverfix 分支

git push origin serverfix:awesomebranch  //若想把远程分支叫作awesomebranch，可以用 git push origin serverfix:awesomebranch 来推送数据

git fetch origin                         //将得到一个新的远程分支 origin/serverfix

git merge origin/serverfix               //把内容合并到当前分支，这个分支是一个远程分支

git checkout -b serverfix origin/serverfix --track  //创建一个自己的serverfix开发

git checkout --track origin/serverfix    //跟踪远程分支
git branch --set-upstream servicevm origin/servicevm

git checkout -b sf origin/serverfix      //现在你的本地分支 sf 会自动向 origin/serverfix 推送和抓取数据了

git push origin :serverfix               //删除远程分支


git checkout experiment ===>  git rebase master 

git rebase --onto master server client ===> git checkout master ==> git merge client ==>  git rebase master server ==> git checkout master ==> git merge server ==> git branch -d client ==> git branch -d server  //我们就可以把基于 server 分支而非 master 分支的改变（即 C8 和 C9），跳过 server 直接放到master 分支中重演一遍，但这需要用 git rebase 的 –onto 选项指定新的基底分支master

git diff --check                      //提交之前，检查空白字符

git log --no-merges                  //还没有merge的分支


git fetch origin  ===> git merge origin/master ==> git push origin master       //提交之前需要fetch仓库里最新的代码,同时将代码合并到最新,然后在push代码


git log --no-merges origin/master ^issue54 //查看issue54本地分支与当前最新的仓库代码的区别

git log --abbrev-commit --pretty=oneline


git fetch origin ==> git log --no-merges origin/master ^issue54 ==> git checkout master ==> git merge issue54 ==> git merge origin/master ==> git push origin master   //完整的更新代码的流程

//user1与user2一起开发feature这个特性
git checkout -b featureA ==> git push origin featureA  //user1开发特性A完成
git fetch origin ==> git checkout -b featureB origin/master ==> git commit -am 'add ls-files' ==> git fetch origin ==> git merge origin/featureBee ==> git push origin featureB:featureBee ==> git log origin/featureA ^featureA ==> git checkout featureA ==> git merge origin/featureA ==> git commit -am 'small tweak' ==> git push origin featureA   //user2开发过程中user1已经更新了代码并提交到仓库里了，所以user2在提交之前需要再次获取到新的代码并合并到最新，然后在将代码推送的featureB分支


git apply --check 0001-seeing-if-this-helps-the-gem.patch  //查看补丁是否能够干净顺利地应用到当前分支中
git apply /tmp/patch-ruby-client.patc   //应用补丁

git shortlog --no-merges master --not v1.0.1   //统计给定范围内的所有提交;假如你上一次发布的版本是v1.0.1，下面的命令将给出自从上次发布之后的所有提交的简介

git reflog 734713b  //引用日志

git show HEAD@{5}   //如果你想查看仓库中 HEAD 在五次前的值，你可以使用引用日志的输出中的@{n}

git show master@{yesterday}  //查看一定时间前分支指向哪里

git show HEAD@{2.months.ago}  //2个月之前的提交

git show HEAD^  //查看HEAD 的父提交
git show HEAD^2  //查看HEAD第二的父提交
git show HEAD~3  //不太清楚，看着用



git config --global core.editor vim

git config --global core.pager less //core.pager指定 Git 运行诸如log、diff等所使用的分页器

git config --global core.excludesfile //提交时，忽略的文件定义


git config --global help.autocorrect //命令自动修正


git config --global color.ui true     //git着色, 可选择false, always,与着色有关的选项color.branch color.diff color.interactive color.status

git config --global core.autocrlf true //提交时自动地把行结束符CRLF转换成LF，而在签出代码时把LF转换成CRLF
git config --global core.autocrlf input  //Linux或Mac系统使用LF作为行结束符，因此你不想 Git 在签出文件时进行自动的转换；当一个以CRLF为行结束符的文件不小心被引入时你肯定想进行修正，把core.autocrlf设置成input来告诉 Git 在提交时把CRLF转换成LF，签出时不转换
git config --global core.autocrlf false //如果你是Windows程序员，且正在开发仅运行在Windows上的项目，可以设置false取消此功能，把回车符记录在库中

git config --global core.whitespace //trailing-space会查找每行结尾的空格,space-before-tab会查找每行开头的制表符前的空格,indent-with-non-tab会查找8个以上空格（非制表符）开头的行,cr-at-eol让 Git 知道行尾回车符是合法的
git config --global core.whitespace \ trailing-space,space-before-tab,indent-with-non-tab




No.1 
git fetch liming==>git merage liming/master 

No.2 
git checkout liming/card 

No.3 
git remote add liming /home/liming/repo ==>git remote -v

No.5 
git branch --remote

No.6
git pull origin <branch_name> 
git pull --rebase origin master

No.7 
git log --grep='_x_nova' --pretty=oneline
git log -g master


No.8 git rebase -i HEAD~3 ==> edit ==>git commit-amend ==>git rebase --continue

No.9 
git reset --hard HEAD
git clean -f -d
git pull
 
No.10
git log --decorate --oneline --graph

No.11
git log -p  #显示详细信息


No.12
git checkout HEAD^  file
git checkout 1.1.0

No.13 
git pull --rebase origin master


No.14
是查看目前的每一行是哪个提交最后改动的
git blame filename

No.15 强制同步
git reset --hard origin/master

No.16 修改commit中的user, mail
git commit --amend --author=huxining

No.17 搜索文件修改历史
git log --pretty=oneline file

No.18 没有commit-msg
LANG=C LANGUAGE=C git review -s

No.19 比较暂存区与仓库的差别
git diff --cached
git diff --staged

No.20 移除跟踪但是不删除
git rm --cached readme.txt

No.21 删除文件
git rm readme.txt
git rm -f readme.txt

No.22 查看日志
git log -p -2
git log --stat
git log --pretty=online --graph
git log --format="%h %s" --graph

git log --abbrev-commit --pretty=oneline -n

No.23 恢复到仓库版本
git checkout -- benchmarks.rb

No.24 远端仓库信息
git remote show origin

No.25 删除远端分支pa
git remote rm pa

No.26 push tag
git push origin v1.5

No.27 push所有tag
git push origin --tags

No.28 
git branch --merged
git branch -v
git branch --no-merged

No.29 跟踪远程分支
git checkout --track origin/serverfix

No.30 删除远程分支
git push origin :serverfix

No.31 rebase
git checkout experiment
git rebase master
git rebase origin/master

No.32 把基于 server 分支而非 master 分支的改变（即 C8 和 C9），跳过 server 直接放到master 分支中重演一遍
git rebase --onto master server client

No.33 先取出特性分支server，然后在主分支 master ==>  git rebase [主分支] [特性分支]
git rebase master server
git checkout master
git merge server

No.34 显示多余的空白字符
git diff --check

No.35 merge最新的代码到本地
git merge origin/master

No.36 查看当前分支与master的区别
git log --no-merges origin/master ^issue54
git log  origin/master ^issue54

No.37  reflog
git show HEAD@{5}
git show HEAD~3
git show HEAD^^^
git log origin/master..HEAD
git log refB --not refA
git log ^refA refB
git log refA..refB

No.38 修改历史提交
git rebase -i HEAD~3
git commit --amend
git rebase --continue

No.40 配置git
commit.template
core.pager
help.autocorrect
core.excludesfile
color.ui(true, always, false)
color.branch color.diff color.interactive color.status
merge.tool
core.autocrlf(true, input, false)
trailing-space, space-before-tab, indent-with-non-tab, cr-at-eol





