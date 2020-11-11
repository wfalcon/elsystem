#!/usr/bin/env python3

import logging
import os
import subprocess
import datetime
import time

log_file ='./' # каталог должен существовать
rac_dir = '/opt/1C/v8.3/x86_64' # путь к дирректории с rac
cluster = '22f67406-c66c-4810-b60d-83195cdeae96' # идентификатор кластера(потом сделать автоматически)
infobases = {'f7dfb2b9-c2a7-4cdf-83ee-a281256165ed':'1','a6600fc7-a723-4adb-a182-2b26adb91bf5':'0'} # необходимо перечислить идентификаторы всех баз и колличество лицензий)
user_message = 'Нет свободной лицензии'

logging.basicConfig(filename=log_file + "checklic.log", format='%(asctime)s - %(message)s', level=logging.INFO) #настройка логирования
logging.info("Проверка колличества лицензий")
os.chdir(rac_dir) # переходим в каталог с rac


output = subprocess.Popen(['./rac', 'session', '--cluster=' + cluster, 'list'], stdout=subprocess.PIPE) # получаем список сессий кластера

result = output.stdout.read() # читаем вывод в переменную
result = result.decode() # преобразовываем в строку
result = result.split('\n\n') # разбиваем строку по \n\n
result = result[:-1] # удаляем лишний символ в конце


def mk_dict(result):
    """
    функция создает словарь для каждой сессии
    """
    result = result.split('\n') # разбиваем строку по \n
    dict = {} # создаем пустой словарь
    for i in result: # наполняем словарь и удаляем пробелы
        dict[i.split(' :')[0].replace(' ','')] = i.split(' :')[1].replace(' ','')
    return dict

count = 0 # счетчик колличества сессий
dict_all = {}
for i in result: # наполняем словарь словарями mk_dict
    all = mk_dict(i)
    dict_all[count]= all
    count = count + 1

def count_connect_db(infobase, sum_lic):
    """
    функция считает колличество подключений к одной базе и сортирует по времени подключения
    """
    count = 0
    session_at = {}
    session_at_sort = []
    for i in dict_all:
        if dict_all[i]['infobase'] == infobase:
            count += 1
            value = str([dict_all[i]['started-at']])[2:-2] #  конвертируем строку в объект времени
            t = time.mktime(datetime.datetime.strptime(value, "%Y-%m-%dT%H:%M:%S").timetuple()) # timestamp
            session_at[t]  = [dict_all[i]['session']]
    if count > int(sum_lic): # если сессий больше лимита, то создаем сортированный(по времени) список
        for k in sorted(session_at):
            session_at_sort.append(session_at[k])
        kill_session(session_at_sort, sum_lic)

def kill_session(session_at_sort, sum_lic):
    """
    функция убивает сессии которые превышают лимит подключений
    """
    kill = session_at_sort[int(sum_lic):] # обрезаем самые старые сессии в разрешенном колличестве
    for i in kill:
        #print(i)
        command = './rac session --cluster='+ cluster +' terminate --session=' + ''.join(i) + ' --error-message=' + '"' + user_message + '"'
        subprocess.call(command, shell=True)
        #sleep 1
        #print(command)
for k,v in infobases.items():
    count_connect_db(k, v)
