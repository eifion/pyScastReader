from scast_buffer import *
import daemon
import glob
import time
import serial


def find_stick_and_start_reading_from_it():
  matching_units = glob.glob('/dev/serial/by-id/*')
  if matching_units:
    PORT_NAME = matching_units[0]
    print "USB device found: " + PORT_NAME
  else:
    print "No devices found, exiting."
    exit()


  BAUD_RATE = 19200

  ser = serial.Serial(
    port = PORT_NAME,
    baudrate = BAUD_RATE,
    parity = serial.PARITY_NONE,
    stopbits = serial.STOPBITS_ONE,
    bytesize = serial.EIGHTBITS)


  buffer = ScastBuffer()
  while 1:
    while ser.inWaiting() > 0:
      chars = ser.read(1).encode('hex')
      buffer.add(chars)   
    time.sleep(1)

def run():
  with daemon.DaemonContext():
    find_stick_and_start_reading_from_it() 


if __name__== "__main__":
  run()
