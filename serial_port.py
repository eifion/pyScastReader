from time import sleep
import psycopg2
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
      chars = ""
      while self.ser.inWaiting() > 0:
        chars += self.ser.read(1).encode('hex')
      if buffer.add(chars):
        self.process_alarms_and_relays()
      sleep(1)

  def process_alarms_and_relays(self):
    conn = psycopg2.connect("dbname=pyppm user=pyppm password=PyPPM")
    cur = conn.cursor()
    cur.execute('SELECT * FROM "GetRelayStates"()')
    for record in cur:
      self.ser.write("AT+UCAST:%s,00%0.2X\r\n" % (record[0], record[1]))
    conn.commit()
    cur.close()
    conn.close()

