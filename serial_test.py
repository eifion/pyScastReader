import daemon
import glob
from serial_port import *


def find_stick_and_start_reading_from_it():
  matching_units = glob.glob('/dev/ttyUSB*')
  if matching_units:
    port_name = matching_units[0]
    print "USB device found: " + port_name
    SerialPort(port_name)
  else:
    print "No devices found, exiting."
    exit()

def run():
  #with daemon.DaemonContext():
  find_stick_and_start_reading_from_it() 

if __name__== "__main__":
  run()
