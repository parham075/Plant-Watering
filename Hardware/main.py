import os
import sys
import socket
from time import sleep

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect(('192.168.1.3', 1234))
air_temp = 0
air_hum = 0
soil_hum_1 = 0
soil_hum_2 = 0
vol_s_1 = 0
vol_s_2 = 0
while True:
    sock.sendall('getData'.encode('utf8'))
    data = sock.recv(1024).decode('utf8').split(',')
    os.system('cls')
    air_temp = float(data[0])
    air_hum = float(data[1])
    soil_hum_1 = float(data[2])
    soil_hum_2 = float(data[3])
    sys.stdout.write(f'air_temp = {air_temp}, air_hum = {air_hum}\n')
    sys.stdout.write(f'soil_1 = {soil_hum_1}, soil_2 = {soil_hum_2}\n')
    if(soil_hum_1 > 3000):
        vol_s_1 = 1
    else:
        vol_s_1 = 0
    if(soil_hum_2 > 3000):
        vol_s_2 = 1
    else:
        vol_s_2 = 0
    sys.stdout.write(f'vol_1 = {vol_s_1}, vol_2 = {vol_s_2}')
    sock.sendall(f'X{vol_s_1}{vol_s_2}'.encode('utf8'))
    sys.stdout.flush()
    sleep(2)
