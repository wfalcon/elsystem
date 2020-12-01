#!/bin/bash

daystostore=2 #количество дней которые будут хранится копии
backupdir=/media/arhive/backupsObmen/
prefix="bak"
declare -a dirs=("/media/raid/data/obmen/ /media/raid/data/obmen_kass/")
currentdate=`date +%F`"="`date +%s`
currentbackupdir=$backupdir/$currentdate
mkdir $currentbackupdir -p
chmod -R 0770 $currentbackupdir
logfile=$currentbackupdir/filestar.log

echo `date` > $logfile
for i in "${dirs[@]}"

do
    filename=$currentbackupdir/$prefix-${i##*}.tar.gz
    find $i \( -name "*.xls" -o -name "*.xlsx" -o -name "*.doc" -o -name "*.docx" -o -name "*.txt" -o -name "*.odp"  -o -name "*.odt" -o -name "*.ods" -o -name "*.tif" -o -name "*.tif" -o -name "*.cdr" -o -name "*.psd" -o -name "*.rtf" -o -name "*.rar" -o -name "*.epf" -o -name "*.erf" \) -print0 | tar -czvf $filename --null -T - >> $logfile
done

# назначение прав для доступа к файлам архивов, т.к. создаются файлы пользователем с другимим правами
chmod -R 0770 $currentbackupdir
chown -R root:root $currentbackupdir

#удаление старых архивов
now=`date +%F`
deldate=`date +%s --date "$now"`
let deldate=deldate-86400*$daystostore
for i in `ls $backupdir`
do
    backuptime=`echo $i | cut -f2 -d=`
    if [ "$backuptime" -lt "$deldate" ]
    then
        rm -R $backupdir/$i
    fi
done
