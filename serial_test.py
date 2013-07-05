#import daemon
import glob
import platform
from serial_port import *


def find_stick_and_start_reading_from_it():
  platform_name = platform.system().lower()
  if platform_name == 'darwin':
    unit_pattern = 'tty.SLAB_USBtoUART'
  elif platform_name == 'linux':
    unit_pattern = 'ttyUSB*'
  else:
    print "Unsure where to look for serial port on {}".format(platform_name)
    exit()

  matching_units = glob.glob('/dev/{}'.format(unit_pattern))
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
