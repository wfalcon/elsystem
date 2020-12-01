#!/bin/bash
HOST=""
#---------- Пути к базам и имя базы данных -----------------------
#base=trade
#---------- Пути к папке для архивов -----------------------------
backupdir=/media/arhive/backups
arhivedir=/media/arhive
#yandexdir=$arhivedir/yandexdisk
dailydir=$backupdir/daily
ftp=/media/ftp
weeklydir=$backupdir/weekly
monthlydir=$backupdir/monthly
backuplogfile="$arhivedir/backup_log.txt"
#------- Количество дней хранения архивов --------------
deldaily=7
delweekly=60
delmonthly=365
#-------------------------------------------------------
timenow=`date +%H-%M`
weekday=`date +%a`
monthname=`date +%h`
day=`date +%d`
month=`date +%m`
year=`date +%Y`
YYYYMMDD=`date +%F`
datetime=`date +%F-%H%M`
checkstatus=0
echo "--------------------- backup started --------------------------" | tee -a $backuplogfile
echo "$weekday $day $monthname $year $timenow" | tee -a $backuplogfile
echo "---------------------------------------------------------------" | tee -a $backuplogfile
#------------- Создаем нужные папки -----------------------------
if [[ -d $backupdir ]]; then
        echo "[exist] $datetime $backupdir already exist" | tee -a $backuplogfile
else
        mkdir $backupdir && chown -R postgres:postgres $backupdir && chmod -R 777 $backupdir & echo "[created] $datetime $backupdir created" | tee -a $backuplogfile
sleep 3
fi

cd $backupdir

end(){
exit
}

logsizecheck(){
logfilesize=`stat -c%s $backuplogfile`
if [[ -f $backuplogfile  && "$logfilesize" -gt "5000000" ]];
        then
        rm -f $backuplogfile && echo "[deleted] $datetime $backuplogfile because is great then 5 mb" | tee $backuplogfile && end
        else echo "[logsize] Logfilesize is normal = $(($logfilesize/1024)) kb" | tee -a $backuplogfile && end
fi
}

logfilecheck(){
if [ -f $backuplogfile ]; then  logsizecheck
else end
fi
}

backupfolders(){
if [[ -d $dailydir ]]; then
        echo "[exist] $datetime $dailydir already exist" | tee -a $backuplogfile
else
        mkdir $dailydir & echo "[created] $datetime $dailydir created" | tee -a $backuplogfile
fi

if [[ -d $weeklydir ]]; then
        echo "[exist] $datetime $weeklydir already exist" | tee -a $backuplogfile
else
        mkdir $weeklydir & echo "[created] $datetime $weeklydir created" | tee -a $backuplogfile
fi

if [[ -d $monthlydir ]]; then
        echo "[exist] $datetime $monthlydir already exist" | tee -a $backuplogfile
else
        mkdir $monthlydir & echo "[created] $datetime $monthlydir created" | tee -a $backuplogfile
fi

if [[ -d $dailydir/$YYYYMMDD ]]; then
        echo "[exist] $datetime $dailydir/$YYYYMMDD already exist" | tee -a $backuplogfile
else
        mkdir $dailydir/$YYYYMMDD & echo "[created] $datetime $dailydir/$YYYYMMDD created" | tee -a $backuplogfile
fi
sleep 5
}

backupfolders

#pg_dumpall > db_all.$HOST.$datetime.sql
#Необходимо делать хотя бы раз в месяц.

arhive(){
#Dump баз данных
echo "[start] $datetime backuping is started"  | tee -a $backuplogfile
for i in `psql -U postgres -l | awk '$1 !~ /(postgres|template0|template1|test)/ {print $1}' | grep ^[a-zA-Z0-9] `
do
        pg_dump -Fc -U postgres $i > $dailydir/$YYYYMMDD/$i.$datetime.backup
        gzip $dailydir/$YYYYMMDD/$i.$datetime.backup
done
}

arhive

backupscopy(){

cd $backupdir

if [ `date +%w` -eq "5" ];then
        cp $dailydir/$YYYYMMDD/*.gz $weeklydir && echo "[done] $datetime today is $weekday we must do weekly backups copy" | tee -a $backuplogfile
fi
if [ `date +%e` -eq "1" ];then
        cp $dailydir/$YYYYMMDD/*.gz $monthlydir && echo "[done] $datetime today is $day $monthname we must do monthly backups copy"  | tee -a $backuplogfile
fi
}

sendftp(){

cd $backupdir

#if  [ ! "mountpoint /media/ftp" ];then
curlftpfs ftp://login:passwd@IPaddres/BackUp/frutto /media/ftp
#fi

#if [ `date +%w` -eq "5" ];then
cp $dailydir/$YYYYMMDD/* $ftp
echo "[done] $datetime today copy in ftp" | tee -a $backuplogfile
#fi

find /media/ftp/* -type f -ctime +$deldaily | xargs rm -rfv {} \; 2> /dev/null | tee -a $backuplogfile

fusermount -u /media/ftp

}

backupscopy

deleteoldarhive()
{
#Удаление старых архивов

find $dailydir/* -type f -ctime +$deldaily | xargs rm -rfv {} \; 2> /dev/null | tee -a $backuplogfile
find $weeklydir/* -type f -ctime +$delweekly | xargs rm -rfv {} \; 2> /dev/null | tee -a $backuplogfile
find $monthlydir/* -type f -ctime +$delmonthly | xargs rm -rfv {} \; 2> /dev/null | tee -a $backuplogfile
find $backupdir/* -type f -ctime +60 | xargs rm -rfv {} \; 2> /dev/null | tee -a $backuplogfile

cd $backupdir
rmdir * 2> /dev/null | tee -a $backuplogfile
cd $dailydir
rmdir * 2> /dev/null | tee -a $backuplogfile
sendftp
}

deleteoldarhive

findbackupfiles(){
if [[ -d $dailydir/$YYYYMMDD && `ls $dailydir/$YYYYMMDD/| grep .gz | wc -l` -ne "0" ]];then
        echo "[found] $datetime backup files found" | tee -a $backuplogfile
else
        echo "[failed] $datetime - no backup files" | tee -a $arhivedir/backup_failed &&
        echo "[failed] $datetime - no backup files" >> $backuplogfile &&
        logfilecheck
fi
}

findbackupfiles


backupcheck(){
#Проверка архивов
echo "[checking] $datetime checking backup files size..." | tee -a $backuplogfile

for file in `find $dailydir/$YYYYMMDD -type f -name "*.gz"`
do
filesize=`stat -c%s $file`
        if [[ -f $file  && "$filesize" -lt "1000000" ]];
        then
                echo "[failed] $datetime $file $(($filesize/1024)) kb" | tee -a $arhivedir/backup_failed &&
                echo "[failed] $datetime $file $(($filesize/1024)) kb" >> $backuplogfile &&
                let checkstatus=1
        else
                echo "[good state] $datetime $file $(($filesize/1024)) kb" | tee -a $backuplogfile
        fi
done
}

backupcheck


checksuccess(){
if [ "$checkstatus" -gt "0" ];then
        echo "[failed] $datetime check backup files" | tee -a $arhivedir/backup_failed >> $backuplogfile &&
        logfilecheck
        else
        echo "[successful] $datetime - backup is successful" | tee -a $arhivedir/backup_successful &&
        echo "[successful] $datetime - backup is successful" >> $backuplogfile &&
        rm -f $arhivedir/backup_failed &&
        logfilecheck
fi

}
checksuccess



