from time import sleep
import serial
from scast_buffer import *

class SerialPort:
  def __init__(self, port_name):
    ser = serial.Serial(
      port = port_name,
      baudrate = 19200,
      parity = serial.PARITY_NONE,
      stopbits = serial.STOPBITS_ONE,
      bytesize = serial.EIGHTBITS)


    buffer = ScastBuffer()
    while 1:
      while ser.inWaiting() > 0:
        chars = ser.read(1).encode('hex')
        buffer.add(chars)   
      sleep(1)
