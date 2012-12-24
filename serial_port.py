from time import sleep
import serial
from scast_buffer import *

class SerialPort:
  def __init__(self, port_name):
    self.ser = serial.Serial(
      port = port_name,
      baudrate = 19200,
      parity = serial.PARITY_NONE,
      stopbits = serial.STOPBITS_ONE,
      bytesize = serial.EIGHTBITS)


    buffer = ScastBuffer()
    while 1:
      while self.ser.inWaiting() > 0:
        chars = self.ser.read(1).encode('hex')
        if buffer.add(chars):
          self.process_alarms_and_relays()
      sleep(1)

  def process_alarms_and_relays(self):
    # Read alarms from alarms table, compare with last readings
    # If any are in an alarm state update database table????
    # Can this all be done in a sproc?
    # Set any relays that need to be set....
    #print "sending!"
    #self.ser.write('AT+UCAST:000D6F000178CDF4,00FF')
    #print "sent."
