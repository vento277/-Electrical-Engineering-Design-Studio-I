import time
import serial
import string
import os
from time import sleep
import numpy as np
import sys, time, math
import serial.tools.list_ports
import matplotlib.pyplot as plt
import matplotlib.animation as animation

xsize=300

# --- Port configuration ---
try:
    ser = serial.Serial(
        port='COM4', # Change as needed
        baudrate=115200,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_TWO,
        bytesize=serial.EIGHTBITS
    )
    ser.isOpen()
    
except:
    portlist=list(serial.tools.list_ports.comports())
    print ('Available serial ports:')
    for item in portlist:
       print (item[0])
    exit()

#--- Functions ---
def data_gen_d():
    t = data_gen_d.t
    while True:
        val = ser.readline().decode('utf-8')
        val = float(val[0:len(val) - 2])
        t += 1
        time.sleep(0.)
        yield t, val

def data_gen_f():
    t = data_gen_f.t
    while True:
        val = ser.readline().decode('utf-8')
        val = float(val[0:len(val) - 2])
        val = val*(9/5) + 32
        t += 1
        time.sleep(0.)
        yield t, val

def run(data):
    # update the data
    t,y = data
    if t>-1:
        xdata.append(t)
        ydata.append(y)
        if t>xsize: # Scroll to the left.
            ax.set_xlim(t-xsize, t)
        line.set_data(xdata, ydata)

    return line,

def on_close_figure(event):
    sys.exit(0)

# --- Main ---
def main():
    os.system('cls')
    print("-------------Choose your mode!-------------")
    while True:
        try:
            start = int(input("1.Regular 2.Timed\n"))
            break
        except ValueError:
            os.system('cls')
            continue

    if start == 1:
        print("\nWhat unit of temperature do you want?")

        while True:
            try:
                unit = int(input("1.Degree 2.Fahrenheit\n"))
                break
            except ValueError:
                print("Type 1 or 2...")
                continue

        if unit == 1:
            print("\nRegular Measurement in Degrees\nLoading...")
            time.sleep(3)
            os.system('cls')
            
            ax.set_ylim(-40, 100)
            ax.set_xlim(0, xsize)
            ax.grid()
            ani = animation.FuncAnimation(fig, run, data_gen_d, blit=False, interval=50, repeat=False)
            plt.show()

        elif unit == 2:
            print("\nRegular Measurement in Fahrenheit\nLoading...")
            time.sleep(3)
            os.system('cls')

            ax.set_ylim(-40, 212) #-40 to 212 in F
            ax.set_xlim(0, xsize)
            ax.grid()
            ani = animation.FuncAnimation(fig, run, data_gen_f, blit=False, interval=50, repeat=False)
            plt.show()

        else:
            print("Please enter 1 or 2...\nRestarting the program\n")
            sleep(1)
            main()

    elif start == 2:
        low = ser.readline().decode('utf-8')
        low = float(low[0:len(low) - 2])
        high = ser.readline().decode('utf-8')
        high = float(high[0:len(high) - 2])

        # Variable dec.
        low0 = 0
        high0 = 0
        sum = 0
        avg = 0
        count = 0


        max = int(input("How long do you want to measure?\n"))
        sleep(1)
        os.system('cls')
        print("Timer Measurment\nLoading...")
        sleep(2)

        starttime = time.time()
        while (time.time() - starttime) < max:
            val = ser.readline().decode('utf-8')
            val = float(val[0:len(val) - 2])

            low0 = val
            high0 = val

            sum += val
            count+=1

            if high > high0:
                high = high
            else:
                high = high0

            if low <= low0:
                low = low
            else:
                low = low0


            time.sleep(0.)
            print(val)

        avg = sum / count

        sleep(1)
        print("Calculating...")
        sleep(1)
        os.system('cls')
        sleep(0.4)

        print("The average temperature is: %.3f" % avg, "°C")
        print("The lowest  temperature is:", low, "°C")
        print("The highest temperature is:", high, "°C")

        exit = int(input("\nWould you like to exit?\n1.Yes 2.No\n"))
        if exit == 1:
            sys.exit(0)
        else:
            main()

    else:
        main()

# --- Initiliaztion ---
init = ser.readline().decode('utf-8')
if init == '\r\n':
    ser.readline().decode('utf-8')

data_gen_d.t = -1
data_gen_f.t = -1
fig = plt.figure()
fig.canvas.mpl_connect('close_event', on_close_figure)
ax = fig.add_subplot(111)
line, = ax.plot([], [], lw=2)
xdata, ydata = [], []

# --- Main call ---
main()
