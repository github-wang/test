#!/bin/bash

BUILD_DATE=$(date +%Y%m%d)
LOG_FILE=/home/builder/liuhaitao/tmp/armani/$BUILD_DATE.txt

mkdir -p /home/builder/liuhaitao/tmp/armani
echo "Build date is $BUILD_DATE"
cd /home/builder/liuhaitao/armani-jb
mkdir -p build_log
repo sync -d -c -j4 2>&1 | tee build_log/sync.log

declare last_commit new_commit

# 1. check if kernel source updated
cd kernel
git checkout bsprelease/armani-jb
last_commit=`git log armani-jb-src | head -1 | awk -F\  '{print $2}'`
echo $last_commit
#git branch -D armani-jb-real

git fetch bsprelease
new_commit=`git log remotes/bsprelease/armani-jb | head -1 | awk -F\  '{print $2}'`
echo $new_commit
#git log ${last_commit}..${new_commit} > $LOG_FILE
pwd
git branch -D armani-jb-src
git checkout -b armani-jb-src bsprelease/armani-jb
cd ..

if [ ! -d kernel.binary ]
then
	mkdir -p kernel.binary
	cd kernel.binary
	git init .
	git remote add mione ssh://gitdaemon@git.xiaomi.com/mionew0/kernel/msm8226
	cd ..
fi
cd kernel.binary
git fetch mione
git checkout mione/armani-jb
git branch -D armani-jb-binary
git checkout -b armani-jb-binary --track mione/armani-jb
cd ..

#repo sync -j8

# 2. if updated, build binary-kernel; otherwise no need to build 
if [[ $new_commit != $last_commit ]]
then
	./binary_kernel_full-jb-auto.sh $BUILD_DATE
	cd kernel
	echo "kernel/msm" >$LOG_FILE
	echo "========================================================" >>$LOG_FILE
	git log $last_commit..$new_commit >> $LOG_FILE
	echo >>$LOG_FILE

	# 3. push binary-kernel to gerrit git.xiaomi.com:8660 armani-jb branch
	cd ../kernel.binary
	git rm -r eng user
	cp -rf  ../binary/eng ./
	cp -rf  ../binary/user ./
	git add eng user
	git commit -m "binary: update armani-jb binary kernel $BUILD_DATE


`cat $LOG_FILE`" -s
	echo "*************************************************"

	git push ssh://liuhaitao@git.xiaomi.com:29419/kernel/msm8226 armani-jb-binary:refs/for/armani-jb

	# 4. mail to notify binary-kernel build and push done
	mail -s "Build binary-kernel $BUILD_DATE for armani-jb done" liuhaitao@xiaomi.com <$LOG_FILE
else
	cd kernel
	echo "kernel/msm" >$LOG_FILE
	echo "========================================================" >>$LOG_FILE
	git log -2 remotes/bsprelease/armani-jb >>$LOG_FILE
	echo >>$LOG_FILE
	cd ..

	cd kernel.binary
	echo "kernel/msm8226" >>$LOG_FILE
	echo "========================================================" >>$LOG_FILE
	git log -2 armani-jb-binary >>$LOG_FILE
	echo >>$LOG_FILE
	mail -s "No need to build binary-kernel $BUILD_DATE for armani-jb" liuhaitao@xiaomi.com yu.zhang@xiaomi.com <$LOG_FILE
fi
