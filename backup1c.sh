#!/bin/bash
HOST="serv"
#---------- Пути к базам и имя базы данных -----------------------
base1=trade1
base2=buh
base3=buh_fix
base4=zup
#---------- Пути к папке для архивов -----------------------------
backupdir=/media/arhive/backups
arhivedir=/media/arhive
yandexdir=$arhivedir/yandexdisk
dailydir=$backupdir/daily
weeklydir=$backupdir/weekly
monthlydir=$backupdir/monthly
backuplogfile="$arhivedir/backup_log.txt"
#------- Количество дней хранения архивов --------------
deldaily=60
delweekly=90
delmonthly=365
#delyandexdisk=15
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
cd $backupdir

end(){
exit
}

logsizecheck(){
logfilesize=`stat -c%s $backuplogfile`
if [[ -f $backuplogfile  && "$logfilesize" -gt "5000000" ]];
        then
        rm -f $backuplogfile && echo "[deleted] `date +%F-%H%M` $backuplogfile because is great then 5 mb" | tee $backuplogfile && end
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
        echo "[exist] `date +%F-%H%M` $dailydir already exist" | tee -a $backuplogfile
else
        mkdir $dailydir & echo "[created] `date +%F-%H%M` $dailydir created" | tee -a $backuplogfile
fi

if [[ -d $weeklydir ]]; then
        echo "[exist] `date +%F-%H%M` $weeklydir already exist" | tee -a $backuplogfile
else
        mkdir $weeklydir & echo "[created] `date +%F-%H%M` $weeklydir created" | tee -a $backuplogfile
fi

if [[ -d $monthlydir ]]; then
        echo "[exist] `date +%F-%H%M` $monthlydir already exist" | tee -a $backuplogfile
else
        mkdir $monthlydir & echo "[created] `date +%F-%H%M` $monthlydir created" | tee -a $backuplogfile
fi

if [[ -d $dailydir/$YYYYMMDD ]]; then
        echo "[exist] `date +%F-%H%M` $dailydir/$YYYYMMDD already exist" | tee -a $backuplogfile
else
        mkdir $dailydir/$YYYYMMDD & echo "[created] `date +%F-%H%M` $dailydir/$YYYYMMDD created" | tee -a $backuplogfile
fi
sleep 10
}
backupfolders

#pg_dumpall > db_all.$HOST.$datetime.sql
#Необходимо делать хотя бы раз в месяц.

arhive(){
#Dump баз данных
echo "[start] `date +%F-%H%M` backuping is started"  | tee -a $backuplogfile
for i in `psql -U postgres -l | awk '$1 !~ /(postgres|template0|s1|template1|test|buh_fix|zup_31_bad|trade_120319|trade_compres|trade_260319)/ {print $1}' | grep ^[a-z] `
do
        pg_dump -Fc -U postgres $i > $dailydir/$YYYYMMDD/$i.$datetime.backup
        gzip $dailydir/$YYYYMMDD/$i.$datetime.backup
done
# pg_dump -Fc -U postgres "$base1" > $dailydir/$YYYYMMDD/$base1.$datetime.backup
# pg_dump -Fc -U postgres "$base2" > $dailydir/$YYYYMMDD/$base2.$datetime.backup
# gzip $dailydir/$YYYYMMDD/$base1.$datetime.backup
# gzip $dailydir/$YYYYMMDD/$base2.$datetime.backup
}
arhive

backupscopy(){
#В облако yandexdisk [scwarek.new@yandex.ru   passwd:SDKarhive2000]
#cp -R $dailydir/$YYYYMMDD /media/arhive/yandexdisk/ && echo "[copyed] `date +%F-%H%M` backup files copyed into yandexdisk"  | tee -a $backuplogfile

if [ `date +%w` -eq "5" ];then
        cp $dailydir/$YYYYMMDD/*.gz $weeklydir && echo "[done] `date +%F-%H%M` today is $weekday we must do weekly backups copy" | tee -a $backuplogfile
fi
if [ `date +%e` -eq "1" ];then
        cp $dailydir/$YYYYMMDD/*.gz $monthlydir && echo "[done] `date +%F-%H%M` today is $day $monthname we must do monthly backups copy"  | tee -a $backuplogfile
fi
}
backupscopy

deleteoldarhive()
{
#Удаление старых архивов

find $dailydir/* -type f -ctime +$deldaily | xargs rm -rfv {} \; 2> /dev/null | tee -a $backuplogfile
find $weeklydir/* -type f -ctime +$delweekly | xargs rm -rfv {} \; 2> /dev/null | tee -a $backuplogfile
find $monthlydir/* -type f -ctime +$delmonthly | xargs rm -rfv {} \; 2> /dev/null | tee -a $backuplogfile
#find $yandexdir/* -type f -ctime +$delyandexdisk | xargs rm -rfv {} \; 2> /dev/null | tee -a $backuplogfile
find $backupdir/* -type f -ctime +60 | xargs rm -rfv {} \; 2> /dev/null | tee -a $backuplogfile
cd $backupdir
rmdir * 2> /dev/null | tee -a $backuplogfile
cd $dailydir
rmdir * 2> /dev/null | tee -a $backuplogfile
#cd $yandexdir
#rmdir * 2> /dev/null | tee -a $backuplogfile
}
deleteoldarhive

findbackupfiles(){
if [[ -d $dailydir/$YYYYMMDD && `ls $dailydir/$YYYYMMDD/| grep .gz | wc -l` -ne "0" ]];then
        echo "[found] `date +%F-%H%M` backup files found" | tee -a $backuplogfile
else
        echo "[failed] `date +%F-%H%M` - no backup files" | tee -a $arhivedir/backup_failed &&
        echo "[failed] `date +%F-%H%M` - no backup files" >> $backuplogfile &&
        logfilecheck
fi
}
findbackupfiles


backupcheck(){
#Проверка архивов
echo "[checking] `date +%F-%H%M` checking backup files size..." | tee -a $backuplogfile

for file in `find $dailydir/$YYYYMMDD -type f -name "*.gz"`
do
filesize=`stat -c%s $file`
        if [[ -f $file  && "$filesize" -lt "1000000" ]];
        then
                echo "[failed] `date +%F-%H%M` $file $(($filesize/1024)) kb" | tee -a $arhivedir/backup_failed &&
                echo "[failed] `date +%F-%H%M` $file $(($filesize/1024)) kb" >> $backuplogfile &&
                let checkstatus=1
        else
                echo "[good state] `date +%F-%H%M` $file $(($filesize/1024)) kb" | tee -a $backuplogfile
        fi
done
}
backupcheck

checksuccess(){
if [ "$checkstatus" -gt "0" ];then
        echo "[failed] `date +%F-%H%M` check backup files" | tee -a $arhivedir/backup_failed >> $backuplogfile &&
        logfilecheck
        else
        echo "[successful] `date +%F-%H%M` - backup is successful" | tee -a $arhivedir/backup_successful &&
        echo "[successful] `date +%F-%H%M` - backup is successful" >> $backuplogfile &&
        rm -f $arhivedir/backup_failed &&
        logfilecheck
fi
}
checksuccess
